//
//  InfoPopoverViewController.swift
//  macOS Utilities
//
//  Created by Keaton Burleson on 2/15/19.
//  Copyright © 2019 Keaton Burleson. All rights reserved.
//

import Foundation
import AppKit

class InfoPopoverViewController: NSViewController {
    @IBOutlet weak var messageLabel: NSTextField?
    var message: String? = nil

    override func viewDidLoad() {
        super.viewDidLoad()
        messageLabel?.stringValue = self.message!
    }
}
