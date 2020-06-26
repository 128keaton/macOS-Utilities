//
//  OSInstallWindow.swift
//  macOS Utilities
//
//  Created by Keaton Burleson on 6/25/20.
//  Copyright © 2020 Keaton Burleson. All rights reserved.
//

import Foundation
class OSInstallWindow: NSWindowController {
    var installController: OSInstall?
    var backdropWindow: OSInstallBackdrop?

    override func windowDidLoad() {
        let storyboard = NSStoryboard(name: "OSInstall", bundle: Bundle.main)

        self.installController = self.window?.contentViewController as? OSInstall
        
        self.window?.alphaValue = 0
        self.window?.isMovable = false

        #if RELEASE
            self.backdropWindow = storyboard.instantiateController(withIdentifier: "OSInstallBackdrop") as? OSInstallBackdrop
            self.backdropWindow?.showWindow(self)
            self.backdropWindow?.sendToBackground()
            NSApp.windows[0].level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.maximumWindow)))
        #endif
    }
    
    override func showWindow(_ sender: Any?) {
        super.showWindow(sender)
        
        NSAnimationContext.runAnimationGroup { (context) in
            context.duration = 0.9
            self.window?.animator().alphaValue = 1
        }
    }
}
