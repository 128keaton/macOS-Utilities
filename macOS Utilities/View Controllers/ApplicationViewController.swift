//
//  ViewController.swift
//  macOS Utilities
//
//  Created by Keaton Burleson on 7/23/18.
//  Copyright © 2018 Keaton Burleson. All rights reserved.
//

import Cocoa
import AppFolder
import CocoaLumberjack

class ApplicationViewController: NSViewController, NSCollectionViewDelegate {
    @IBOutlet weak var collectionView: NSCollectionView!
    @IBOutlet weak var installMacOSButton: NSButton?

    private var preferenceLoader: PreferenceLoader? = nil
    private let itemRepository = ItemRepository.shared

    private var disabledPaths: [IndexPath] = []
    private var applications: [Application] = []
    private var applicationsInSections = [[Application]]()

    private var dispatchQueue: DispatchQueue?
    private var dispatchWorkItem: DispatchWorkItem?

    override func viewDidLoad() {
        super.viewDidLoad()

        installMacOSButton?.alphaValue = 0.0

        if let preferenceLoader = PreferenceLoader.sharedInstance {
            self.preferenceLoader = preferenceLoader
            self.registerForNotifications()
        }

        if let collectionViewNib = NSNib(nibNamed: "NSCollectionAppCell", bundle: nil) {
            collectionView.register(collectionViewNib, forItemWithIdentifier: NSUserInterfaceItemIdentifier(rawValue: "NSCollectionAppCell"))
        }

        DDLogInfo("Launched macOS Utilities")
    }

    private func registerForNotifications() {
        NotificationCenter.default.addObserver(self, selector: #selector(ApplicationViewController.readPreferences), name: PreferenceLoader.preferencesLoaded, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(ApplicationViewController.bulkUpdateApplications(_:)), name: ItemRepository.updatingApplications, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(ApplicationViewController.addApplication(_:)), name: ItemRepository.newApplication, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(ApplicationViewController.forceReloadApplications), name: ItemRepository.newApplications, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(ApplicationViewController.checkForInstallers), name: ItemRepository.newInstaller, object: nil)
    }

    @objc private func checkForInstallers() {
        if itemRepository.getInstallers().count > 0{
            NSAnimationContext.runAnimationGroup { (context) in
                context.duration = 0.5
                self.installMacOSButton?.animator().alphaValue = 1.0
            }
            self.addTouchBarInstallButton()
        }else{
            NSAnimationContext.runAnimationGroup { (context) in
                context.duration = 0.5
                self.installMacOSButton?.animator().alphaValue = 0.0
            }
            self.removeTouchBarInstallButton()
        }
    }

    @objc private func readPreferences() {
        if let preferences = PreferenceLoader.currentPreferences {
            if preferences.useDeviceIdentifierAPI {
                DeviceIdentifier.setup(authenticationToken: preferences.deviceIdentifierAuthenticationToken!)
            }
        }
    }

    @objc public func bulkUpdateApplications(_ notification: Notification?) {
        if !Thread.isMainThread {
            DispatchQueue.main.async {
                self.bulkUpdateApplications(notification)
            }
            return
        }

        if let validNotification = notification {
            guard var newApplications = (validNotification.object as? [Application]) else { return }

            newApplications = newApplications.filter { $0.showInApplicationsWindow == true }

            NotificationCenter.default.post(name: ItemRepository.hideApplications, object: nil)

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                self.reloadApplications(withNewApplications: newApplications)
            }
        }
    }

    @objc public func addApplication(_ notification: Notification? = nil) {
        if !Thread.isMainThread && notification != nil {
            DispatchQueue.main.async {
                self.addApplication(notification)
            }
            return
        }

        if let validNotification = notification,
            let newApplication = validNotification.object as? Application,
            newApplication.showInApplicationsWindow == true {
            self.applications.append(newApplication)
        }
    }

    @objc func forceReloadApplications() {
        if !Thread.isMainThread {
            DispatchQueue.main.async {
                self.reloadApplications(withNewApplications: nil)
            }
            return
        }
        reloadApplications(withNewApplications: nil)
    }

    private func reloadApplications(withNewApplications newApplications: [Application]? = nil) {
        if newApplications == nil {
            applications = ItemRepository.shared.getApplications()
        } else if let newApplications = newApplications {
            if(newApplications.count > applications.count) {
                applications.append(contentsOf: newApplications.filter { applications.contains($0) == false })
            } else if (newApplications.count < applications.count) {
                applications.removeAll { !newApplications.contains($0) }
            } else if newApplications.count == 0 {
                applications.removeAll()
            } else {
                applications = newApplications
            }
        }
        reloadCollectionView()
    }

