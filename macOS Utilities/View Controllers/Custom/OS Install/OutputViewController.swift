//
//  OutputViewController.swift
//  macOS Utilities
//
//  Created by Keaton Burleson on 6/25/20.
//  Copyright © 2020 Keaton Burleson. All rights reserved.
//

import Foundation

class OutputViewController: OSInstallStep {
    @IBOutlet var outputTextView: NSTextView?
    @IBOutlet var progressIndicator: NSProgressIndicator?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.progressIndicator?.startAnimation(self)
        OSInstallHelper.kickoffInstaller()
    }
    
}
