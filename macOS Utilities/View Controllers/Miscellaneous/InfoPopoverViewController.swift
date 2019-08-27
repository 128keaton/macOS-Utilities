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
    @IBOutlet weak var actionButton: NSButton?
    var message: String? = nil
    
    var buttonAction: Selector? = nil
    var buttonText: String? = nil

    override func viewDidLoad() {
        super.viewDidLoad()
        messageLabel?.stringValue = self.message!
        
        if(buttonText != nil && buttonAction != nil){
            actionButton?.action = buttonAction
            actionButton?.title = buttonText!
        }else{
            actionButton?.removeFromSuperview()
        }
    }
}
