//
//  AppKit-Extensions.swift
//  macOS Utilities
//
//  Created by Keaton Burleson on 4/19/19.
//  Copyright © 2019 Keaton Burleson. All rights reserved.
//

import Foundation
import AppKit

/// NSControl - adds hide/show with animations
extension NSControl {
    public func shake(duration durationOfShake: Double = 0.4, delay: Double = 0.1) {
        let animation = CAKeyframeAnimation(keyPath: "transform.translation.x")
        animation.timingFunction = CAMediaTimingFunction(name: CAMediaTimingFunctionName.linear)
        animation.duration = durationOfShake
        animation.values = [-20.0, 20.0, -20.0, 20.0, -10.0, 10.0, -5.0, 5.0, 0.0]

        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            self.layer?.add(animation, forKey: "shake")
        }
    }

    public func hide(animated: Bool = true) {
        DispatchQueue.main.async {
            if animated {
                NSAnimationContext.runAnimationGroup { (context) in
                    context.duration = 0.5
                    self.animator().alphaValue = 0.0
                }
            } else {
                self.alphaValue = 0.0
            }
        }
    }

    public func show(animated: Bool = true) {
        DispatchQueue.main.async {
            NSAnimationContext.runAnimationGroup { (context) in
                context.duration = animated ? 0.5 : 0.0
                self.animator().alphaValue = 1.0
            }
        }
    }

    public func setEnabled(_ flag: Bool = true) {
        if flag {
            return self.enable()
        }
        return self.disable()
    }

    public func disable() {
        NSAnimationContext.runAnimationGroup { (context) in
            context.duration = 0.5
            self.animator().alphaValue = 0.5
        }
    }

    public func enable() {
        NSAnimationContext.runAnimationGroup { (context) in
            context.duration = 0.5
            self.animator().alphaValue = 1.0
        }
    }
}


/// NSLabel - bad name, good @IBInspectable
@IBDesignable class NSHidingTextField: NSTextField {
    /// Set to 'true' if you want to fade in your label with new data manually
    @IBInspectable var shouldHideWhenRunning: Bool = false {
        didSet {
            if self.shouldHideWhenRunning {
                self.alphaValue = 0.0
            } else {
                self.alphaValue = 1.0
            }
        }
    }
}

/// NSLabel - bad name, good @IBInspectable
@IBDesignable class NSHidingImageView: NSImageView {
    /// Set to 'true' if you want to fade in your label with new data manually
    @IBInspectable var shouldHideWhenRunning: Bool = false {
        didSet {
            if self.shouldHideWhenRunning {
                self.alphaValue = 0.0
            } else {
                self.alphaValue = 1.0
            }
        }
    }
}

/// NSLabel - bad name, good @IBInspectable
@IBDesignable class NSHidingButton: NSButton {
    /// Set to 'true' if you want to fade in your label with new data manually
    @IBInspectable var shouldHideWhenRunning: Bool = false {
        didSet {
            if self.shouldHideWhenRunning {
                self.alphaValue = 0.0
            } else {
                self.alphaValue = 1.0
            }
        }
    }
}

extension NSProgressIndicator {
    func stopSpinning() {
        self.isHidden = true
        self.stopAnimation(self)
    }

    func startSpinning() {
        self.startAnimation(self)
        self.isHidden = false
    }
}

extension NSImage {
    func tint(color: NSColor) -> NSImage {
        let image = self.copy() as! NSImage
        image.lockFocus()

        color.set()

        let imageRect = NSRect(origin: NSZeroPoint, size: image.size)
        imageRect.fill(using: .sourceAtop)

        image.unlockFocus()

        return image
    }

    var darkened: NSImage? {
        if(NSGraphicsContext.current !== nil) {
            let size = self.size
            let rect = NSRect(x: 0, y: 0, width: size.width, height: size.height)
            let newImage = self.copy() as! NSImage
            newImage.lockFocus()
            NSColor(calibratedWhite: 0, alpha: 0.33).set()
            rect.fill(using: NSCompositingOperation.sourceAtop)
            newImage.unlockFocus()
            newImage.draw(in: rect, from: rect, operation: .sourceOver, fraction: 0.75)

            return newImage
        }
        return nil
    }
    
