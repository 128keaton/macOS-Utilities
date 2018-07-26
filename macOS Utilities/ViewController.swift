//
//  ViewController.swift
//  macOS Utilities
//
//  Created by Keaton Burleson on 7/23/18.
//  Copyright © 2018 Keaton Burleson. All rights reserved.
//

import Cocoa
import AppFolder
import os

class ViewController: NSViewController, NSCollectionViewDelegate {
    @IBOutlet weak var installButton: NSButton?
    @IBOutlet weak var progressWheel: NSProgressIndicator?
    @IBOutlet weak var collectionView: NSCollectionView!

    private var sections: [Int: Int] = [:]
    private var applications: [String: [String: String]] = [:]
    private var macOSVolume = "/Volumes/Install macOS High Sierra"
    private var macOSVersion = "10.13"

    private let libraryFolder = AppFolder.Library

    override func viewDidLoad() {
        super.viewDidLoad()
        createLibraryFolder()
        configureCollectionView()
        progressWheel?.startAnimation(self)
        readPreferences()
        registerForNotifications()
        os_log("Launched macOS Utilities")
    }

    func registerForNotifications() {
        NSWorkspace.shared.notificationCenter.addObserver(self, selector: #selector(didMount(_:)), name: NSWorkspace.didMountNotification, object: nil)
        NSWorkspace.shared.notificationCenter.addObserver(self, selector: #selector(didUnmount(_:)), name: NSWorkspace.didUnmountNotification, object: nil)
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

        if let path = preferences["macOS Volume"] {
            macOSVolume = path as! String
        }

        if let version = preferences["macOS Version"] {
            macOSVersion = "\(version)"
        }

        guard let localSections = preferences["Applications"] as? [String: Any]
            else {
                return
        }

        for (title, listing) in localSections {
            applications[title] = listing as? [String: String]
        }

        if FileManager.default.fileExists(atPath: macOSVolume) {
            installButton?.isEnabled = true
            progressWheel?.isHidden = true
        }
        self.collectionView.reloadData()
        os_log("Successfully loaded plist into dictionary")
    }

    func openApplication(atPath path: String) {
        os_log("Opening application")
        print("Opening application at: \(path)")
        NSWorkspace.shared.open(URL(fileURLWithPath: path))
    }

    @IBAction func startOSInstall(sender: NSButton) {
        let filePath = "/Applications/Install \(macOSVersion).app"

        if FileManager.default.fileExists(atPath: filePath) {
            os_log("Starting macOS Install")
            NSWorkspace.shared.open(URL(fileURLWithPath: "/Applications/Install \(macOSVersion).app"))
        } else {
            os_log("Unable to start macOS Install. Missing kickstart application")
            let alert: NSAlert = NSAlert()
            alert.messageText = "Unable to start macOS Install"
            alert.informativeText = "macOS Utilities was unable find application \n \(filePath)"
            alert.alertStyle = .critical
            alert.addButton(withTitle: "OK")
            alert.runModal()
        }
    }

    @objc func didMount(_ notification: NSNotification) {
        if let devicePath = notification.userInfo!["NSDevicePath"] as? String {
            if (devicePath.contains(macOSVolume)) {
                progressWheel?.isHidden = true
                installButton?.isEnabled = true
            }
        }
    }

    @objc func didUnmount(_ notification: NSNotification) {
        if let devicePath = notification.userInfo!["NSDevicePath"] as? String {
            if (devicePath.contains(macOSVolume)) {
                progressWheel?.isHidden = false
                installButton?.isEnabled = false
            }
        }
    }

    fileprivate func configureCollectionView() {
        let flowLayout = NSCollectionViewFlowLayout()
        flowLayout.itemSize = NSSize(width: 100, height: 120.0)
        flowLayout.sectionInset = NSEdgeInsets(top: 10.0, left: 20.0, bottom: 10.0, right: 20.0)
        flowLayout.minimumInteritemSpacing = 20.0
        flowLayout.minimumLineSpacing = 20.0

        collectionView.collectionViewLayout = flowLayout
        view.wantsLayer = true
        collectionView.layer?.cornerRadius = 12
    }

    fileprivate func createLibraryFolder() {
        let url = libraryFolder.url
        let fileManager = FileManager.default
        let pathComponent = url.appendingPathComponent("ER2")
        try! fileManager.createDirectory(atPath: pathComponent.path, withIntermediateDirectories: true, attributes: nil)
    }

    fileprivate func getPropertyList() -> URL? {
        let url = libraryFolder.url
        let pathComponent = url.appendingPathComponent("ER2")
        let filePath = pathComponent.path
        let fileManager = FileManager.default
        if fileManager.fileExists(atPath: filePath) {
            let pathComponent = pathComponent.appendingPathComponent("com.er2.applications.plist")
            let filePath = pathComponent.path
            if fileManager.fileExists(atPath: filePath) {
                return pathComponent
            } else {
                createLibraryFolder()
                return copyPlist()
            }

        } else {
            return copyPlist()
        }
    }

    fileprivate func copyPlist() -> URL! {
        let url = libraryFolder.url
        let pathComponent = url.appendingPathComponent("ER2").appendingPathComponent("com.er2.applications.plist")
        let filePath = pathComponent.path
        let fileManager = FileManager.default
        if !fileManager.fileExists(atPath: filePath) {
            let defaultPlist = Bundle.main.path(forResource: "com.er2.applications", ofType: "plist")
            try! fileManager.copyItem(atPath: defaultPlist!, toPath: filePath)
            return pathComponent
        } else {
            return pathComponent
        }

    }
}
extension ViewController: NSCollectionViewDataSource {
    func collectionView(_ collectionView: NSCollectionView, didSelectItemsAt indexPaths: Set<IndexPath>) {
        let indexPath = indexPaths.first!
        let key = Array(applications.keys)[indexPath.section]
        let appList = applications[key]
        let appName = Array(appList!.keys)[indexPath.item]
        let appPath = appList![appName]

        openApplication(atPath: appPath!)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.06) {
            collectionView.deselectItems(at: indexPaths)
        }
    }

    func numberOfSections(in collectionView: NSCollectionView) -> Int {
        return applications.keys.count
    }

    func collectionView(_ collectionView: NSCollectionView, numberOfItemsInSection section: Int) -> Int {
        let key = Array(applications.keys)[section]
        return (applications[key])!.keys.count
    }


    func collectionView(_ collectionView: NSCollectionView, itemForRepresentedObjectAt
    indexPath: IndexPath) -> NSCollectionViewItem {
        let item = collectionView.makeItem(withIdentifier: NSUserInterfaceItemIdentifier(rawValue: "NSCollectionAppCell"), for: indexPath)
        guard let collectionViewItem = item as? NSCollectionAppCell else { return item }

        let key = Array(applications.keys)[indexPath.section]
        let appList = applications[key]
        let appName = Array(appList!.keys)[indexPath.item]
        let appPath = appList![appName]

        if let image = findIconFor(applicationPath: appPath!) {
            collectionViewItem.icon?.image = image
            collectionViewItem.regularImage = image
            collectionViewItem.darkenedImage = image.darkened()
            collectionViewItem.titleLabel?.stringValue = appName
        }
    
        return item
    }

    func findIconFor(applicationPath: String) -> NSImage? {
        let path = applicationPath + "/Contents/Info.plist"
        let infoDictionary = NSDictionary(contentsOfFile: path)
        let imagePath = "\(applicationPath)/Contents/Resources/\(infoDictionary!["CFBundleIconFile"]!).icns"

        return NSImage(contentsOfFile: imagePath)
    }
}
