//
//  ViewController.swift
//  macOS Utilities
//
//  Created by Keaton Burleson on 7/23/18.
//  Copyright © 2018 Keaton Burleson. All rights reserved.
//

import Cocoa
import AppFolder
import PaperTrailLumberjack

class ApplicationViewController: NSViewController, NSCollectionViewDelegate {
    @IBOutlet weak var collectionView: NSCollectionView!

    private let preferences = Preferences()
    private var sections: [String: [String: String]] = [:]
    private var disabledPaths: [IndexPath] = []
    public var apps: [App] = []

    override func viewDidLoad() {
        super.viewDidLoad()

        constructLogger()
        configureCollectionView()

        let quintClickGesture = NSClickGestureRecognizer(target: self, action: #selector(startEasterEgg))
        quintClickGesture.numberOfClicksRequired = 5
        collectionView.addGestureRecognizer(quintClickGesture)

        if #available(OSX 10.13, *) {
            if let contentSize = collectionView.collectionViewLayout?.collectionViewContentSize {
                collectionView.setFrameSize(contentSize)
            }
        }

        DDLogInfo("Launched macOS Utilities")

        guard let loadedSections = preferences.getApplications()
            else {
                return
        }

        sections = loadedSections
        collectionView.reloadData()
    }

    func constructLogger() {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as! String
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as! String

        DDLog.add(DDOSLogger.sharedInstance)

        if(preferences.checkIfLoggingEnabled()) {
            let logger = RMPaperTrailLogger.sharedInstance()!

            logger.host = preferences.getLoggingURL()
            logger.port = preferences.getLoggingPort()
            print(logger.port)
            print(logger.host)
            
            logger.machineName = Host.current().localizedName != nil ? String("\(Host.current().localizedName!)__(\(Sysctl.model)__\(getSystemUUID() ?? ""))") : String("\(Sysctl.model)__(\(getSystemUUID() ?? ""))")
            
            #if DEBUG
                logger.machineName = logger.machineName! + "__DEBUG__"
            #endif
            
            logger.programName = "macOS_Utilities-\(version)-\(build)"
            DDLog.add(logger, with: .debug)
            DDLogInfo("Remote logging enabled")
        }else{
            DDLogInfo("Remote logging disabled")
        }

        DDLogInfo("\n")
        DDLogInfo("\n---------------------------LOGGER INITIALIZED---------------------------")
        DDLogInfo("\n")
    }

    @IBAction func startOSInstall(sender: NSButton) {
        InstallOS.kickoffMacOSInstall()
    }

    fileprivate func configureCollectionView() {
        let flowLayout = NSCollectionViewFlowLayout()
        flowLayout.itemSize = NSSize(width: 100, height: 120.0)

        flowLayout.sectionInset = NSEdgeInsets(top: 15.0, left: 10.0, bottom: 10.0, right: 10.0)
        flowLayout.minimumInteritemSpacing = 60.0
        flowLayout.minimumLineSpacing = 30.0

        collectionView.collectionViewLayout = flowLayout
    }

    @IBAction func ejectCDTray(_ sender: NSMenuItem) {
        let ejectProcess = Process()
        ejectProcess.launchPath = "/usr/bin/drutil"
        ejectProcess.arguments = ["tray", "eject"]
        ejectProcess.launch()
    }
}
extension ApplicationViewController: NSCollectionViewDataSource {
    func collectionView(_ collectionView: NSCollectionView, didSelectItemsAt indexPaths: Set<IndexPath>) {
        let indexPath = indexPaths.first!

        if !disabledPaths.contains(indexPath) {
            let sortedSectionTitles = Array(sections.keys).sorted { $0 < $1 }

            let sectionTitle = sortedSectionTitles[indexPath.section]
            let appList = sections[sectionTitle]
            let appName = Array(appList!.keys).sorted { $0 < $1 }[indexPath.item]

            let app = apps.first(where: { $0.name == appName })
            app?.open()

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

        let sortedSectionTitles = Array(sections.keys).sorted { $0 < $1 }
        let sectionTitle = sortedSectionTitles[indexPath.section]

        let appList = sections[sectionTitle]
        let appName = Array(appList!.keys).sorted { $0 < $1 }[indexPath.item]
        guard let appPath = appList![appName] else { return item }

        let app = App(name: appName, path: appPath)
        apps.append(app)

        if(app.isInvalid) {
            disabledPaths.append(indexPath)
        }

        return app.getCollectionViewItem(item: item)
    }

    @objc func startEasterEgg() {
        for cell in self.collectionView.visibleItems() as! [NSCollectionAppCell] {
            buildAnimation(view: (cell.icon)!)
        }
    }

    func buildAnimation(view: NSView) {
        let basicAnimation = CABasicAnimation(keyPath: "transform.rotation")
        basicAnimation.timingFunction = CAMediaTimingFunction(name: CAMediaTimingFunctionName.linear)
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
