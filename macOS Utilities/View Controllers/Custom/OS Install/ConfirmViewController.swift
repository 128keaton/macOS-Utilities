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

    var versionToInstall: String = "" {
        didSet {
            self.versionLabel?.stringValue = "Installing macOS \(self.versionToInstall)"
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        self.versionLabel?.stringValue = "Installing macOS \(self.versionToInstall)"
    }
}
