//
//  ViewController.swift
//  macOS Utilities
//
//  Created by Keaton Burleson on 7/23/18.
//  Copyright © 2018 Keaton Burleson. All rights reserved.
//

import Cocoa

class ViewController: NSViewController {
    @IBOutlet weak var installButton: NSButton?
    @IBOutlet weak var progressWheel: NSProgressIndicator?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        if FileManager.default.fileExists(atPath: "/Volumes/Install macOS High Sierra") {
            installButton?.isEnabled = true
            progressWheel?.isHidden = true
        }
        progressWheel?.startAnimation(self)
        
        NSWorkspace.shared.notificationCenter.addObserver(self, selector: #selector(didMount(_:)), name: NSWorkspace.didMountNotification, object: nil)
        NSWorkspace.shared.notificationCenter.addObserver(self, selector: #selector(didUnmount(_:)), name: NSWorkspace.didUnmountNotification, object: nil)
        // Do any additional setup after loading the view.
    }

    override var representedObject: Any? {
        didSet {
            // Update the view, if already loaded.
        }
    }

    @IBAction func openLabelApplication(sender: NSButton) {
        NSWorkspace.shared.open(URL(fileURLWithPath: "/Applications/Print Label.app"))
    }

    @IBAction func openDiskUtility(sender: NSButton) {
        NSWorkspace.shared.open(URL(fileURLWithPath: "/Applications/Utilities/Disk Utility.app"))
    }

    @IBAction func openPrime95(sender: NSButton) {
        NSWorkspace.shared.open(URL(fileURLWithPath: "/Applications/Prime95.app"))
    }

    @IBAction func openHeaven(sender: NSButton) {
        NSWorkspace.shared.open(URL(fileURLWithPath: "/Applications/Heaven.app"))
    }

    @IBAction func openSafari(sender: NSButton) {
        NSWorkspace.shared.open(URL(fileURLWithPath: "/Applications/Safari.app"))
    }

    @IBAction func openTerminal(sender: NSButton) {
        NSWorkspace.shared.open(URL(fileURLWithPath: "/Applications/Utilities/Terminal.app"))
    }

    @IBAction func startOSInstall(sender: NSButton) {
        NSWorkspace.shared.open(URL(fileURLWithPath: "/Applications/Install 10.13.app"))
    }

    @objc func didMount(_ notification: NSNotification) {
        if let devicePath = notification.userInfo!["NSDevicePath"] as? String {
            if (devicePath.contains("Install macOS High Sierra")) {
                progressWheel?.isHidden = true
                installButton?.isEnabled = true
            }
        }
    }
    
    @objc func didUnmount(_ notification: NSNotification) {
        if let devicePath = notification.userInfo!["NSDevicePath"] as? String {
            if (devicePath.contains("Install macOS High Sierra")) {
                progressWheel?.isHidden = false
                installButton?.isEnabled = false
            }
        }
    }
}

