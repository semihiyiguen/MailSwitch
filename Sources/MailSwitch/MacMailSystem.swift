import AppKit
import CoreServices
import UniformTypeIdentifiers
import MailSwitchCore

final class MacMailSystem: MailSystem {
    static let mailURL = URL(string: "mailto:")!
    private let probeDirectory: URL
    private var probes: [EmailFileKind: URL] = [:]

    init() {
        probeDirectory = FileManager.default.temporaryDirectory.appendingPathComponent("MailSwitch-" + UUID().uuidString, isDirectory: true)
        do {
            try FileManager.default.createDirectory(at: probeDirectory, withIntermediateDirectories: false, attributes: [.posixPermissions: 0o700])
            for kind in EmailFileKind.allCases {
                let url = probeDirectory.appendingPathComponent("association-check." + kind.rawValue)
                // These files are association probes only, never opened as messages.
                try Data().write(to: url, options: .atomic)
                probes[kind] = url
            }
        } catch { probes = [:] }
    }

    deinit { try? FileManager.default.removeItem(at: probeDirectory) }

    func current() -> MailClient? {
        NSWorkspace.shared.urlForApplication(toOpen: Self.mailURL).flatMap { Self.client(at: $0, requireDeclaration: false) }
    }

    func currentFile(_ kind: EmailFileKind) -> MailClient? {
        guard let probe = probes[kind] else { return nil }
        return NSWorkspace.shared.urlForApplication(toOpen: probe).flatMap { Self.client(at: $0, requireDeclaration: false) }
    }

    func discover() async -> [MailClient] {
        let registered: [URL]
        if #available(macOS 12.0, *) {
            registered = NSWorkspace.shared.urlsForApplications(toOpen: Self.mailURL)
        } else {
            let identifiers = LSCopyAllHandlersForURLScheme("mailto" as CFString)?.takeRetainedValue() as? [String] ?? []
            registered = identifiers.compactMap { NSWorkspace.shared.urlForApplication(withBundleIdentifier: $0) }
        }
        return await Task.detached(priority: .userInitiated) { Self.scan(registered: registered) }.value
    }

    nonisolated private static func scan(registered: [URL]) -> [MailClient] {
        var found = registered.compactMap { Self.client(at: $0, requireDeclaration: false) }
        for root in ["/Applications", "/System/Applications", NSHomeDirectory() + "/Applications"] {
            guard let walker = FileManager.default.enumerator(at: URL(fileURLWithPath: root), includingPropertiesForKeys: [.isDirectoryKey], options: [.skipsHiddenFiles, .skipsPackageDescendants]) else { continue }
            for case let url as URL in walker where url.pathExtension.lowercased() == "app" {
                walker.skipDescendants()
                if let app = Self.client(at: url) { found.append(app) }
            }
        }
        return MailClient.normalized(found)
    }

    nonisolated static func typeIdentifier(_ kind: EmailFileKind) -> String? {
        if #available(macOS 11.0, *) { return UTType(filenameExtension: kind.rawValue)?.identifier }
        return UTTypeCreatePreferredIdentifierForTag(kUTTagClassFilenameExtension, kind.rawValue as CFString, nil)?.takeRetainedValue() as String?
    }

    nonisolated static func client(at url: URL, requireDeclaration: Bool = true) -> MailClient? {
        guard url.pathExtension.lowercased() == "app", FileManager.default.fileExists(atPath: url.path),
              let bundle = Bundle(url: url), let info = bundle.infoDictionary,
              let bundleID = bundle.bundleIdentifier, let executable = bundle.executableURL,
              FileManager.default.isExecutableFile(atPath: executable.path),
              !requireDeclaration || MailClient.supportsMail(info: info) else { return nil }
        let name = bundle.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String
            ?? bundle.object(forInfoDictionaryKey: "CFBundleName") as? String
            ?? url.deletingPathExtension().lastPathComponent
        let files = Set(EmailFileKind.allCases.filter { MailClient.supportsFile($0, info: info, resolvedType: typeIdentifier($0)) })
        return MailClient(url: url, name: name, bundleID: bundleID, supportedFiles: files)
    }

    private func validate(_ client: MailClient, kind: EmailFileKind? = nil) throws {
        guard let actual = Self.client(at: client.url, requireDeclaration: false),
              actual.bundleID == client.bundleID, kind.map({ actual.supportedFiles.contains($0) }) ?? true else {
            throw NSError(domain: "MailSwitch", code: 1, userInfo: [NSLocalizedDescriptionKey: "This app changed, is unavailable, or does not support this selection. Refresh the app list."])
        }
        if #unavailable(macOS 12.0) {
            guard let resolved = NSWorkspace.shared.urlForApplication(withBundleIdentifier: client.bundleID),
                  resolved.standardizedFileURL.resolvingSymlinksInPath() == client.url.standardizedFileURL.resolvingSymlinksInPath() else {
                throw NSError(domain: "MailSwitch", code: 3, userInfo: [NSLocalizedDescriptionKey: "macOS resolves this app identifier to another installation. Choose that copy instead."])
            }
        }
    }

    func setDefault(_ client: MailClient) async throws {
        try validate(client)
        if #available(macOS 12.0, *) {
            try await NSWorkspace.shared.setDefaultApplication(at: client.url, toOpenURLsWithScheme: "mailto")
        } else {
            let status = LSSetDefaultHandlerForURLScheme("mailto" as CFString, client.bundleID as CFString)
            if status != noErr { throw NSError(domain: NSOSStatusErrorDomain, code: Int(status)) }
        }
    }

    func setDefaultFile(_ kind: EmailFileKind, client: MailClient) async throws {
        try validate(client, kind: kind)
        guard probes[kind] != nil, let type = Self.typeIdentifier(kind) else {
            throw NSError(domain: "MailSwitch", code: 4, userInfo: [NSLocalizedDescriptionKey: "Could not prepare a local file-type check. Restart MailSwitch and try again."])
        }
        if #available(macOS 12.0, *) {
            guard let contentType = UTType(type) else {
                throw NSError(domain: "MailSwitch", code: 5, userInfo: [NSLocalizedDescriptionKey: "macOS did not resolve this file type."])
            }
            try await NSWorkspace.shared.setDefaultApplication(at: client.url, toOpen: contentType)
        } else {
            let status = LSSetDefaultRoleHandlerForContentType(type as CFString, .all, client.bundleID as CFString)
            if status != noErr { throw NSError(domain: NSOSStatusErrorDomain, code: Int(status)) }
        }
    }
}