    @objc public func reloadCollectionView() {
        applicationsInSections = applications.count > 4 ? applications.chunked(into: 4) : [applications]

        DispatchQueue.main.async {
            if(self.applications.count > 0 && self.applicationsInSections.count > 0 && self.applicationsInSections.first!.count > 0) {
                self.configureCollectionView()
            }
        }

        self.collectionView?.reloadData()
    }

    private func addEasterEgg() {
        let quintClickGesture = NSClickGestureRecognizer(target: self, action: #selector(startEasterEgg))
        quintClickGesture.numberOfClicksRequired = 5
        collectionView.addGestureRecognizer(quintClickGesture)
    }

    private func configureCollectionView() {
        // collectionView width is 660
        // inner available width is 640 (insets are 10.0 left/right)

        let flowLayout = NSCollectionViewFlowLayout()

        let collectionViewWidth = 640
        let collectionViewHeight = 291.0

        let itemWidth = 100
        let itemHeight = 120

        let totalNumberOfItems = Double(self.applications.count)
        let numberOfItemsInSections = self.applicationsInSections.map { $0.count }

        let itemSpacing = (collectionViewWidth - (numberOfItemsInSections.first! * itemWidth)) / numberOfItemsInSections.first!

        flowLayout.itemSize = NSSize(width: itemWidth, height: itemHeight)


        if totalNumberOfItems < 3.0 {
            flowLayout.minimumLineSpacing = 3.0
            flowLayout.sectionInset = NSEdgeInsets(top: CGFloat(collectionViewHeight / 4.0), left: CGFloat(collectionViewWidth / 8), bottom: 10.0, right: CGFloat(collectionViewWidth / 8))
        } else if totalNumberOfItems < 4.0 {
            flowLayout.minimumLineSpacing = 3.0
            flowLayout.sectionInset = NSEdgeInsets(top: CGFloat(collectionViewHeight / 4.0), left: CGFloat(collectionViewWidth / 12), bottom: 10.0, right: CGFloat(collectionViewWidth / 12))
        } else if totalNumberOfItems == 4.0 {
            flowLayout.minimumLineSpacing = 0.0
            flowLayout.sectionInset = NSEdgeInsets(top: CGFloat(collectionViewHeight / 4.0), left: 10.0, bottom: 10.0, right: 10.0)
        } else if totalNumberOfItems > 4.0 {
            flowLayout.minimumLineSpacing = 0.0
            flowLayout.sectionInset = NSEdgeInsets(top: 10.0, left: 10.0, bottom: 10.0, right: 10.0)
        }

        flowLayout.minimumInteritemSpacing = CGFloat(itemSpacing)
        self.collectionView.collectionViewLayout = flowLayout
        NotificationCenter.default.post(name: ItemRepository.showApplications, object: nil)
        updateScrollViewContentSize()
    }

    private func updateScrollViewContentSize() {
        if let window = collectionView?.window {
            CATransaction.begin()
            CATransaction.setDisableActions(true)
            CATransaction.setAnimationDuration(0.0)
            let originalFrame = window.frame
            var frame = originalFrame
            frame.origin.y = frame.origin.y - 0.025
            frame.size.height = frame.size.height + 0.025
            window.setFrame(frame, display: false)
            CATransaction.commit()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.045) {
                window.setFrame(originalFrame, display: false)
            }
        }
    }

    @IBAction func ejectCDTray(_ sender: NSMenuItem) {
        let ejectProcess = Process()
        ejectProcess.launchPath = "/usr/bin/drutil"
        ejectProcess.arguments = ["tray", "eject"]
        ejectProcess.launch()
    }

    @IBAction func installMacOSButtonClicked(_ sender: NSButton) {
        self.startMacOSInstall()
    }

    @objc private func startMacOSInstall() {
        PageController.shared.showPageController()
    }

    @objc private func openPreferences() {
        if let preferencesWindow = NSStoryboard(name: "Main", bundle: nil).instantiateController(withIdentifier: "preferencesWindowController") as? NSWindowController {
            preferencesWindow.showWindow(self)
        }
    }

    @objc private func getInfo() {
        if let getInfoWindow = NSStoryboard(name: "Main", bundle: nil).instantiateController(withIdentifier: "getInfoWindowController") as? NSWindowController {
            getInfoWindow.showWindow(self)
        }
    }

