//
//  ConfirmViewController.swift
//  macOS Utilities
//
//  Created by Keaton Burleson on 6/25/20.
//  Copyright © 2020 Keaton Burleson. All rights reserved.
//

import Foundation

class ConfirmViewController: OSInstallStep {
    @IBOutlet var versionLabel: NSTextField?

   

    override func viewDidLoad() {
        super.viewDidLoad()

        if let installer = OSInstallHelper.getInstaller() {
            self.versionLabel?.stringValue = "Installing \(installer.version.name)"
        }

    }
}
