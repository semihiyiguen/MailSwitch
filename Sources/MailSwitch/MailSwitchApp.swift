import AppKit
import Combine
import MailSwitchCore

@main
struct MailSwitchApp {
    @MainActor static func main() {
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        app.setActivationPolicy(.regular)
        withExtendedLifetime(delegate) { app.run() }
    }
}

@MainActor final class AppDelegate: NSObject, NSApplicationDelegate, NSTableViewDataSource, NSTableViewDelegate {
    private let model = MailModel(system: MacMailSystem())
    private var observation: AnyCancellable?
    private var window: NSWindow!
    private let table = NSTableView()
    private let currentName = NSTextField(labelWithString: "Checking…")
    private let emlName = NSTextField(labelWithString: "Checking…")
    private var fileChecks: [EmailFileKind: NSButton] = [:]
    private var fileLabels: [EmailFileKind: NSTextField] = [:]
    private let detailsButton = NSButton(title: "Details…", target: nil, action: nil)
    private let currentIcon = NSImageView()
    private let status = NSTextField(wrappingLabelWithString: "")
    private let refreshButton = NSButton(title: "Refresh", target: nil, action: nil)
    private let browseButton = NSButton(title: "Choose another app…", target: nil, action: nil)
    private let applyButton = NSButton(title: "Set as default", target: nil, action: nil)
    private let testButton = NSButton(title: "Test .eml", target: nil, action: nil)
    private let progress = NSProgressIndicator()
    private let emptyLabel = NSTextField(labelWithString: "Looking for email apps…")
    private var rendering = false

    func applicationDidFinishLaunching(_ notification: Notification) {
        makeMenu()
        makeWindow()
        observation = model.objectWillChange.sink { [weak self] _ in
            DispatchQueue.main.async { self?.render() }
        }
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        Task { await model.refresh() }
    }

    func applicationDidBecomeActive(_ notification: Notification) {
        Task { await model.refresh() }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }

