//
//  App.swift
//  macOS Utilities
//
//  Created by Keaton Burleson on 3/29/19.
//  Copyright © 2019 Keaton Burleson. All rights reserved.
//

import Foundation
import AppKit
import CocoaLumberjack

@objcMembers class Application: NSObject, Item, Codable {
    static let prohibatoryIcon = NSImage(named: "stop")
    var name: String
    var isUtility: Bool = false
    var path: String
    var isInvalid = false
    var id: String {
        get {
            return self.name.md5Value
        }
    }

    var showInApplicationsWindow = true

    override var description: String {
        return "Application: \n\t Name: \(self.name) \n\t Utility: \(self.isUtility) \n\t Invalid: \(self.isInvalid) \n\t \n\t Path: \(self.path)"
    }

    func addToRepo() {
        ItemRepository.shared.addToRepository(newApplication: self)
    }

    init(name: String, isUtility: Bool = false) {
        self.name = name.replacingOccurrences(of: ".app", with: "")

        self.isUtility = isUtility
        if(self.isUtility) {
            self.showInApplicationsWindow = false
            self.path = "/Applications/Utilities/\(self.name).app"
        } else {
            self.path = "/Applications/\(self.name).app"
        }

        super.init()
        self.addToRepo()
    }

    convenience init(name: String, path: String, showInApplicationsWindow: Bool = false) {

        self.init(name: name)
        self.path = path

        self.determineUtilityFromPath()
        self.showInApplicationsWindow = showInApplicationsWindow
    }

    private func determineUtilityFromPath() {
        if self.path.contains("/Applications/Utilities") {
            self.isUtility = true
            self.showInApplicationsWindow = false
        } else {
            self.isUtility = false
        }
    }

    public func open() {
        NSWorkspace.shared.open(URL(fileURLWithPath: self.path))
    }

    public func getCollectionViewItem(item: NSCollectionViewItem) -> NSCollectionViewItem {
        let icon = self.findIcon()

        guard let collectionViewItem = item as? NSCollectionAppCell else { return item }

        collectionViewItem.icon?.image = icon
        collectionViewItem.regularImage = icon

        DispatchQueue.main.async {
            collectionViewItem.icon!.lockFocus()
            collectionViewItem.darkenedImage = icon.darkened()
            collectionViewItem.icon!.unlockFocus()
        }

        if(self.isInvalid) {
            collectionViewItem.titleLabel?.textColor = NSColor.gray
            collectionViewItem.titleLabel?.stringValue = "\(self.name)*"
        } else {
            if(NSApplication.shared.isDarkMode(view: collectionViewItem.view)) {
                collectionViewItem.titleLabel?.textColor = NSColor.white
            } else {
                collectionViewItem.titleLabel?.textColor = NSColor.black
            }
            collectionViewItem.titleLabel?.stringValue = self.name
        }

        return collectionViewItem
    }

    private func findIcon() -> NSImage {
        let infoPath = "\(self.path)/Contents/Info.plist"
        guard let infoDictionary = NSDictionary(contentsOfFile: infoPath)
            else {
                isInvalid = true
                return Application.prohibatoryIcon!
        }

        guard let imageName = (infoDictionary["CFBundleIconFile"] as? String)
            else {
                isInvalid = true
                return Application.prohibatoryIcon!
        }

        let imagePath = URL(fileURLWithPath: "\(self.path)/Contents/Resources/\(imageName)", isDirectory: false)
        let imageUti = UTTypeCreatePreferredIdentifierForTag(kUTTagClassFilenameExtension, imagePath.pathExtension as CFString, nil)

        if UTTypeConformsTo((imageUti?.takeRetainedValue())!, kUTTypeImage) {
            return NSImage(contentsOf: imagePath)!
        } else {
            return NSImage(contentsOf: imagePath.appendingPathExtension("icns"))!
        }
    }

    static func == (lhs: Application, rhs: Application) -> Bool {
        return lhs.path == rhs.path &&
            lhs.name == rhs.name
    }

}

