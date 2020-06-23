//
//  AppCellView.swift
//  macOS Utilities
//
//  Created by Keaton Burleson on 6/23/20.
//  Copyright © 2020 Keaton Burleson. All rights reserved.
//

import Foundation

class AppCellView: NSTableCellView {
    @IBOutlet weak var icon: NSImageView?
    @IBOutlet weak var titleLabel: NSTextField?
    @IBOutlet weak var detailLabel: NSTextField?

    public var regularImage: NSImage? = nil
    public var darkenedImage: NSImage? = nil
    public var isDisabled: Bool = false
    public var application: Application? = nil {
        didSet {
            if let application = application {
                self.icon?.image = application.icon
                self.titleLabel?.stringValue = application.name

                if let appDescription = application.appDescription {
                    self.detailLabel?.stringValue = appDescription
                } else {
                    self.detailLabel?.stringValue = "Version \(application.getApplicationVersion())"
                }
            }
        }
    }

    var isSelected: Bool = false {
        didSet {
            icon?.image = isSelected ? self.darkenedImage : self.regularImage
        }
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        self.icon?.alphaValue = 0.0
        self.titleLabel?.alphaValue = 0.0
        self.detailLabel?.alphaValue = 0.0
    }

    public func show() {
        NSAnimationContext.runAnimationGroup { (context) in
            context.duration = 0.5
            self.icon?.animator().alphaValue = 1.0
            self.titleLabel?.animator().alphaValue = 1.0
            self.detailLabel?.animator().alphaValue = 1.0
        }
    }

    public func hide() {
        NSAnimationContext.runAnimationGroup { (context) in
            context.duration = 0.5
            self.icon?.animator().alphaValue = 0.0
            self.titleLabel?.animator().alphaValue = 0.0
            self.detailLabel?.animator().alphaValue = 0.0
        }
    }
}