    func removeTouchBarInstallButton() {
        if let touchBar = self.touchBar {
            touchBar.defaultItemIdentifiers = [.getInfo, .openPreferences]
        }
    }

    func addTouchBarInstallButton() {
        if let touchBar = self.touchBar {
            touchBar.defaultItemIdentifiers = [.installMacOS, .getInfo, .openPreferences]
        }
    }
}

extension ApplicationViewController: NSCollectionViewDataSource {
    func collectionView(_ collectionView: NSCollectionView, didSelectItemsAt indexPaths: Set<IndexPath>) {
        let indexPath = indexPaths.first!

        let applicationsInSection = applicationsInSections[indexPath.section]
        let applicationFromSection = applicationsInSection[indexPath.item]

        if(applicationFromSection.isInvalid) {
            disabledPaths.append(indexPath)
            return deselectAllItems(indexPaths)
        }

        applicationFromSection.open()
        deselectAllItems(indexPaths)
    }

    func deselectAllItems(_ indexPaths: Set<IndexPath>) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.06) {
            self.collectionView.deselectItems(at: indexPaths)
        }
    }

    func numberOfSections(in collectionView: NSCollectionView) -> Int {
        return applicationsInSections.count
    }

    func collectionView(_ collectionView: NSCollectionView, numberOfItemsInSection section: Int) -> Int {
        if applicationsInSections.indices.contains(section) {
            return applicationsInSections[section].count
        }
        return applications.count
    }

    func collectionView(_ collectionView: NSCollectionView, itemForRepresentedObjectAt
        indexPath: IndexPath) -> NSCollectionViewItem {
        let item = collectionView.makeItem(withIdentifier: NSUserInterfaceItemIdentifier(rawValue: "NSCollectionAppCell"), for: indexPath)
        var applicationsInSection = [Application]()

        if applicationsInSections.indices.contains(indexPath.section) {
            applicationsInSection = applicationsInSections[indexPath.section]
        }

        if applicationsInSection.indices.contains(indexPath.item) {
            let applicationFromSection = applicationsInSection[indexPath.item]

            if(applicationFromSection.isInvalid) {
                disabledPaths.append(indexPath)
            }

            return applicationFromSection.getCollectionViewItem(item: item)
        }
        return item
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

@available(OSX 10.12.1, *)
extension NSTouchBarItem.Identifier {
    static let installMacOS = NSTouchBarItem.Identifier("com.keaton.utilities.installMacOS")
    static let getInfo = NSTouchBarItem.Identifier("com.keaton.utilities.getInfo")
    static let closeCurrentWindow = NSTouchBarItem.Identifier("com.keaton.utilities.closeCurrentWindow")
    static let backPageController = NSTouchBarItem.Identifier("com.keaton.utilities.back")
    static let nextPageController = NSTouchBarItem.Identifier("com.keaton.utilities.next")
    static let openPreferences = NSTouchBarItem.Identifier("com.keaton.utilities.openPreferences")
}

@available(OSX 10.12.1, *)
extension ApplicationViewController: NSTouchBarDelegate {

    override func makeTouchBar() -> NSTouchBar? {
        let touchBar = NSTouchBar()
        touchBar.delegate = self
        touchBar.defaultItemIdentifiers = [.getInfo, .openPreferences]

        return touchBar
    }

    func touchBar(_ touchBar: NSTouchBar, makeItemForIdentifier identifier: NSTouchBarItem.Identifier) -> NSTouchBarItem? {
        switch identifier {

        case NSTouchBarItem.Identifier.installMacOS:
            let item = NSCustomTouchBarItem(identifier: identifier)
            item.view = NSButton(image: NSImage(named: "NSInstallIcon")!, target: self, action: #selector(startMacOSInstall))
            return item

        case NSTouchBarItem.Identifier.getInfo:
            let item = NSCustomTouchBarItem(identifier: identifier)
            item.view = NSButton(image: NSImage(named: "NSTouchBarGetInfoTemplate")!, target: self, action: #selector(getInfo))
            return item

        case NSTouchBarItem.Identifier.openPreferences:
            let item = NSCustomTouchBarItem(identifier: identifier)
            item.view = NSButton(image: NSImage(named: "NSActionTemplate")!, target: self, action: #selector(openPreferences))
            return item

        default: return nil
        }
    }
}
