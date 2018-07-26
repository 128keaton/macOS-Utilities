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
        
        progressWheel?.startAnimation(self)
        createLibraryFolder()
        readPreferences()
        NSWorkspace.shared.notificationCenter.addObserver(self, selector: #selector(didMount(_:)), name: NSWorkspace.didMountNotification, object: nil)
        NSWorkspace.shared.notificationCenter.addObserver(self, selector: #selector(didUnmount(_:)), name: NSWorkspace.didUnmountNotification, object: nil)
        // Do any additional setup after loading the view.
    }

    func readPreferences() {
        guard let plistPath = self.getPropertyList()
            else {
                return
        }

        guard let preferences = NSDictionary(contentsOf: plistPath)
            else {
                return
        }
        
        var macOSPath = "/Volumes/Install macOS High Sierra"
        if let newPath = preferences["macOS Volume"] {
                macOSPath = newPath as! String
        }

        
        if FileManager.default.fileExists(atPath: macOSPath) {
            installButton?.isEnabled = true
            progressWheel?.isHidden = true
        }
        
        print(preferences)
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
    
    func getPropertyList() -> URL? {
        let path = NSSearchPathForDirectoriesInDomains(.libraryDirectory, .userDomainMask, true)[0] as String
        let url = NSURL(fileURLWithPath: path)
        if let pathComponent = url.appendingPathComponent("ER2") {
            let filePath = pathComponent.path
            let fileManager = FileManager.default
            if fileManager.fileExists(atPath: filePath) {
                let pathComponent = pathComponent.appendingPathComponent("com.er2.applications.plist")
                let filePath = pathComponent.path
                if fileManager.fileExists(atPath: filePath) {
                    return pathComponent
                } else {
                    return copyPlist()
                }
                
            } else {
                return copyPlist()
            }
        } else {
            print("Unable to access library folder")
        }
        
        return nil
    }
    
    func copyPlist() -> URL! {
        let path = NSSearchPathForDirectoriesInDomains(.libraryDirectory, .userDomainMask, true)[0] as String
        let url = NSURL(fileURLWithPath: path)
        if let pathComponent = url.appendingPathComponent("ER2")?.appendingPathComponent("com.er2.applications.plist") {
            let filePath = pathComponent.path
            let fileManager = FileManager.default
            if !fileManager.fileExists(atPath: filePath) {
                let defaultPlist = Bundle.main.path(forResource: "com.er2.applications", ofType: "plist")
                try! fileManager.copyItem(atPath: defaultPlist!, toPath: filePath)
                return pathComponent
            } else {
                return pathComponent
            }
        } else {
            createLibraryFolder()
            return copyPlist()
        }
    }
    
    func createLibraryFolder() {
        let path = NSSearchPathForDirectoriesInDomains(.libraryDirectory, .userDomainMask, true)[0] as String
        let url = NSURL(fileURLWithPath: path)
        if let pathComponent = url.appendingPathComponent("ER2") {
            let filePath = pathComponent.path
            let fileManager = FileManager.default
            print(filePath)
            if !fileManager.fileExists(atPath: filePath) {
                try! FileManager.default.createDirectory(at: pathComponent, withIntermediateDirectories: true)
            }
        } else {
            print("Unable to access library folder")
        }
    }
}

