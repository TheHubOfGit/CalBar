import AppKit
import SwiftUI
import Combine

@MainActor
public final class MenuBarController: NSObject, NSPopoverDelegate {
    private var statusItem: NSStatusItem!
    private var popover: NSPopover!
    private var settingsWindow: NSWindow?
    private let coordinator = CalendarSyncCoordinator.shared
    private var cancellables = Set<AnyCancellable>()

    public override init() {
        super.init()
        setupStatusItem()
        setupPopover()
        observeCoordinator()
    }

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        if let button = statusItem.button {
            let imageConfig = NSImage.SymbolConfiguration(pointSize: 13, weight: .regular)
            let image = NSImage(systemSymbolName: "calendar", accessibilityDescription: "CalBar")?.withSymbolConfiguration(imageConfig)
            image?.isTemplate = true
            button.image = image
            button.imagePosition = .imageLeft
            button.target = self
            button.action = #selector(togglePopover(_:))

            updateTitle(coordinator.menuBarTitle)
        }
    }

    private func setupPopover() {
        popover = NSPopover()
        popover.behavior = .transient
        popover.animates = true
        popover.delegate = self

        let rootView = MenuBarPopoverView(
            coordinator: coordinator,
            onOpenSettings: { [weak self] in
                self?.openSettingsWindow()
            }
        )

        let hostingController = NSHostingController(rootView: rootView)
        popover.contentViewController = hostingController
        popover.contentSize = coordinator.desiredPopoverSize()
    }

    private func observeCoordinator() {
        coordinator.onMenuBarTitleChanged = { [weak self] newTitle in
            self?.updateTitle(newTitle)
        }

        coordinator.onPopoverSizeChanged = { [weak self] newSize in
            self?.updatePopoverSize(newSize)
        }

        Publishers.CombineLatest4(coordinator.$viewMode, coordinator.$limitWorkingHours, coordinator.$timelineDensity, coordinator.$events)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                guard let self = self else { return }
                self.updatePopoverSize(self.coordinator.desiredPopoverSize())
            }
            .store(in: &cancellables)

        coordinator.$onlyShowWeekdays
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                guard let self = self else { return }
                self.updatePopoverSize(self.coordinator.desiredPopoverSize())
            }
            .store(in: &cancellables)
    }

    private func updatePopoverSize(_ size: NSSize) {
        if popover.contentSize != size {
            popover.contentSize = size
        }
    }

    private func updateTitle(_ text: String) {
        guard let button = statusItem.button else { return }
        if text.isEmpty {
            button.title = ""
        } else {
            button.title = " " + text
        }
    }

    @objc private func togglePopover(_ sender: AnyObject?) {
        guard let button = statusItem.button else { return }

        if popover.isShown {
            popover.performClose(sender)
        } else {
            updatePopoverSize(coordinator.desiredPopoverSize())
            NSApp.activate(ignoringOtherApps: true)
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            popover.contentViewController?.view.window?.makeKey()
        }
    }

    public func openSettingsWindow() {
        popover.performClose(nil)

        if let window = settingsWindow {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let settingsView = SettingsView(coordinator: coordinator)
        let hostingController = NSHostingController(rootView: settingsView)

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 520, height: 520),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.center()
        window.title = "CalBar Settings"
        window.contentViewController = hostingController
        window.setContentSize(NSSize(width: 520, height: 520))
        window.minSize = NSSize(width: 480, height: 460)
        window.isReleasedWhenClosed = false

        self.settingsWindow = window
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    // MARK: - NSPopoverDelegate
    public func popoverWillShow(_ notification: Notification) {
        coordinator.isPopoverVisible = true
    }

    public func popoverDidClose(_ notification: Notification) {
        coordinator.isPopoverVisible = false
    }
}

