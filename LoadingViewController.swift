//
//  LoadingController.swift
//  macOS Utilities
//
//  Created by Keaton Burleson on 4/6/19.
//  Copyright © 2019 Keaton Burleson. All rights reserved.
//

import Foundation
import AppKit

class LoadingViewController: NSViewController {
    @IBOutlet var loadingSpinner: NSProgressIndicator?
    @IBOutlet var loadingTextField: NSTextField?
    
    public var loadingText: String = "Loading" {
        didSet {
            updateLoadingLabel()
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        updateLoadingLabel()
    }
    
    func updateLoadingLabel() {
        guard isViewLoaded else {
            return
        }
        self.loadingTextField?.stringValue = self.loadingText
    }
    
    override func viewWillAppear() {
        loadingSpinner?.startSpinning()
    }
    
    override func viewWillDisappear() {
        loadingSpinner?.stopSpinning()
    }
}