    private func makeMenu() {
        let menu = NSMenu()
        let appItem = NSMenuItem()
        let appMenu = NSMenu(title: "MailSwitch")
        appMenu.addItem(withTitle: "About MailSwitch", action: #selector(about), keyEquivalent: "")
        appMenu.addItem(.separator())
        appMenu.addItem(withTitle: "Quit MailSwitch", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        appItem.submenu = appMenu
        menu.addItem(appItem)
        let windowItem = NSMenuItem()
        let windowMenu = NSMenu(title: "Window")
        windowMenu.addItem(withTitle: "Minimize", action: #selector(NSWindow.performMiniaturize(_:)), keyEquivalent: "m")
        windowMenu.addItem(withTitle: "Close", action: #selector(NSWindow.performClose(_:)), keyEquivalent: "w")
        windowItem.submenu = windowMenu
        menu.addItem(windowItem)
        NSApp.mainMenu = menu
        NSApp.windowsMenu = windowMenu
    }

    private func makeWindow() {
        window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 600, height: min(790, (NSScreen.main?.visibleFrame.height ?? 900) - 80)),
                          styleMask: [.titled, .closable, .miniaturizable], backing: .buffered, defer: false)
        window.title = "MailSwitch"
        window.isReleasedWhenClosed = false
        window.center()
        let viewport = NSScrollView(frame: window.contentView!.bounds)
        viewport.autoresizingMask = [.width, .height]
        viewport.hasVerticalScroller = true
        viewport.autohidesScrollers = true
        let root = NSView(frame: NSRect(x: 0, y: 0, width: 600, height: 790))
        viewport.documentView = root
        window.contentView = viewport
        viewport.contentView.scroll(to: NSPoint(x: 0, y: max(0, 790 - viewport.bounds.height)))
        let appIcon = NSImageView(frame: NSRect(x: 26, y: 702, width: 64, height: 64))
        appIcon.image = NSApp.applicationIconImage
        root.addSubview(appIcon)
        label("Your email. Your app.", frame: NSRect(x: 102, y: 734, width: 470, height: 27), size: 24, weight: .semibold, in: root)
        label("Set defaults for email links and files. No Mail sign-in needed.", frame: NSRect(x: 102, y: 708, width: 470, height: 21), size: 12, secondary: true, in: root)
        let card = NSBox(frame: NSRect(x: 28, y: 606, width: 544, height: 80))
        card.boxType = .custom
        card.borderWidth = 0
        card.cornerRadius = 12
        card.fillColor = NSColor.controlAccentColor.withAlphaComponent(0.10)
        root.addSubview(card)
        label("EMAIL LINKS (mailto)", frame: NSRect(x: 46, y: 652, width: 245, height: 15), size: 10, weight: .semibold, secondary: true, in: root)
        label("EMAIL FILES (.eml)", frame: NSRect(x: 310, y: 652, width: 245, height: 15), size: 10, weight: .semibold, secondary: true, in: root)
        currentName.frame = NSRect(x: 46, y: 626, width: 235, height: 24)
        currentName.font = .systemFont(ofSize: 17, weight: .semibold)
        currentName.lineBreakMode = .byTruncatingTail
        root.addSubview(currentName)
        emlName.frame = NSRect(x: 310, y: 626, width: 245, height: 24)
        emlName.font = .systemFont(ofSize: 17, weight: .semibold)
        emlName.lineBreakMode = .byTruncatingTail
        root.addSubview(emlName)
        label("Your email apps", frame: NSRect(x: 28, y: 566, width: 330, height: 22), size: 13, weight: .semibold, in: root)
        configure(refreshButton, frame: NSRect(x: 478, y: 564, width: 98, height: 27), action: #selector(refresh), in: root)
        let scroll = NSScrollView(frame: NSRect(x: 28, y: 351, width: 544, height: 205))
        scroll.borderType = .bezelBorder
        scroll.hasVerticalScroller = true
        scroll.autohidesScrollers = true
        let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("app"))
        column.width = 526
        column.minWidth = 510
        table.addTableColumn(column)
        table.headerView = nil
        table.rowHeight = 62
        table.intercellSpacing = NSSize(width: 0, height: 2)
        table.allowsEmptySelection = false
        table.allowsMultipleSelection = false
        table.columnAutoresizingStyle = .uniformColumnAutoresizingStyle
        table.dataSource = self
        table.delegate = self
        table.setAccessibilityLabel("Installed email apps")
        scroll.documentView = table
        root.addSubview(scroll)
        emptyLabel.frame = NSRect(x: 42, y: 435, width: 515, height: 40)
        emptyLabel.alignment = .center
        emptyLabel.textColor = .secondaryLabelColor
        root.addSubview(emptyLabel)
        configure(browseButton, frame: NSRect(x: 24, y: 311, width: 187, height: 29), action: #selector(browse), in: root)
        configure(testButton, frame: NSRect(x: 468, y: 311, width: 108, height: 29), action: #selector(testEmail), in: root)
        testButton.toolTip = "Open a synthetic message with the current default app. Nothing is sent."
        label("File types", frame: NSRect(x: 28, y: 285, width: 110, height: 20), size: 12, weight: .semibold, in: root)
        label("CURRENT DEFAULT", frame: NSRect(x: 142, y: 285, width: 210, height: 20), size: 10, secondary: true, in: root)
        for (index, kind) in EmailFileKind.allCases.enumerated() {
            let y = CGFloat(258 - index * 25)
            let check = NSButton(checkboxWithTitle: kind.label, target: self, action: #selector(toggleFile(_:)))
            check.frame = NSRect(x: 28, y: y, width: 104, height: 23)
            check.tag = index
            fileChecks[kind] = check
            root.addSubview(check)
            let info = NSTextField(labelWithString: "Checking…")
            info.frame = NSRect(x: 142, y: y + 2, width: 425, height: 20)
            info.font = .systemFont(ofSize: 11)
            info.lineBreakMode = .byTruncatingTail
            fileLabels[kind] = info
            root.addSubview(info)
        }
        configure(detailsButton, frame: NSRect(x: 477, y: 67, width: 98, height: 28), action: #selector(showDetails), in: root)
        status.frame = NSRect(x: 28, y: 62, width: 440, height: 40)
        status.font = .systemFont(ofSize: 12)
        root.addSubview(status)
        label("Each selected default is checked with macOS.", frame: NSRect(x: 28, y: 31, width: 357, height: 23), size: 11, secondary: true, in: root)
        configure(applyButton, frame: NSRect(x: 424, y: 24, width: 153, height: 38), action: #selector(apply), in: root)
        applyButton.keyEquivalent = "\r"
        progress.frame = NSRect(x: 394, y: 34, width: 18, height: 18)
        progress.style = .spinning
        progress.controlSize = .small
        progress.isDisplayedWhenStopped = false
        root.addSubview(progress)
        render()
    }

    private func label(_ text: String, frame: NSRect, size: CGFloat, weight: NSFont.Weight = .regular, secondary: Bool = false, in view: NSView) {
        let label = NSTextField(labelWithString: text)
        label.frame = frame
        label.font = .systemFont(ofSize: size, weight: weight)
        if secondary { label.textColor = .secondaryLabelColor }
        view.addSubview(label)
    }

    private func configure(_ button: NSButton, frame: NSRect, action: Selector, in view: NSView) {
        button.frame = frame
        button.bezelStyle = .rounded
        button.target = self
        button.action = action
        view.addSubview(button)
    }

    private func render() {
        guard window != nil else { return }
        rendering = true
        defer { rendering = false }
        currentName.stringValue = model.current?.name ?? (model.scanning ? "Checking…" : "Not set")
        emlName.stringValue = model.fileDefaults[.eml]?.name ?? (model.scanning ? "Checking…" : "Not set")
        currentIcon.image = model.current.map { NSWorkspace.shared.icon(forFile: $0.url.path) }
        table.reloadData()
        if let index = model.clients.firstIndex(where: { $0.id == model.selection }) {
            table.selectRowIndexes(IndexSet(integer: index), byExtendingSelection: false)
        }
        emptyLabel.isHidden = !model.clients.isEmpty
        emptyLabel.stringValue = model.scanning ? "Looking for email apps…" : "No email apps found. Choose an app below."
        let busy = model.scanning || model.applying
        refreshButton.isEnabled = !busy
        browseButton.isEnabled = !busy
        testButton.isEnabled = !busy
        for kind in EmailFileKind.allCases {
            let supported = model.selected?.supportedFiles.contains(kind) == true
            fileChecks[kind]?.isEnabled = !busy && supported
            fileChecks[kind]?.state = supported && model.selectedFiles.contains(kind) ? .on : .off
            let name = model.fileDefaults[kind]?.name ?? "Not set"
            fileLabels[kind]?.stringValue = name + (supported ? "" : " · Not supported by selected app")
            fileLabels[kind]?.textColor = supported ? .labelColor : .secondaryLabelColor
        }
        applyButton.isEnabled = model.canApply
        applyButton.title = model.applying ? "Setting default…" : "Set as default"
        status.stringValue = model.isError ? "Some defaults could not be updated. Review Details and retry." : (model.message ?? "")
        detailsButton.isHidden = !model.isError
        status.textColor = model.isError ? .systemRed : .systemGreen
        if busy { progress.startAnimation(nil) } else { progress.stopAnimation(nil) }
    }

    func numberOfRows(in tableView: NSTableView) -> Int { model.clients.count }
    func tableView(_ tableView: NSTableView, shouldSelectRow row: Int) -> Bool { !model.applying && !model.scanning }
    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let client = model.clients[row]
        let cell = NSTableCellView(frame: NSRect(x: 0, y: 0, width: 520, height: 62))
        let icon = NSImageView(frame: NSRect(x: 12, y: 12, width: 38, height: 38))
        icon.image = NSWorkspace.shared.icon(forFile: client.url.path)
        cell.addSubview(icon)
        let name = NSTextField(labelWithString: client.name)
        name.frame = NSRect(x: 62, y: 32, width: 340, height: 19)
        name.font = .systemFont(ofSize: 13, weight: .medium)
        name.lineBreakMode = .byTruncatingTail
        cell.addSubview(name)
        cell.textField = name
        let path = client.url.deletingLastPathComponent().path.replacingOccurrences(of: NSHomeDirectory(), with: "~", options: .anchored)
        label(path, frame: NSRect(x: 62, y: 11, width: 360, height: 17), size: 10, secondary: true, in: cell)
        if client.id == model.current?.id {
            label("Links", frame: NSRect(x: 455, y: 34, width: 60, height: 18), size: 10, weight: .medium, secondary: true, in: cell)
        }
        if client.id == model.fileDefaults[.eml]?.id {
            label(".eml", frame: NSRect(x: 455, y: 13, width: 60, height: 18), size: 10, weight: .medium, secondary: true, in: cell)
        }
        cell.toolTip = client.url.path.replacingOccurrences(of: NSHomeDirectory(), with: "~", options: .anchored)
        cell.setAccessibilityLabel(client.name + (client.id == model.current?.id ? ", default for email links" : "") + (client.id == model.fileDefaults[.eml]?.id ? ", default for .eml files" : ""))
        return cell
    }

    func tableViewSelectionDidChange(_ notification: Notification) {
        guard !rendering, model.clients.indices.contains(table.selectedRow) else { return }
        model.selection = model.clients[table.selectedRow].id
    }

    @objc private func refresh() { Task { await model.refresh() } }
    @objc private func testEmail() {
        guard let url = Bundle.main.url(forResource: "hello", withExtension: "eml"),
              NSWorkspace.shared.open(url) else {
            model.reportError("The sample email could not be opened. Check the .eml default and try again.")
            return
        }
    }
    @objc private func apply() { Task { await model.apply() } }
    @objc private func toggleFile(_ sender: NSButton) {
        guard EmailFileKind.allCases.indices.contains(sender.tag) else { return }
        let kind = EmailFileKind.allCases[sender.tag]
        if sender.state == .on { model.selectedFiles.insert(kind) }
        else { model.selectedFiles.remove(kind) }
    }
    @objc private func showDetails() {
        let alert = NSAlert()
        alert.messageText = "Default app update"
        alert.informativeText = model.message ?? "No details available."
        alert.addButton(withTitle: "OK")
        alert.beginSheetModal(for: window)
    }
    @objc private func about() {
        NSApp.orderFrontStandardAboutPanel(options: [
            .applicationName: "MailSwitch", .applicationVersion: "1.2",
            .credits: NSAttributedString(string: "Choose your default email app.\nNo account, network connection or administrator password required.")
        ])
    }

    @objc private func browse() {
        let panel = NSOpenPanel()
        panel.title = "Choose an email app"
        panel.prompt = "Choose"
        panel.allowedFileTypes = ["app"]
        panel.directoryURL = URL(fileURLWithPath: "/Applications")
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.beginSheetModal(for: window) { [weak self] response in
            guard let self, response == .OK, let url = panel.url else { return }
            guard let client = MacMailSystem.client(at: url) else {
                self.model.reportError("This app does not declare support for email links (mailto). Choose another app.")
                return
            }
            self.model.add(client)
        }
    }
}
