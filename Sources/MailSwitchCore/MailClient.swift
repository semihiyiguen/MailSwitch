import Foundation
import Combine

public enum EmailFileKind: String, CaseIterable, Identifiable, Sendable {
    case eml, emlx, msg, mime, mme, oft, emltpl
    public var id: String { rawValue }
    public var label: String { "." + rawValue }
    public var knownTypeIdentifiers: [String] {
        switch self {
        case .eml: return ["com.apple.mail.email", "com.microsoft.outlook15.email-message"]
        case .emlx: return ["com.apple.mail.emlx"]
        case .msg: return ["com.microsoft.outlook.msg"]
        default: return []
        }
    }
}

public struct MailClient: Identifiable, Equatable, Sendable {
    public let url: URL
    public let name: String
    public let bundleID: String
    public let supportedFiles: Set<EmailFileKind>
    public var id: String { url.standardizedFileURL.resolvingSymlinksInPath().path }

    public init(url: URL, name: String, bundleID: String, supportedFiles: Set<EmailFileKind> = []) {
        self.url = url
        self.name = name
        self.bundleID = bundleID
        self.supportedFiles = supportedFiles
    }

    public static func supportsMail(info: [String: Any]) -> Bool {
        let types = info["CFBundleURLTypes"] as? [[String: Any]] ?? []
        return types.contains { entry in
            (entry["CFBundleURLSchemes"] as? [String] ?? []).contains { $0.lowercased() == "mailto" }
        }
    }

    public static func supportsFile(_ kind: EmailFileKind, info: [String: Any], resolvedType: String?) -> Bool {
        let types = info["CFBundleDocumentTypes"] as? [[String: Any]] ?? []
        return types.contains { entry in
            let role = (entry["CFBundleTypeRole"] as? String ?? "").lowercased()
            guard ["viewer", "editor", "shell"].contains(role),
                  (entry["LSHandlerRank"] as? String)?.lowercased() != "none" else { return false }
            if (entry["CFBundleTypeExtensions"] as? [String] ?? []).contains(where: { $0.lowercased() == kind.rawValue }) { return true }
            // Broad public.item/public.data or wildcard claims are not email-file capabilities.
            return (entry["LSItemContentTypes"] as? [String] ?? []).contains { declared in
                kind.knownTypeIdentifiers.contains(declared) || (resolvedType != nil && declared == resolvedType)
            }
        }
    }

    public static func normalized(_ clients: [MailClient]) -> [MailClient] {
        var seen = Set<String>()
        return clients.filter { seen.insert($0.id).inserted }.sorted {
            let order = $0.name.localizedStandardCompare($1.name)
            return order == .orderedSame ? $0.id < $1.id : order == .orderedAscending
        }
    }
}

@MainActor public protocol MailSystem {
    func discover() async -> [MailClient]
    func current() -> MailClient?
    func setDefault(_ client: MailClient) async throws
    func currentFile(_ kind: EmailFileKind) -> MailClient?
    func setDefaultFile(_ kind: EmailFileKind, client: MailClient) async throws
}

public extension MailSystem {
    func currentFile(_ kind: EmailFileKind) -> MailClient? { nil }
    func setDefaultFile(_ kind: EmailFileKind, client: MailClient) async throws {
        throw NSError(domain: "MailSwitch", code: 2, userInfo: [NSLocalizedDescriptionKey: "This file type is unavailable."])
    }
}

@MainActor public final class MailModel: ObservableObject {
    @Published public private(set) var clients: [MailClient] = []
    @Published public private(set) var current: MailClient?
    @Published public private(set) var fileDefaults: [EmailFileKind: MailClient] = [:]
    @Published public var selectedFiles = Set(EmailFileKind.allCases)
    @Published public var selection: String?
    @Published public private(set) var scanning = false
    @Published public private(set) var applying = false
    @Published public private(set) var message: String?
    @Published public private(set) var isError = false
    private let system: any MailSystem

    public init(system: any MailSystem) { self.system = system }
    public var selected: MailClient? { clients.first { $0.id == selection } }
    public var canApply: Bool {
        guard !scanning, !applying, let chosen = selected else { return false }
        return chosen.id != current?.id || selectedFiles.intersection(chosen.supportedFiles).contains { fileDefaults[$0]?.id != chosen.id }
    }

    private func readDefaults() {
        current = system.current()
        fileDefaults = Dictionary(uniqueKeysWithValues: EmailFileKind.allCases.compactMap { kind in
            system.currentFile(kind).map { (kind, $0) }
        })
    }

    public func refresh() async {
        guard !scanning && !applying else { return }
        scanning = true
        defer { scanning = false }
        let found = await system.discover()
        readDefaults()
        clients = MailClient.normalized(found + (current.map { [$0] } ?? []))
        if !clients.contains(where: { $0.id == selection }) { selection = current?.id ?? clients.first?.id }
    }

    public func add(_ client: MailClient) {
        clients.removeAll { $0.id == client.id }
        clients = MailClient.normalized(clients + [client])
        selection = client.id
        message = nil
    }

    public func reportError(_ text: String) { message = text; isError = true }

    public func apply() async {
        guard canApply, let chosen = selected else { return }
        applying = true
        message = nil
        defer { applying = false }
        // Snapshot choices so a later UI change cannot expand this operation.
        let files = EmailFileKind.allCases.filter { selectedFiles.contains($0) && chosen.supportedFiles.contains($0) }
        let targets: [EmailFileKind?] = [nil] + files.map(Optional.some)
        var failures: [String] = []
        for kind in targets {
            let label = kind?.label ?? "Email links"
            do {
                let before = kind.map { system.currentFile($0) } ?? system.current()
                if before?.id != chosen.id {
                    if let kind { try await system.setDefaultFile(kind, client: chosen) }
                    else { try await system.setDefault(chosen) }
                }
                var verified = false
                for attempt in 0..<8 {
                    let actual: MailClient? = kind.map { system.currentFile($0) } ?? system.current()
                    if actual?.id == chosen.id { verified = true; break }
                    if attempt < 7 { try await Task.sleep(nanoseconds: 250_000_000) }
                }
                if !verified { failures.append("\(label): could not verify the change.") }
            } catch {
                failures.append("\(label): \(error.localizedDescription)")
            }
        }
        readDefaults()
        isError = !failures.isEmpty
        message = failures.isEmpty
            ? "Verified: \(chosen.name) opens email links\(files.isEmpty ? "" : " and the selected supported files")."
            : failures.joined(separator: "\n") + "\nSome settings may have changed. Review the current defaults and retry."
    }
}
