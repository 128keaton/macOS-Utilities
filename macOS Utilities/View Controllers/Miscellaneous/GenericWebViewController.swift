//
//  GenericWebViewController.swift
//  macOS Utilities
//
//  Created by Keaton Burleson on 8/27/19.
//  Copyright © 2019 Keaton Burleson. All rights reserved.
//

import Foundation
import Cocoa
import WebKit

class GenericWebViewController: NSViewController {
    @IBOutlet weak private var titleLabel: NSTextField!
    @IBOutlet weak private var webView: WebView!
    
    public var contentString: String = ""
    public var titleString: String = "WebView"
    public var baseURL: URL? = nil
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.webView.layer?.cornerRadius = 6
        self.webView.layer?.masksToBounds = true
        
        self.titleLabel.stringValue = titleString
    }
    
    override func viewDidAppear() {
        super.viewDidAppear()
        
        self.titleLabel.stringValue = titleString
        if let validBaseURL = self.baseURL {
            self.webView.mainFrame.loadHTMLString(contentString, baseURL: validBaseURL)
        }
    }
    
    @IBAction private func closeWindow(_ sender: NSButton){
        self.view.window?.close()
    }
}
