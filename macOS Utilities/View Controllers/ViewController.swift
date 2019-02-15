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
    @IBOutlet weak var collectionView: NSCollectionView!
    @IBOutlet weak var installPopupButton: NSPopUpButton?
    @IBOutlet weak var progressSpinner: NSProgressIndicator?
    @IBOutlet weak var metalStatus: NSButton!
    @IBOutlet weak var memoryStatus: NSButton!
    
    private var compatibilityChecker: Compatibility = Compatibility()
    private var versionNumbers: VersionNumbers = VersionNumbers()
    private var diskAgent: MountDisk? = nil {
        didSet {
            diskAgent?.delegate = self
        }
    }

    private var sections: [String: [String: String]] = [:]
    private var disabledPaths: [IndexPath] = []


    private var fallbackMacOSVolume = "/Volumes/Install macOS High Sierra"
    private var fallbackMacOSVersion = "10.13"

    private var hostDiskPath = "/Library/Server/Web/Data/Sites/Default/Installers"
    private var hostDiskServer = "172.16.5.5"

    private let prohibatoryIcon = NSImage(named: NSImage.Name(rawValue: "stop"))
    private let libraryFolder = AppFolder.Library
    private let taskQueue = DispatchQueue.global(qos: DispatchQoS.QoSClass.background)

    override func viewDidLoad() {
        super.viewDidLoad()
        createLibraryFolder()
        configureCollectionView()
        checkForMetal()
        verifyMemoryAmount()
        let quintClickGesture = NSClickGestureRecognizer(target: self, action: #selector(startEasterEgg))

        quintClickGesture.numberOfClicksRequired = 5
        self.collectionView.addGestureRecognizer(quintClickGesture)

        installPopupButton?.isEnabled = false
        startSpinning()
        
        if #available(OSX 10.13, *) {
            if let contentSize = self.collectionView.collectionViewLayout?.collectionViewContentSize {
                self.collectionView.setFrameSize(contentSize)
            }
        }
        
        os_log("Launched macOS Utilities")
    }

    override func viewDidAppear() {
        readPreferences()
    }

    func checkForMetal(){
        if compatibilityChecker.hasMetalGPU{
            metalStatus.image = NSImage(named: NSImage.Name(rawValue: "SuccessIcon"))
        }else{
            metalStatus.image = NSImage(named: NSImage.Name(rawValue: "AlertIcon"))
        }
    }
    
    func verifyMemoryAmount(){
        if compatibilityChecker.hasEnoughMemory{
            memoryStatus.image = NSImage(named: NSImage.Name(rawValue: "SuccessIcon"))
        }else{
            memoryStatus.image = NSImage(named: NSImage.Name(rawValue: "AlertIcon"))
        }
    }
    
    @IBAction func showPopover(sender: NSButton){
        let popoverController = storyboard?.instantiateController(withIdentifier: NSStoryboard.SceneIdentifier(rawValue: "InfoPopoverViewController")) as! InfoPopoverViewController
        
        if(sender == memoryStatus){
            if(compatibilityChecker.hasEnoughMemory){
                popoverController.message = "This machine has more than 8GB of RAM"
            }else{
                popoverController.message = "This machine has less than 8GB of RAM. You can install, but the machine's performance might be dismal."
            }
        }else{
            if(compatibilityChecker.hasMetalGPU){
                popoverController.message = "This machine has one Metal compatible GPU"
            }else{
                popoverController.message = "This machine has no Metal compatible GPUs. If you are installing anything below Mojave, you can safely ignore this warning."
            }
        }
        
        let popover = NSPopover()
        popover.contentSize = NSSize(width: 216, height: 111)
        popover.behavior = .transient
        popover.animates = true
        popover.contentViewController = popoverController
        
        let entryRect = sender.convert(sender.bounds, to: NSApp.mainWindow?.contentView)
        popover.show(relativeTo: entryRect, of: (NSApp.mainWindow?.contentView)!, preferredEdge: .minY)
    }
    
    func populatePopupButton() {
        installPopupButton?.menu?.removeAllItems()

        if(diskAgent != nil) {
            let diskImages = diskAgent?.getInstallerDiskImages().sorted(by: { $0.0 > $1.0 })
            for(version, name) in diskImages! {
                if(compatibilityChecker.canInstall(version: version)) {
                    installPopupButton?.addItem(withTitle: name)
                }
            }
            if((installPopupButton?.menu?.items.count)! > 0) {
                let recentVersion = installPopupButton?.menu?.items.first?.title
                taskQueue.async {
                    self.diskAgent?.mountInstallDisk(recentVersion!, "10.11")
                }
            } else {
                showErrorAlert(title: "macOS Install Error", message: "There are no installable versions found on the server compatible with this machine")
            }
        }
    }


    func showErrorAlert(title: String, message: String) {
        let alert: NSAlert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.alertStyle = .critical
        alert.addButton(withTitle: "OK :(")
        alert.runModal()
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

        diskAgent = MountDisk(host: hostDiskServer, hostPath: hostDiskPath)

        populatePopupButton()

        for (title, applications) in localSections {
            sections[title] = applications as? [String: String]
        }

        self.collectionView.reloadData()
        os_log("Successfully loaded plist into dictionary")
    }

    func openApplication(atPath path: String) {
        print("Opening application at: \(path)")
        NSWorkspace.shared.open(URL(fileURLWithPath: path))
    }

    @IBAction func installPopupChanged(sender: NSPopUpButton) {
        startSpinning()
        diskAgent?.unmountActiveDisk()
        sender.isEnabled = false

        if((installPopupButton?.menu?.items.count)! > 0) {
            let selectedVersion = installPopupButton?.selectedItem?.title
            taskQueue.async {
                self.diskAgent?.mountInstallDisk(selectedVersion!, "10.11")
            }
        } else {
            showErrorAlert(title: "macOS Install Error", message: "There are no installable versions found on the server compatible with this machine")
        }
    }


    @IBAction func startOSInstall(sender: NSButton) {
        InstallOS.kickoffMacOSInstall()
    }

    fileprivate func configureCollectionView() {
        let flowLayout = NSCollectionViewFlowLayout()
        flowLayout.itemSize = NSSize(width: 100, height: 120.0)
        flowLayout.sectionInset = NSEdgeInsets(top: 10.0, left: 20.0, bottom: 10.0, right: 20.0)
        flowLayout.minimumInteritemSpacing = 20.0
        flowLayout.minimumLineSpacing = 20.0

        collectionView.collectionViewLayout = flowLayout
        view.wantsLayer = false
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

    func stopSpinning() {
        progressSpinner?.isHidden = true
        progressSpinner?.stopAnimation(self)
    }

    func startSpinning() {
        progressSpinner?.startAnimation(self)
        progressSpinner?.isHidden = false
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
extension ViewController: MountDiskDelegate {
    func handleDiskError(message: String) {
        self.showErrorAlert(title: "Disk Error", message: message)
    }

    func readyToInstall(volumePath: String, macOSVersion: String) {
        stopSpinning()
        self.installButton?.isEnabled = true
        self.installPopupButton?.isEnabled = true

        guard let plistPath = self.getPropertyList()
            else {
                return
        }
        guard let preferences = NSMutableDictionary(contentsOf: plistPath)
            else {
                return
        }

        preferences["macOS Volume"] = volumePath
        preferences["macOS Version"] = macOSVersion

        preferences.write(to: plistPath, atomically: true)
    }

    func unreadyToInstall() {
        self.installButton?.isEnabled = false
    }


}
