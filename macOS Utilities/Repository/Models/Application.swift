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

@objcMembers class Application: RepositoryItem, Codable {
    private var path: String?
    private var cachedPath: String? = nil

    var name: String
    var isUtility: Bool? = false
    var showInApplicationsWindow = true

    private (set) public var infoPath: String? = nil
    private (set) public var iconURL: URL? = nil

    var icon: NSImage {
        return self.getApplicationIcon()
    }

    var defaultIcon: NSImage {
        return NSImage(named: "NSHaltIcon")!
    }

    public var isValid: Bool {
        let fileManager = FileManager.default
        var isDir: ObjCBool = false
        if fileManager.fileExists(atPath: self.applicationPath, isDirectory: &isDir) {
            if isDir.boolValue {
                return true
            }
        }

        return false
    }

    public var infoDictionary: NSDictionary? {
        self.infoPath = "\(self.applicationPath)/Contents/Info.plist"
        if let infoPath = self.infoPath,
            let infoDictionary = NSDictionary(contentsOfFile: infoPath) {
            return infoDictionary
        }

        return nil
    }

    private var generatedPath: String? {
        return NSWorkspace.shared.fullPath(forApplication: self.name)
    }

    public var applicationPath: String {
        if let cachedPath = self.cachedPath {
            return cachedPath
        }

        if let settingsPath = self.path,
            settingsPath != "",
            settingsPath.fileURL.filestatus != .isNot {

            self.cachedPath = settingsPath
            return settingsPath
        }

        if let generatedPath = self.generatedPath {
            if self.path != nil {
                DDLogVerbose("Path was set in preferences to \(self.path!), but an application was not found at this location. However, an application matching the name \(self.name) was found, so we're using the path to that application (\(generatedPath)).")
            }
            self.cachedPath = generatedPath
            return generatedPath
        }

        self.cachedPath = ""
        
        DDLogVerbose("Could not find path for application \"\(self.name)\"")
        return ""
    }

    override var id: String {
        return self.name.md5Value
    }

    override var searchableEntityName: String {
        return self.name
    }

    override var description: String {
        return "\(self.name): \(self.applicationPath)"
    }

    init(name: String, path: String, showInApplicationsWindow: Bool = true) {
        self.path = path
        self.name = name

        super.init()

        self.showInApplicationsWindow = showInApplicationsWindow
    }

    public func open() -> Bool {
        return NSWorkspace.shared.open(applicationPath.fileURL)
    }

    override func addToRepo() {
        ItemRepository.shared.addToRepository(newItem: self)
    }

    public func updatePath(_ newPath: String) {
        self.path = newPath
        DDLogVerbose("Application \(self.name)'s new path: \(newPath)")
    }

    public func updateName(_ newName: String) {
        if self.name == "" {
            DDLogVerbose("Application name updated: \(newName)")
        } else {
            DDLogVerbose("Application \(self.name)'s new name: \(newName)")
        }

        self.name = newName
    }

    public func reloadApplicationPath() {
        self.cachedPath = nil
    }

    public func getCollectionViewItem(item: NSCollectionViewItem) -> NSCollectionViewItem {
        if let newItem = item as? NSCollectionAppCell {
            newItem.icon?.image = self.icon
            newItem.regularImage = self.icon
            newItem.darkenedImage = self.icon.darkened

            newItem.application = self

            if !self.isValid {
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

    public func getApplicationIcon() -> NSImage {
        guard let infoDictionary = self.infoDictionary else {
            return self.defaultIcon
        }

        guard let imageName = (infoDictionary["CFBundleIconFile"] as? String) else {
            return self.defaultIcon
        }

        if iconURL == nil {
            iconURL = URL(fileURLWithPath: "\(self.applicationPath)/Contents/Resources/\(imageName)", isDirectory: false)
        }

        guard let validIconURL = iconURL else {
            return self.defaultIcon
        }

        if UTTypeConformsTo((UTTypeCreatePreferredIdentifierForTag(kUTTagClassFilenameExtension, validIconURL.pathExtension as CFString, nil)?.takeRetainedValue())!, kUTTypeImage) {
            return NSImage(contentsOf: validIconURL)!
        } else {
            return NSImage(contentsOf: validIconURL.appendingPathExtension("icns"))!
        }
    }


    static func == (lhs: Application, rhs: Application) -> Bool {
        return lhs.id == rhs.id
    }
}

