//
//  NSCollectionAppCell.swift
//  macOS Utilities
//
//  Created by Keaton Burleson on 7/26/18.
//  Copyright © 2018 Keaton Burleson. All rights reserved.
//

import Foundation
import AppKit

class NSCollectionAppCell: NSCollectionViewItem {
    @IBOutlet weak var icon: NSImageView?
    @IBOutlet weak var titleLabel: NSTextField?

    public var regularImage: NSImage? = nil
    public var darkenedImage: NSImage? = nil
    public var isDisabled: Bool = false
    public var application: Application? = nil

    override var isSelected: Bool {
        didSet {
            icon?.image = isSelected ? self.darkenedImage : self.regularImage
        }
    }
    override func viewDidLoad() {
        if let titleLabel = self.titleLabel {

            self.icon?.alphaValue = 0.0
            titleLabel.alphaValue = 0.0

            if titleLabel.stringValue != "" {
                if titleLabel.stringValue.count > 13 {
                    titleLabel.font = NSFont.systemFont(ofSize: 8)
                } else {
                    titleLabel.font = NSFont.systemFont(ofSize: 10)
                }
            }
        }
    }

    public func show() {
        NSAnimationContext.runAnimationGroup { (context) in
            context.duration = 0.5
            self.icon?.animator().alphaValue = 1.0
            self.titleLabel?.animator().alphaValue = 1.0
        }
    }

    public func hide() {
        NSAnimationContext.runAnimationGroup { (context) in
            context.duration = 0.5
            self.icon?.animator().alphaValue = 0.0
            self.titleLabel?.animator().alphaValue = 0.0
        }
    }
}

