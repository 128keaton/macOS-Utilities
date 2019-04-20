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
    static let prohibatoryIcon = NSImage(named: "NSHaltIcon")
    var name: String
    var path: String
    var isInvalid = false
    var showInApplicationsWindow = true

    var id: String {
        get {
            return self.name.md5Value
        }
    }

    override var description: String {
        return "\(self.name): \(self.path)"
    }


    init(name: String, path: String, showInApplicationsWindow: Bool = false) {
        self.path = path
        self.name = name

        if path == "" {
            self.isInvalid = true
        }

        self.showInApplicationsWindow = showInApplicationsWindow
    }

    public func open() {
        NSWorkspace.shared.open(URL(fileURLWithPath: self.path))
    }

    func addToRepo() {
        ItemRepository.shared.addToRepository(newApplication: self)
    }

    public func getCollectionViewItem(item: NSCollectionViewItem) -> NSCollectionViewItem {
        if let newItem = item as? NSCollectionAppCell {
            let icon = self.findIcon()
            newItem.icon?.image = icon
            newItem.regularImage = icon
            newItem.application = self

            DispatchQueue.main.async {
                newItem.icon!.lockFocus()
                newItem.darkenedImage = icon.darkened
                newItem.icon!.unlockFocus()
            }

            if(self.isInvalid) {
                newItem.titleLabel?.textColor = NSColor.gray
                newItem.titleLabel?.stringValue = "\(self.name)*"
            } else {
                if(NSApplication.shared.isDarkMode(view: newItem.view)) {
                    newItem.titleLabel?.textColor = NSColor.white
                } else {
                    newItem.titleLabel?.textColor = NSColor.black
                }
                newItem.titleLabel?.stringValue = self.name
            }
            return newItem
        }

        return item
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
        return lhs.id == rhs.id
    }
}

