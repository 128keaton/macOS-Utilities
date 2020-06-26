//
//  OSInstallBackdrop.swift
//  macOS Utilities
//
//  Created by Keaton Burleson on 6/25/20.
//  Copyright © 2020 Keaton Burleson. All rights reserved.
//

import Foundation

class OSInstallBackdrop: NSWindowController {
    override func windowDidLoad() {
        super.windowDidLoad()

        if let backgroundWindow = self.window,
            let mainDisplayFrame = NSScreen.main?.frame,
            let mainScreenFrame = NSScreen.main?.frame,
            let mainScreenOrigin = NSScreen.main?.frame.origin {
            backgroundWindow.contentRect(forFrameRect: mainDisplayFrame)
            backgroundWindow.setFrame(mainScreenFrame, display: true)
            backgroundWindow.setFrameOrigin(mainScreenOrigin)
            backgroundWindow.level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.maximumWindow) - 1))

        }
    }

    func sendToBackground() {
        self.window?.orderBack(self)
    }
}
