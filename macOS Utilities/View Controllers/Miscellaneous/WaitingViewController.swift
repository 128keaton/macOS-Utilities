//
//  WaitingViewController.swift
//  macOS Utilities
//
//  Created by Keaton Burleson on 5/13/19.
//  Copyright © 2019 Keaton Burleson. All rights reserved.
//

import Foundation
import Cocoa
import CocoaLumberjack

class WaitingViewController: NSViewController{
    @IBOutlet weak var waitingProgressBar: NSProgressIndicator!
    
    override func viewDidLoad() {
        waitingProgressBar.startAnimation(self)
    }
    
    @IBAction func quitNow(_ sender: NSButton){
        NotificationCenter.default.post(name: GlobalNotifications.quitNow, object: nil)
    }
}
