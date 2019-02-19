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

class ApplicationViewController: NSViewController, NSCollectionViewDelegate {
    @IBOutlet weak var collectionView: NSCollectionView!

    private let preferences = Preferences()
    private var sections: [String: [String: String]] = [:]
    private var disabledPaths: [IndexPath] = []

    override func viewDidLoad() {
        super.viewDidLoad()
        configureCollectionView()
        let quintClickGesture = NSClickGestureRecognizer(target: self, action: #selector(startEasterEgg))

        quintClickGesture.numberOfClicksRequired = 5
        collectionView.addGestureRecognizer(quintClickGesture)

        if #available(OSX 10.13, *) {
            if let contentSize = collectionView.collectionViewLayout?.collectionViewContentSize {
                collectionView.setFrameSize(contentSize)
            }
        }

        os_log("Launched macOS Utilities")

        guard let loadedSections = preferences.getApplications()
            else {
                return
        }

        sections = loadedSections
        collectionView.reloadData()
    }


    func openApplication(atPath path: String) {
        print("Opening application at: \(path)")
        NSWorkspace.shared.open(URL(fileURLWithPath: path))
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

        let image = findIconFor(applicationPath: appPath!)

        collectionViewItem.icon?.image = image
        collectionViewItem.regularImage = image
        collectionViewItem.darkenedImage = image.darkened()

        if image == prohibatoryIcon! {
            collectionViewItem.titleLabel?.stringValue = "Invalid path"
            disabledPaths.append(indexPath)
        } else {
            collectionViewItem.titleLabel?.stringValue = appName
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
