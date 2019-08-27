//
//  InstallerCellView.swift
//  macOS Utilities
//
//  Created by Keaton Burleson on 4/9/19.
//  Copyright © 2019 Keaton Burleson. All rights reserved.
//

import Foundation
import AppKit

class InstallerCellView: NSTableCellView {
    @IBOutlet weak var installerIconView: NSImageView?
    @IBOutlet weak var installerNameLabel: NSTextField?
    @IBOutlet weak var installerVersionLabel: NSTextField?

    var installer: Installer? = nil {
        didSet {
            update()
        }
    }

    override func awakeFromNib() {
        super.awakeFromNib()
        update()
    }

    public func update() {
        guard let installer = self.installer
            else {
                return
        }

        installerIconView?.image = installer.icon
        installerNameLabel?.stringValue = installer.version.name
        installerVersionLabel?.stringValue = installer.isFakeInstaller ? "Fake Installer" : "\(installer.version.number)"
        setTextColor(canInstall: installer.canInstall)
    }

    private func setTextColor(canInstall: Bool) {
        if canInstall {
            installerNameLabel?.textColor = (NSApplication.shared.isDarkMode(view: self) ? NSColor.white : NSColor.black)
            installerVersionLabel?.textColor = (NSApplication.shared.isDarkMode(view: self) ? NSColor.white : NSColor.black)
        } else {
            installerNameLabel?.textColor = NSColor.gray
            installerVersionLabel?.textColor = NSColor.gray
        }
    }
}
