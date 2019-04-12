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
    @IBOutlet weak var getInfoButton: NSButton?

    private let preferenceLoader: PreferenceLoader? = PreferenceLoader(useBundlePreferences: false)
    private let itemRepository = ItemRepository.shared

    private var disabledPaths: [IndexPath] = []
    private var applications: [Application] = []
    private var applicationsInSections = [[Application]]()

    override func viewDidLoad() {
        super.viewDidLoad()

        getInfoButton?.alphaValue = 0.0

        addEasterEgg()
        if let collectionViewNib = NSNib(nibNamed: "NSCollectionAppCell", bundle: nil) {
            collectionView.register(collectionViewNib, forItemWithIdentifier: NSUserInterfaceItemIdentifier(rawValue: "NSCollectionAppCell"))
            registerForNotifications()
        }

        DDLogInfo("Launched macOS Utilities")
    }

    private func registerForNotifications() {
        NotificationCenter.default.addObserver(self, selector: #selector(ApplicationViewController.readPreferences), name: PreferenceLoader.preferencesLoaded, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(ApplicationViewController.updatingApplications), name: ItemRepository.updatingApplications, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(ApplicationViewController.getApplications), name: ItemRepository.newApplications, object: nil)
    }

    @objc private func readPreferences() {
        if let preferences = PreferenceLoader.currentPreferences {
            if preferences.useDeviceIdentifierAPI {
                DeviceIdentifier.setup(authenticationToken: preferences.deviceIdentifierAuthenticationToken!)
                NSAnimationContext.runAnimationGroup { (context) in
                    context.duration = 0.5
                    self.getInfoButton?.animator().alphaValue = 1.0
                }
            }
        }
    }

    @objc public func updatingApplications(_ notification: Notification?) {
        if !Thread.isMainThread {
            DispatchQueue.main.async {
                self.updatingApplications(notification)
            }
            return
        }

        if let validNotification = notification {
            guard var newApplications = (validNotification.object as? [Application]) else { return }

            newApplications = newApplications.filter { $0.showInApplicationsWindow == true }.sorted(by: { $0.name > $1.name })
            
            NotificationCenter.default.post(name: ItemRepository.hideApplications, object: nil)

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                self.setValidApplications(newApplications)
            }
        }
    }

    @objc public func getApplications() {
        if !Thread.isMainThread {
            DispatchQueue.main.async {
                self.getApplications()
            }
            return
        }

        let newApplications = ItemRepository.shared.getApplications().filter { $0.showInApplicationsWindow == true }.sorted(by: { $0.name > $1.name })
        setValidApplications(newApplications)
    }

    private func setValidApplications(_ newApplications: [Application]) {
        if(newApplications.count > applications.count) {
            applications.append(contentsOf: newApplications.filter { applications.contains($0) == false })
        } else if (newApplications.count < applications.count) {
            applications.removeAll { !newApplications.contains($0) }
        } else if newApplications.count == 0 {
            applications.removeAll()
        }


        applicationsInSections = applications.count > 4 ? applications.chunked(into: 4) : [applications]

        if(applications.count > 0 && applicationsInSections.count > 0 && applicationsInSections.first!.count > 0) {
            configureCollectionView()
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

        if totalNumberOfItems <= 4.0 {
            flowLayout.minimumLineSpacing = 0.0
            flowLayout.sectionInset = NSEdgeInsets(top: CGFloat(collectionViewHeight / 4.0), left: 10.0, bottom: 10.0, right: 10.0)
        } else {
            flowLayout.minimumLineSpacing = 3.0
            flowLayout.sectionInset = NSEdgeInsets(top: 0.0, left: 10.0, bottom: 10.0, right: 10.0)
        }


        print("Item spacing: \(itemSpacing)")

        flowLayout.minimumInteritemSpacing = CGFloat(itemSpacing)
        self.collectionView.collectionViewLayout = flowLayout
    }


    @IBAction func ejectCDTray(_ sender: NSMenuItem) {
        let ejectProcess = Process()
        ejectProcess.launchPath = "/usr/bin/drutil"
        ejectProcess.arguments = ["tray", "eject"]
        ejectProcess.launch()
    }

    @IBAction func installMacOSButtonClicked(_ sender: NSButton) {
        PageController.shared.showPageController()
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
        return applicationsInSections[section].count
    }

    func collectionView(_ collectionView: NSCollectionView, itemForRepresentedObjectAt
    indexPath: IndexPath) -> NSCollectionViewItem {
        let item = collectionView.makeItem(withIdentifier: NSUserInterfaceItemIdentifier(rawValue: "NSCollectionAppCell"), for: indexPath)
        let applicationsInSection = applicationsInSections[indexPath.section]

        let applicationFromSection = applicationsInSection[indexPath.item]

        if(applicationFromSection.isInvalid) {
            disabledPaths.append(indexPath)
        }

        return applicationFromSection.getCollectionViewItem(item: item)
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
