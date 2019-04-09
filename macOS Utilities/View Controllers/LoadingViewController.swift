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
    
    public func setLoadingText(loadingText: String){
        loadingTextField?.ti = loadingText
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
    }
    
    override func viewWillAppear() {
        loadingSpinner?.startSpinning()
    }
    
    override func viewWillDisappear() {
        loadingSpinner?.stopSpinning()
    }
}
