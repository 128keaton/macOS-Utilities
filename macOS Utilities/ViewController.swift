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

    private var sections: [String: [String: String]] = [:]
    private var disabledPaths: [IndexPath] = []

    private var macOSVolume = "/Volumes/Install macOS High Sierra" {
        didSet {
            writePreferences()
        }
    }
    private var macOSVersion = "10.13"

    private var fallbackMacOSVolume = "/Volumes/Install macOS High Sierra"
    private var fallbackMacOSVersion = "10.13"

    private var hostDiskPath = "/Library/Server/Web/Data/Sites/Default/Installers"
    private var hostDiskServer = "172.16.5.5" {
        didSet {
            getInstallVersion()
        }
    }

    private let prohibatoryIcon = NSImage(named: NSImage.Name(rawValue: "stop"))
    private let libraryFolder = AppFolder.Library

    override func viewDidLoad() {
        super.viewDidLoad()
        createLibraryFolder()
        configureCollectionView()
        progressWheel?.startAnimation(self)
        registerForNotifications()

        let quintClickGesture = NSClickGestureRecognizer(target: self, action: #selector(startEasterEgg))

        quintClickGesture.numberOfClicksRequired = 5
        self.collectionView.addGestureRecognizer(quintClickGesture)

        os_log("Launched macOS Utilities")
    }

    override func viewDidAppear() {
        readPreferences()
    }

    func getInstallVersion() {
        guard let macOSInstallProperties = ModelYearDetermination().determineInstallableVersion()
            else {
                showErrorAlert(title: "Unable to image this machine", message: "This machine is too old to be imaged (\(ModelYearDetermination().modelIdentifier)). If this is a MacPro4,1, you need to update the firmware first.")
                return
        }

        print("Maximum macOS Version Determined: \(macOSInstallProperties)")

        macOSVersion = macOSInstallProperties.keys.first!.rawValue
        macOSVolume = "/Volumes/\(String(describing: macOSInstallProperties[macOSInstallProperties.keys.first!]!.rawValue))"
        print(macOSVolume)
        let taskQueue = DispatchQueue.global(qos: DispatchQoS.QoSClass.background)
        taskQueue.async {
            guard let error = self.mountInstallDisk()
                else {
                    return
            }
            DispatchQueue.main.async(execute: {
                self.showErrorAlert(title: "Image mounting error", message: error)
            })
        }
    }

    func mountInstallDisk() -> String? {
        var task = Process()
        var pipe = Pipe()

        task.launchPath = "/bin/mkdir"
        task.arguments = ["/var/tmp/Installers"]
        task.standardError = pipe
        task.launch()
        task.waitUntilExit()

        var handle = pipe.fileHandleForReading
        var data = handle.readDataToEndOfFile()
        var printing = String (data: data, encoding: String.Encoding.utf8)

        print(printing!)

        task = Process()
        pipe = Pipe()
        task.launchPath = "/sbin/mount"
        task.arguments = ["-t", "nfs", "-o", "soft,intr,rsize=8192,wsize=8192,timeo=900,retrans=3,proto=tcp", "\(hostDiskServer):\(hostDiskPath)", "/var/tmp/Installers"]
        task.standardError = pipe
        task.launch()
        task.waitUntilExit()

        handle = pipe.fileHandleForReading
        data = handle.readDataToEndOfFile()
        printing = String (data: data, encoding: String.Encoding.utf8)

        print(printing!)

        task = Process()
        pipe = Pipe()
        task.standardError = pipe
        task.launchPath = "/usr/bin/hdiutil"
        task.arguments = ["mount", "/var/tmp/Installers/\(macOSVersion).dmg"]
        task.launch()
        task.waitUntilExit()

        handle = pipe.fileHandleForReading
        data = handle.readDataToEndOfFile()
        printing = String (data: data, encoding: String.Encoding.utf8)

        if((printing?.contains("hdiutil: mount failed"))!) {
            macOSVersion = fallbackMacOSVersion
            macOSVolume = fallbackMacOSVolume
            let _ = mountInstallDisk()
            return "Unable to find image /var/tmp/Installers/\(macOSVersion).dmg. Falling back on previous version"

        }
        return nil
    }


    func showErrorAlert(title: String, message: String) {
        let alert: NSAlert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.alertStyle = .critical
        alert.addButton(withTitle: "OK :(")
        alert.runModal()
    }


    func registerForNotifications() {
        NSWorkspace.shared.notificationCenter.addObserver(self, selector: #selector(didMount(_:)), name: NSWorkspace.didMountNotification, object: nil)
        NSWorkspace.shared.notificationCenter.addObserver(self, selector: #selector(didUnmount(_:)), name: NSWorkspace.didUnmountNotification, object: nil)
    }

    func writePreferences() {
        guard let plistPath = self.getPropertyList()
            else {
                return
        }
        guard let preferences = NSMutableDictionary(contentsOf: plistPath)
            else {
                return
        }

        preferences["macOS Volume"] = macOSVolume
        preferences["macOS Version"] = macOSVersion

        preferences.write(to: plistPath, atomically: true)
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

        print(preferences)

        guard let localSections = preferences["Applications"] as? [String: Any]
            else {
                return
        }

        guard let serverIP = preferences["Server IP"] as? String
            else {
                return
        }

        guard let serverPath = preferences["Server Path"] as? String
            else {
                return
        }

        hostDiskPath = serverPath
        hostDiskServer = serverIP

        for (title, applications) in localSections {
            sections[title] = applications as? [String: String]
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
        let filePath = "/Applications/Install macOS.app"

        if FileManager.default.fileExists(atPath: filePath) {
            os_log("Starting macOS Install")
            NSWorkspace.shared.open(URL(fileURLWithPath: "/Applications/Install macOS.app"))
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
                os_log("macOS Installer Volume mounted -- macOS Install possible at this time")
            }
        }
    }

    @objc func didUnmount(_ notification: NSNotification) {
        if let devicePath = notification.userInfo!["NSDevicePath"] as? String {
            if (devicePath.contains(macOSVolume)) {
                progressWheel?.isHidden = false
                installButton?.isEnabled = false
                os_log("macOS Installer Volume unmounted -- macOS Install impossible at this time")
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

    @IBAction func ejectCDTray(_ sender: NSMenuItem) {
        let ejectProcess = Process()
        ejectProcess.launchPath = "/usr/bin/drutil"
        ejectProcess.arguments = ["tray", "eject"]
        ejectProcess.launch()
    }
}
extension ViewController: NSCollectionViewDataSource {
    func collectionView(_ collectionView: NSCollectionView, didSelectItemsAt indexPaths: Set<IndexPath>) {
        let indexPath = indexPaths.first!

        if !disabledPaths.contains(indexPath) {
            let sortedSectionTitles = Array(sections.keys).sorted { $0 < $1 }

            let sectionTitle = sortedSectionTitles[indexPath.section]
            let appList = sections[sectionTitle]
            let appName = Array(appList!.keys).sorted { $0 < $1 }[indexPath.item]
            let appPath = appList![appName]

            openApplication(atPath: appPath!)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.06) {
                collectionView.deselectItems(at: indexPaths)
            }
        }
    }

    func numberOfSections(in collectionView: NSCollectionView) -> Int {
        return sections.keys.count
    }

    func collectionView(_ collectionView: NSCollectionView, numberOfItemsInSection section: Int) -> Int {
        let key = Array(sections.keys)[section]
        return (sections[key])!.keys.count
    }


    func collectionView(_ collectionView: NSCollectionView, itemForRepresentedObjectAt
        indexPath: IndexPath) -> NSCollectionViewItem {
        let item = collectionView.makeItem(withIdentifier: NSUserInterfaceItemIdentifier(rawValue: "NSCollectionAppCell"), for: indexPath)
        guard let collectionViewItem = item as? NSCollectionAppCell else { return item }

        let sortedSectionTitles = Array(sections.keys).sorted { $0 < $1 }

        let sectionTitle = sortedSectionTitles[indexPath.section]

        let appList = sections[sectionTitle]

        let appName = Array(appList!.keys).sorted { $0 < $1 }[indexPath.item]
        let appPath = appList![appName]

        if let image = findIconFor(applicationPath: appPath!) {
            collectionViewItem.icon?.image = image
            collectionViewItem.regularImage = image
            collectionViewItem.darkenedImage = image.darkened()
            collectionViewItem.titleLabel?.stringValue = appName
        } else {
            collectionViewItem.titleLabel?.stringValue = "Invalid path"
            collectionViewItem.icon?.image = prohibatoryIcon!
            collectionViewItem.regularImage = prohibatoryIcon!
            collectionViewItem.darkenedImage = prohibatoryIcon!.darkened()
            disabledPaths.append(indexPath)
        }

        return item
    }

    func findIconFor(applicationPath: String) -> NSImage? {
        let path = applicationPath + "/Contents/Info.plist"
        guard let infoDictionary = NSDictionary(contentsOfFile: path)
            else {
                return nil
        }

        guard let imageName = (infoDictionary["CFBundleIconFile"] as? String)
            else {
                return nil
        }

        var imagePath = "\(applicationPath)/Contents/Resources/\(imageName)"

        if !imageName.contains(".icns") {
            imagePath = imagePath + ".icns"
        }

        return NSImage(contentsOfFile: imagePath)
    }

    @objc func startEasterEgg() {
        for cell in self.collectionView.visibleItems() as! [NSCollectionAppCell] {
            buildAnimation(view: (cell.icon)!)
        }
    }

    func buildAnimation(view: NSView) {
        let basicAnimation = CABasicAnimation(keyPath: "transform.rotation")
        basicAnimation.timingFunction = CAMediaTimingFunction(name: kCAMediaTimingFunctionLinear)
        basicAnimation.fromValue = (0 * (Double.pi / 180))
        basicAnimation.toValue = (360 * (Double.pi / 180))
        basicAnimation.duration = 1.0
        basicAnimation.repeatCount = .infinity

        setAnchorPoint(anchorPoint: CGPoint(x: 0.5, y: 0.5), forView: view)
        view.layer?.add(basicAnimation, forKey: "transform")
    }

    func setAnchorPoint(anchorPoint: CGPoint, forView view: NSView) {
        let newPoint = NSPoint(x: view.bounds.size.width * anchorPoint.x, y: view.bounds.size.height * anchorPoint.y)
        let oldPoint = NSPoint(x: view.bounds.size.width * (view.layer?.anchorPoint.x)!, y: view.bounds.size.height * (view.layer?.anchorPoint.y)!)

        newPoint.applying((view.layer?.affineTransform())!)
        oldPoint.applying((view.layer?.affineTransform())!)

        var position = view.layer?.position
        position?.x -= oldPoint.x
        position?.x += newPoint.x

        position?.y -= oldPoint.y
        position?.y += newPoint.y

        view.layer?.position = position!
        view.layer?.anchorPoint = anchorPoint
    }
}
