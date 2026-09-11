import XCTest
@testable import MailSwitchCore

final class MailModelTests: XCTestCase {
    let mail = MailClient(url: URL(fileURLWithPath: "/System/Applications/Mail.app"), name: "Mail", bundleID: "com.apple.mail")
    let outlook = MailClient(url: URL(fileURLWithPath: "/Applications/Microsoft Outlook.app"), name: "Outlook", bundleID: "com.microsoft.Outlook")

    func testOnlyExplicitMailtoHandlersQualify() {
        XCTAssertTrue(MailClient.supportsMail(info: ["CFBundleURLTypes": [["CFBundleURLSchemes": ["MAILTO", "outlook"]]]]))
        XCTAssertFalse(MailClient.supportsMail(info: ["CFBundleURLTypes": [["CFBundleURLSchemes": ["https"]]]]))
        XCTAssertFalse(MailClient.supportsMail(info: ["CFBundleURLTypes": "malformed"]))
    }

    func testDeduplicatesPathsButKeepsSeparateInstallations() {
        let second = MailClient(url: URL(fileURLWithPath: "/Users/test/Applications/Mail.app"), name: "Mail", bundleID: mail.bundleID)
        XCTAssertEqual(MailClient.normalized([mail, outlook, mail, second]).count, 3)
    }

    @MainActor func testRefreshNeverChangesDefaultAndPreservesSelection() async {
        let system = FakeSystem(clients: [mail, outlook], active: mail)
        let model = MailModel(system: system)
        await model.refresh()
        XCTAssertFalse(model.canApply)
        model.selection = outlook.id
        await model.refresh()
        XCTAssertEqual(model.selection, outlook.id)
        XCTAssertEqual(system.writes, 0)
        XCTAssertTrue(model.canApply)
    }

    @MainActor func testSuccessfulChangeIsReadBack() async {
        let system = FakeSystem(clients: [mail, outlook], active: mail)
        let model = MailModel(system: system)
        await model.refresh()
        model.selection = outlook.id
        await model.apply()
        XCTAssertEqual(model.current, outlook)
        XCTAssertFalse(model.isError)
        XCTAssertNotNil(model.message)
        XCTAssertFalse(model.canApply)
        XCTAssertFalse(model.applying)
        XCTAssertEqual(system.writes, 1)
    }

    @MainActor func testRejectedChangeKeepsActualDefault() async {
        let system = FakeSystem(clients: [mail, outlook], active: mail)
        system.failure = NSError(domain: NSCocoaErrorDomain, code: NSUserCancelledError)
        let model = MailModel(system: system)
        await model.refresh()
        model.selection = outlook.id
        await model.apply()
        XCTAssertEqual(model.current, mail)
        XCTAssertTrue(model.isError)
        XCTAssertFalse(model.applying)
        XCTAssertTrue(model.canApply)
    }

    @MainActor func testNoFalseSuccessWhenSystemDoesNotChange() async {
        let system = FakeSystem(clients: [mail, outlook], active: mail)
        system.ignoreWrite = true
        let model = MailModel(system: system)
        await model.refresh()
        model.selection = outlook.id
        await model.apply()
        XCTAssertTrue(model.isError)
        XCTAssertEqual(model.current, mail)
    }

    @MainActor func testRemovedSelectionAndEmptyDiscovery() async {
        let system = FakeSystem(clients: [outlook], active: nil)
        let model = MailModel(system: system)
        await model.refresh()
        XCTAssertEqual(model.selection, outlook.id)
        system.clients = []
        await model.refresh()
        XCTAssertNil(model.selection)
        XCTAssertFalse(model.canApply)
    }
}

@MainActor private final class FakeSystem: MailSystem {
    var clients: [MailClient]
    var active: MailClient?
    var failure: Error?
    var ignoreWrite = false
    var writes = 0

    init(clients: [MailClient], active: MailClient?) {
        self.clients = clients
        self.active = active
    }
    func discover() async -> [MailClient] { clients }
    func current() -> MailClient? { active }
    func setDefault(_ client: MailClient) async throws {
        writes += 1
        if let failure { throw failure }
        if !ignoreWrite { active = client }
    }
}
