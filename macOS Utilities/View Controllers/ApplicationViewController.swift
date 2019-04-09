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

    private let preferences = Preferences.shared
    private let itemRepository = ItemRepository.shared

    private var disabledPaths: [IndexPath] = []
    private var applications: [Application] = []
    private var sections: [String] = []

    override func awakeFromNib() {
        NotificationCenter.default.addObserver(self, selector: #selector(ApplicationViewController.getApplicationsAndSections), name: ItemRepository.newApplication, object: nil)
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        configureCollectionView()
        addEasterEgg()

        if #available(OSX 10.13, *) {
            if let contentSize = collectionView.collectionViewLayout?.collectionViewContentSize {
                collectionView.setFrameSize(contentSize)
            }
        }

        getApplicationsAndSections()
        DDLogInfo("Launched macOS Utilities")
    }

    @objc public func getApplicationsAndSections() {
        let newApplications = ItemRepository.shared.getApplications().filter { $0.showInApplicationsWindow == true }.sorted(by: { $0.sectionName > $1.sectionName })
        let newSections = Array(Set(newApplications.map { $0.sectionName })).sorted(by: { $0 > $1 })

        if(newApplications != applications || newSections != sections) {
            sections.append(contentsOf: newSections.filter { sections.contains($0) == false })
            applications.append(contentsOf: newApplications.filter { applications.contains($0) == false })
            self.collectionView?.reloadData()
        }
    }

    private func addEasterEgg() {
        let quintClickGesture = NSClickGestureRecognizer(target: self, action: #selector(startEasterEgg))
        quintClickGesture.numberOfClicksRequired = 5
        collectionView.addGestureRecognizer(quintClickGesture)
    }

    fileprivate func configureCollectionView() {
        let flowLayout = NSCollectionViewFlowLayout()
        flowLayout.itemSize = NSSize(width: 100, height: 120.0)

        flowLayout.sectionInset = NSEdgeInsets(top: 0.0, left: 10.0, bottom: 10.0, right: 10.0)
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

    @IBAction func installMacOSButtonClicked(_ sender: NSButton) {
        (NSApplication.shared.delegate as? AppDelegate)?.showPageController()
    }
}

extension ApplicationViewController: NSCollectionViewDataSource {
    func collectionView(_ collectionView: NSCollectionView, didSelectItemsAt indexPaths: Set<IndexPath>) {
        let indexPath = indexPaths.first!


        if !disabledPaths.contains(indexPath) {

            let applicationsForSection = applications.filter { $0.sectionName == sections[indexPath.section] }

            if applicationsForSection.indices.contains(indexPath.item) {
                applicationsForSection[indexPath.item].open()
            } else {
                DDLogError("This shouldn't happen... Application section (\(indexPath.section), \(applicationsForSection)) does not contain an element at \(indexPath.item)")
            }
        } else {
            collectionView.deselectItems(at: indexPaths)
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.06) {
            collectionView.deselectItems(at: indexPaths)
        }
    }

    func numberOfSections(in collectionView: NSCollectionView) -> Int {
        return sections.count
    }

    func collectionView(_ collectionView: NSCollectionView, numberOfItemsInSection section: Int) -> Int {
        return applications.filter { $0.sectionName == sections[section] }.count
    }

    func collectionView(_ collectionView: NSCollectionView, itemForRepresentedObjectAt
    indexPath: IndexPath) -> NSCollectionViewItem {
        let item = collectionView.makeItem(withIdentifier: NSUserInterfaceItemIdentifier(rawValue: "NSCollectionAppCell"), for: indexPath)

        let applicationsForSection = applications.filter { $0.sectionName == sections[indexPath.section] }

        if applicationsForSection.indices.contains(indexPath.item) {
            let app = applicationsForSection[indexPath.item]
            if(app.isInvalid) {
                disabledPaths.append(indexPath)
            }

            return app.getCollectionViewItem(item: item)
        } else {
            DDLogError("This shouldn't happen... Application section (\(indexPath.section), \(applicationsForSection)) does not contain an element at \(indexPath.item)")
        }

        return NSCollectionViewItem()
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
