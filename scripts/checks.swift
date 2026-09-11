import AppKit
import MailSwitchCore

@MainActor final class FakeMailSystem: MailSystem {
    var clients: [MailClient] = []
    var active: MailClient?
    var reject = false
    var ignore = false
    var writes = 0
    var fileDefaults: [EmailFileKind: MailClient] = [:]
    var fileWrites: [EmailFileKind] = []
    var rejectedFiles = Set<EmailFileKind>()
    func currentFile(_ kind: EmailFileKind) -> MailClient? { fileDefaults[kind] }
    func setDefaultFile(_ kind: EmailFileKind, client: MailClient) async throws {
        fileWrites.append(kind)
        if rejectedFiles.contains(kind) { throw NSError(domain: NSCocoaErrorDomain, code: NSUserCancelledError) }
        fileDefaults[kind] = client
    }
    func discover() async -> [MailClient] { clients }
    func current() -> MailClient? { active }
    func setDefault(_ client: MailClient) async throws {
        writes += 1
        if reject { throw NSError(domain: NSCocoaErrorDomain, code: NSUserCancelledError) }
        if !ignore { active = client }
    }
}

@main struct Checks {
    @MainActor static func main() async {
        let mail = MailClient(url: URL(fileURLWithPath: "/System/Applications/Mail.app"), name: "Mail", bundleID: "com.apple.mail")
        let outlook = MailClient(url: URL(fileURLWithPath: "/Applications/Microsoft Outlook.app"), name: "Outlook", bundleID: "com.microsoft.Outlook")
        precondition(MailClient.supportsMail(info: ["CFBundleURLTypes": [["CFBundleURLSchemes": ["MAILTO"]]]]))
        precondition(!MailClient.supportsMail(info: ["CFBundleURLTypes": [["CFBundleURLSchemes": ["https"]]]]))
        precondition(!MailClient.supportsMail(info: ["CFBundleURLTypes": "invalid"]))
        print("PASS: mailto declaration validation")
        precondition(MailClient.normalized([mail, outlook, mail]).count == 2)
        print("PASS: application deduplication")
        let fake = FakeMailSystem()
        fake.clients = [mail, outlook]
        fake.active = mail
        let model = MailModel(system: fake)
        await model.refresh()
        precondition(model.current == mail && !model.canApply && fake.writes == 0)
        model.selection = outlook.id
        await model.refresh()
        precondition(model.selection == outlook.id && model.canApply && fake.writes == 0)
        print("PASS: read-only refresh and selection preservation")
        await model.apply()
        precondition(model.current == outlook && !model.isError && !model.applying && !model.canApply)
        print("PASS: successful change and readback")
        model.selection = mail.id
        fake.reject = true
        await model.apply()
        precondition(model.current == outlook && model.isError && !model.applying && model.canApply)
        print("PASS: cancellation/error handling")
        fake.reject = false
        fake.ignore = true
        await model.apply()
        precondition(model.current == outlook && model.isError)
        print("PASS: unchanged setting cannot produce false success")
        fake.clients = []
        fake.active = nil
        await model.refresh()
        precondition(model.selection == nil && !model.canApply)
        print("PASS: removed applications and empty state")

        for kind in EmailFileKind.allCases {
            let positive: [String: Any] = ["CFBundleDocumentTypes": [["CFBundleTypeRole": "Viewer", "CFBundleTypeExtensions": [kind.rawValue.uppercased()]]]]
            precondition(MailClient.supportsFile(kind, info: positive, resolvedType: nil))
            let negative: [String: Any] = ["CFBundleDocumentTypes": [["CFBundleTypeRole": "None", "CFBundleTypeExtensions": [kind.rawValue]]]]
            precondition(!MailClient.supportsFile(kind, info: negative, resolvedType: nil))
            precondition(!MailClient.supportsFile(kind, info: ["CFBundleDocumentTypes": [["CFBundleTypeRole": "Viewer", "LSItemContentTypes": ["public.item", "public.data"]]]], resolvedType: nil))
        }
        print("PASS: all seven file capabilities reject generic and non-opening declarations")
        let supported = MailClient(url: outlook.url, name: outlook.name, bundleID: outlook.bundleID, supportedFiles: [.eml, .msg])
        let fileSystem = FakeMailSystem()
        fileSystem.active = supported
        fileSystem.clients = [supported]
        fileSystem.fileDefaults[.eml] = mail
        let fileModel = MailModel(system: fileSystem)
        await fileModel.refresh()
        precondition(fileModel.canApply)
        await fileModel.apply()
        precondition(fileSystem.writes == 0 && Set(fileSystem.fileWrites) == [.eml, .msg])
        precondition(!fileModel.isError && !fileModel.canApply)
        print("PASS: file defaults change even when email links already use the selected app")
        fileSystem.fileDefaults[.eml] = mail
        fileSystem.fileDefaults[.msg] = mail
        fileSystem.rejectedFiles = [.eml]
        await fileModel.refresh()
        await fileModel.apply()
        precondition(fileModel.isError && fileModel.fileDefaults[.eml] == mail && fileModel.fileDefaults[.msg] == supported)
        precondition(fileModel.message?.contains("Some settings may have changed") == true)
        print("PASS: partial failure preserves actual per-type state and reports it")
        fileModel.selectedFiles = []
        precondition(!fileModel.canApply)
        print("PASS: unchecked and unsupported formats are not written")

        // Real integration check: discovery and readback only; never changes defaults.
        let system = MacMailSystem()
        let before = system.current()
        let discovered = await system.discover()
        precondition(system.current() == before)
        precondition(discovered.allSatisfy { FileManager.default.fileExists(atPath: $0.url.path) })
        print("PASS: real macOS discovery (\(discovered.count) handlers)")
        let sample = URL(fileURLWithPath: FileManager.default.currentDirectoryPath).appendingPathComponent("examples/hello.eml")
        precondition(FileManager.default.fileExists(atPath: sample.path))
        let actual = NSWorkspace.shared.urlForApplication(toOpen: sample)?.standardizedFileURL.resolvingSymlinksInPath()
        precondition(actual == system.currentFile(.eml)?.url.standardizedFileURL.resolvingSymlinksInPath())
        print("PASS: nonempty EML sample and independent probe resolve to the same application")
        print("PASS: current association readback (local app inventory omitted)")
    }
}
