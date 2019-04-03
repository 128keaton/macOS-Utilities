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

class Application {
    var name: String
    var isUtility: Bool
    var path: String
    var isInvalid = false
    var sectionName = "Basic"

    private static let repository = ApplicationRepository.shared

    let prohibatoryIcon = NSImage(named: "stop")

    init(name: String, isUtility: Bool = false) {
        self.name = name.replacingOccurrences(of: ".app", with: "")
        self.isUtility = isUtility
        if(self.isUtility) {
            self.path = "/Applications/Utilities/\(self.name).app"
        } else {
            self.path = "/Applications/\(self.name).app"
        }
    }

    convenience init(name: String, path: String) {
        self.init(name: name)
        self.path = path

        self.determineUtilityFromPath()
    }

    convenience init(name: String, prefDict: [String: String]) {
        self.init(name: name)

        if let prefPath = prefDict["Path"] {
            self.path = prefPath
        } else {
            DDLogInfo("Unable to parse path from dictionary for app: \(name)")
            self.isInvalid = true
        }

        if let sectionName = prefDict["Section"] {
            self.sectionName = sectionName
        } else {
            DDLogInfo("No section set for app: \(name), using 'Basic'.")
        }

        self.determineUtilityFromPath()
    }

    private func determineUtilityFromPath() {
        if self.path.contains("/Applications/Utilities/") {
            self.isUtility = true
        } else {
            self.isUtility = false
        }
    }

    @objc public func open() {
        Application.open(path: self.path)
    }

    public static func open(_ name: String, isUtility: Bool = false) {
        repository.openAppByName(name, isUtility: isUtility)
    }

    public static func open(path: String) {
        DDLogVerbose("Opening application at: \(path)")
        NSWorkspace.shared.open(URL(fileURLWithPath: path))
    }

    public func getCollectionViewItem(item: NSCollectionViewItem) -> NSCollectionViewItem {
        let icon = self.findIcon()

        guard let collectionViewItem = item as? NSCollectionAppCell else { return item }

        collectionViewItem.icon?.image = icon
        collectionViewItem.regularImage = icon
        collectionViewItem.darkenedImage = icon.darkened()

        if(self.isInvalid) {
            collectionViewItem.titleLabel?.stringValue = "Invalid path"
        } else {
            collectionViewItem.titleLabel?.stringValue = self.name
        }

        return collectionViewItem
    }

    private func findIcon() -> NSImage {
        let infoPath = self.path + "/Contents/Info.plist"
        guard let infoDictionary = NSDictionary(contentsOfFile: infoPath)
            else {
                self.isInvalid = true
                return prohibatoryIcon!
        }

        guard let imageName = (infoDictionary["CFBundleIconFile"] as? String)
            else {
                self.isInvalid = true
                return prohibatoryIcon!
        }

        var imagePath = "\(self.path)/Contents/Resources/\(imageName)"

        if !imageName.contains(".icns") {
            imagePath = imagePath + ".icns"
        }

        return NSImage(contentsOfFile: imagePath)!
    }

}
