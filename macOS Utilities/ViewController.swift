//
//  ViewController.swift
//  macOS Utilities
//
//  Created by Keaton Burleson on 7/23/18.
//  Copyright © 2018 Keaton Burleson. All rights reserved.
//

import Cocoa

class ViewController: NSViewController, NSCollectionViewDelegate {
    @IBOutlet weak var installButton: NSButton?
    @IBOutlet weak var progressWheel: NSProgressIndicator?
    @IBOutlet weak var collectionView: NSCollectionView!

    private var sections: [Int: Int] = [:]
    private var applications: [String: [String: String]] = [:]

    override func viewDidLoad() {
        super.viewDidLoad()
                configureCollectionView()
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

        guard let localSections = preferences["Applications"] as? [String: Any]
            else {
                return
        }

        for (title, listing) in localSections {
            applications[title] = listing as? [String: String]
        }

        if FileManager.default.fileExists(atPath: macOSPath) {
            installButton?.isEnabled = true
            progressWheel?.isHidden = true
        }

        print(applications)
        self.collectionView.reloadData()
    }

    override var representedObject: Any? {
        didSet {
            // Update the view, if already loaded.
        }
    }

    func openApplication(atPath path: String) {
        NSWorkspace.shared.open(URL(fileURLWithPath: path))
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

        print(appName)
        collectionViewItem.titleLabel?.stringValue = appName

        if let image = findIconFor(applicationPath: appPath!) {
            collectionViewItem.icon?.image = image
            collectionViewItem.regularImage = image
            collectionViewItem.darkenedImage = generateDarkenedImage(fromImage: image)
        }
        return item
    }

    func findIconFor(applicationPath: String) -> NSImage? {
        let path = applicationPath + "/Contents/Info.plist"
        let infoDictionary = NSDictionary(contentsOfFile: path)
        let imagePath = "\(applicationPath)/Contents/Resources/\(infoDictionary!["CFBundleIconFile"]!).icns"
        
        return NSImage(contentsOfFile: imagePath)
    }
    
    func generateDarkenedImage(fromImage image: NSImage) -> NSImage{
        let size = image.size
        let rect = NSRect(x: 0, y: 0, width: size.width, height: size.height)
        let newImage = image.copy() as! NSImage
        newImage.lockFocus()
        NSColor(calibratedWhite: 0, alpha: 0.33).set()
        rect.fill(using: NSCompositingOperation.sourceAtop)
        newImage.unlockFocus()
        newImage.draw(in: rect, from: rect, operation: .sourceOver, fraction: 0.75)
        
        return newImage
    }


}