    func resize(withSize targetSize: NSSize) -> NSImage? {
        let frame = NSRect(x: 0, y: 0, width: targetSize.width, height: targetSize.height)
        guard let representation = self.bestRepresentation(for: frame, context: nil, hints: nil) else {
            return nil
        }
        let image = NSImage(size: targetSize, flipped: false, drawingHandler: { (_) -> Bool in
            return representation.draw(in: frame)
        })

        return image
    }
}

extension NSApplication {
    public var systemUUID: String? {
        let dev = IOServiceMatching("IOPlatformExpertDevice")
        let platformExpert: io_service_t = IOServiceGetMatchingService(kIOMasterPortDefault, dev)
        let serialNumberAsCFString = IORegistryEntryCreateCFProperty(platformExpert, kIOPlatformUUIDKey as CFString, kCFAllocatorDefault, 0)
        IOObjectRelease(platformExpert)
        let ser: CFTypeRef = serialNumberAsCFString!.takeUnretainedValue()
        if let result = ser as? String {
            return result
        }
        return nil
    }

    public func isDarkMode(view: NSView?) -> Bool {
        if #available(OSX 10.14, *) {
            if let appearance = view?.effectiveAppearance ?? NSAppearance.current {
                return (appearance.name == .darkAqua)
            }
        }
        return false
    }

    public func getName() -> String {
        return Bundle.main.object(forInfoDictionaryKey: "CFBundleName") as! String
    }

    public func getVersion() -> String {
        return Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as! String
    }

    public func getBuild() -> String {
        return Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as! String
    }

    public func getVerboseName() -> String {
        return "\(getName())-v\(getVersion())-b\(getBuild())"
    }

    public func getSerialNumber() -> String? {
        let platformExpert = IOServiceGetMatchingService(kIOMasterPortDefault, IOServiceMatching("IOPlatformExpertDevice"))

        guard platformExpert > 0 else {
            return nil
        }

        guard let serialNumber = (IORegistryEntryCreateCFProperty(platformExpert, kIOPlatformSerialNumberKey as CFString, kCFAllocatorDefault, 0).takeUnretainedValue() as? String) else {
            return nil
        }

        IOObjectRelease(platformExpert)
        return serialNumber
    }

    public func showErrorAlertOnCurrentWindow(title: String, message: String) {
        // Thank you https://github.com/sparkle-project/Sparkle/compare/1.19.0...1.20.0#diff-79d37b7d406b6534ddab8fa541dfc3e7
        if !Thread.isMainThread {
            DispatchQueue.main.async {
                self.showErrorAlertOnCurrentWindow(title: title, message: message)
            }
            return
        }

        var aWindow: NSWindow? = nil

        if let keyWindow = NSApplication.shared.keyWindow {
            aWindow = keyWindow
        } else if let mainWindow = NSApplication.shared.mainWindow {
            aWindow = mainWindow
        } else if let firstWindow = NSApplication.shared.windows.first {
            aWindow = firstWindow
        }

        if let window = aWindow {
            if let contentViewController = window.contentViewController {
                contentViewController.showErrorAlert(title: title, message: message)
            }
        }
    }
}

extension NSViewController {
    func showErrorAlert(title: String, message: String) {
        let alert: NSAlert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.alertStyle = .critical
        alert.addButton(withTitle: "OK")
        DispatchQueue.main.async {
            alert.runModal()
        }
    }

    func showInfoAlert(title: String, message: String) {
        let alert: NSAlert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.alertStyle = .informational
        alert.addButton(withTitle: "OK")
        DispatchQueue.main.async {
            alert.runModal()
        }
    }

    func showInfoAlert(title: String, message: String, completion: @escaping (Bool) -> ()) {
        let alert: NSAlert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.alertStyle = .informational
        alert.addButton(withTitle: "OK")
        DispatchQueue.main.async {
            completion(alert.runModal() == .alertFirstButtonReturn)
        }
    }

    func showConfirmationAlert(question: String, text: String) -> Bool {
        let alert = NSAlert()
        alert.messageText = question
        alert.informativeText = text
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Yes")
        alert.addButton(withTitle: "No")

        return alert.runModal() == .alertFirstButtonReturn
    }

    func showConfirmationAlert(question: String, text: String, window: NSWindow, completionHandler: @escaping (NSApplication.ModalResponse) -> ()) {
        let alert = NSAlert()
        alert.messageText = question
        alert.informativeText = text
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Yes")
        alert.addButton(withTitle: "No")

        alert.beginSheetModal(for: window, completionHandler: completionHandler)
    }
}
