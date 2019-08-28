//
//  XLOverlayLog.swift
//  macOS Utilities
//
//  Created by Keaton Burleson on 8/27/19.
//  Copyright © 2019 Keaton Burleson. All rights reserved.
//

import Foundation

class XLOverlayLog: XLLogger {
    public var overlayOpacity: Float
    public var textFont: NSFont

    private (set) public var isHidden = true

    private var logWindow: NSWindow?
    private var textView: NSTextView?

    public static let shared: XLOverlayLog = XLOverlayLog()

    override init() {
        self.overlayOpacity = 0.85
        self.textFont = NSFont(name: "Menlo", size: 11.0)!

        super.init()

        self.format = "[%l / %P] %M"
        self.createLogWindow()
    }

    private func createLogWindow() {
        let logWindow = NSWindow(contentRect: NSRect(x: 100, y: 100, width: 1000, height: 200), styleMask: .init(arrayLiteral: .resizable, .fullSizeContentView, .titled), backing: .buffered, defer: true)

        logWindow.level = .floating
        logWindow.isExcludedFromWindowsMenu = true
        logWindow.isMovableByWindowBackground = true
        logWindow.backgroundColor = NSColor.black
        logWindow.hasShadow = false
        logWindow.setFrameUsingName(self.className)
        logWindow.alphaValue = 0.0
        logWindow.titlebarAppearsTransparent = true
        logWindow.titleVisibility = .hidden
        logWindow.showsToolbarButton = false
        logWindow.standardWindowButton(NSWindow.ButtonType.miniaturizeButton)?.isHidden = true
        logWindow.standardWindowButton(NSWindow.ButtonType.closeButton)?.isHidden = true
        logWindow.standardWindowButton(NSWindow.ButtonType.zoomButton)?.isHidden = true

        let scrollView = NSScrollView(frame: NSInsetRect(logWindow.contentView!.bounds, 4, 8))

        scrollView.autoresizingMask = .init(arrayLiteral: .width, .height)
        scrollView.drawsBackground = false
        scrollView.hasHorizontalScroller = false
        scrollView.hasVerticalScroller = true

        logWindow.contentView?.addSubview(scrollView)

        let textView = NSTextView(frame: scrollView.bounds)

        textView.autoresizingMask = scrollView.autoresizingMask
        textView.isRichText = true
        textView.isEditable = false
        textView.isSelectable = false
        textView.drawsBackground = false
        textView.string = ""

        scrollView.documentView = textView


        self.textView = textView
        self.logWindow = logWindow
    }

    public func show() {
        if let logWindow = self.logWindow {
            logWindow.alphaValue = 0.0
            logWindow.orderFront(self)

            NSAnimationContext.runAnimationGroup({ context in
                context.duration = 0.25
                context.timingFunction = CAMediaTimingFunction(name: CAMediaTimingFunctionName.easeInEaseOut)
                logWindow.animator().alphaValue = CGFloat(self.overlayOpacity)
            }, completionHandler: {
                self.isHidden = false
            })
        }
    }

    public func hide() {
        if let logWindow = self.logWindow {
            logWindow.alphaValue = CGFloat(self.overlayOpacity)

            NSAnimationContext.runAnimationGroup({ context in
                context.duration = 0.25
                context.timingFunction = CAMediaTimingFunction(name: CAMediaTimingFunctionName.easeInEaseOut)
                logWindow.animator().alphaValue = 0.0
            }, completionHandler: {
                logWindow.orderOut(self)
                self.isHidden = true
            })

        }
    }

    override func logRecord(_ record: XLLogRecord) {
        if let textView = self.textView, let logWindow = self.logWindow {
            let formattedMessage = self.formatRecord(record)
            let attributes = [NSAttributedString.Key.font: self.textFont, NSAttributedString.Key.foregroundColor: getColorFor(record)]

            DispatchQueue.main.async {
                let string = NSAttributedString(string: formattedMessage, attributes: attributes)

                textView.textStorage?.append(string)
                textView.scrollRangeToVisible(NSRange(location: textView.textStorage!.length, length: 0))


                if logWindow.alphaValue == CGFloat(self.overlayOpacity) {
                    logWindow.orderFront(nil)
                }
            }
        }
    }

    private func getColorFor(_ record: XLLogRecord) -> NSColor {
        switch record.level {
        case .logLevel_Debug:
            return NSColor.systemOrange
        case .logLevel_Verbose:
            return NSColor.systemPink
        case .logLevel_Error:
            return NSColor.systemRed
        default:
            return NSColor.systemBlue
        }
    }
}
