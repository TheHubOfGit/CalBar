import AppKit
import QuartzCore
import SwiftUI
import Combine

@MainActor
public final class MenuBarController: NSObject, NSPopoverDelegate {
    private var statusItem: NSStatusItem!
    private var popover: NSPopover!
    private var settingsWindow: NSWindow?
    private let coordinator = CalendarSyncCoordinator.shared
    private var cancellables = Set<AnyCancellable>()
    private var iconImage: NSImage?

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
            iconImage = image
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

        // Only geometry-affecting preferences resize the popover. Event arrivals deliberately
        // do not: resizing mid-sync made the window visibly jump on every refresh.
        Publishers.CombineLatest4(
            coordinator.$viewMode,
            coordinator.$limitWorkingHours,
            coordinator.$timelineDensity,
            coordinator.$onlyShowWeekdays
        )
        .map { [weak self] _ in self?.coordinator.desiredPopoverSize() ?? .zero }
        .removeDuplicates()
        .receive(on: RunLoop.main)
        .sink { [weak self] size in
            self?.updatePopoverSize(size, animated: true)
        }
        .store(in: &cancellables)
    }

    private func updatePopoverSize(_ size: NSSize, animated: Bool = false) {
        guard popover.contentSize != size else { return }

        guard animated, popover.isShown else {
            popover.contentSize = size
            return
        }

        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.22
            context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            context.allowsImplicitAnimation = true
            popover.contentSize = size
        }
    }

    private func updateTitle(_ text: String) {
        guard let button = statusItem.button else { return }
        button.attributedTitle = NSAttributedString(string: "")
        if text.contains("\n") {
            // Stacked two-line title, drawn into one template image (icon + both lines) so the
            // lines can span the full menu bar height instead of fighting the button's own
            // vertical text centering.
            button.title = ""
            button.imagePosition = .imageOnly
            button.image = Self.stackedImage(icon: iconImage, text: text)
        } else {
            button.image = iconImage
            button.imagePosition = .imageLeft
            button.title = text.isEmpty ? "" : " " + text
        }
    }

    private static func stackedImage(icon: NSImage?, text: String) -> NSImage {
        let lines = text.components(separatedBy: "\n")
        let top = lines.first ?? ""
        let bottom = lines.count > 1 ? lines[1] : ""
        let height: CGFloat = 22
        let iconSize = icon?.size ?? .zero
        let gap: CGFloat = 5

        let topFont = NSFont.systemFont(ofSize: 10, weight: .semibold)
        let bottomFont = NSFont.systemFont(ofSize: 10, weight: .medium)
        func attributed(_ string: String, _ font: NSFont) -> NSAttributedString {
            NSAttributedString(string: string, attributes: [.font: font, .foregroundColor: NSColor.black])
        }
        let topText = attributed(top, topFont)
        let bottomText = attributed(bottom, bottomFont)
        let textWidth = ceil(max(topText.size().width, bottomText.size().width))
        let width = iconSize.width + gap + textWidth

        let image = NSImage(size: NSSize(width: width, height: height), flipped: false) { _ in
            if let icon {
                icon.draw(in: NSRect(x: 0, y: (height - iconSize.height) / 2, width: iconSize.width, height: iconSize.height))
            }
            // Pin each line's baseline near its edge: cap tops sit ~2pt below the top and the
            // bottom baseline sits ~2pt above the bottom, using the whole bar.
            let textX = iconSize.width + gap
            let topBaseline = height - 2.5 - topFont.capHeight
            let bottomBaseline: CGFloat = 2.5
            let topX = textX + (textWidth - topText.size().width) / 2
            let bottomX = textX + (textWidth - bottomText.size().width) / 2
            topText.draw(at: NSPoint(x: topX, y: topBaseline + topFont.descender))
            bottomText.draw(at: NSPoint(x: bottomX, y: bottomBaseline + bottomFont.descender))
            return true
        }
        image.isTemplate = true
        return image
    }

    @objc private func togglePopover(_ sender: AnyObject?) {
        guard let button = statusItem.button else { return }

        if popover.isShown {
            popover.performClose(sender)
        } else {
            // Snap to the current day and re-anchor the timeline *before* the first paint so the
            // popover opens already showing today at the right scroll position.
            coordinator.prepareForPopoverPresentation()
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
        // Idempotent safety net for shows that don't go through `togglePopover`.
        coordinator.prepareForPopoverPresentation()
        coordinator.isPopoverVisible = true
    }

    public func popoverDidClose(_ notification: Notification) {
        coordinator.isPopoverVisible = false
        coordinator.selectedEventForDetail = nil
    }
}

