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

class App {
    var name: String
    var isUtility: Bool
    var path: String
    var isInvalid = false

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
    
    convenience init(name: String, path: String){
        self.init(name: name)
        self.path = path
        
        if self.path.contains("/Applications/Utilities/"){
            self.isUtility = true
        }else{
            self.isUtility = false
        }
    }

    @objc public func open() {
        App.open(path: self.path)
    }
    
    public static func open(path: String){
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
