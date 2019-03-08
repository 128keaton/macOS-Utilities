//
//  Extensions.swift
//  macOS Utilities
//
//  Created by Keaton Burleson on 7/26/18.
//  Copyright © 2018 Keaton Burleson. All rights reserved.
//

import Foundation
import AppKit

let taskQueue = DispatchQueue.global(qos: DispatchQoS.QoSClass.background)
let prohibatoryIcon = NSImage(named: "stop")

func findIconFor(applicationPath: String) -> NSImage {
    let path = applicationPath + "/Contents/Info.plist"
    guard let infoDictionary = NSDictionary(contentsOfFile: path)
        else {
            return prohibatoryIcon!
    }

    guard let imageName = (infoDictionary["CFBundleIconFile"] as? String)
        else {
            return prohibatoryIcon!
    }

    var imagePath = "\(applicationPath)/Contents/Resources/\(imageName)"

    if !imageName.contains(".icns") {
        imagePath = imagePath + ".icns"
    }

    return NSImage(contentsOfFile: imagePath)!
}

extension NSImage {
    func darkened() -> NSImage? {
        if(NSGraphicsContext.current !== nil) {
            let size = self.size
            let rect = NSRect(x: 0, y: 0, width: size.width, height: size.height)
            let newImage = self.copy() as! NSImage
            newImage.lockFocus()
            NSColor(calibratedWhite: 0, alpha: 0.33).set()
            rect.fill(using: NSCompositingOperation.sourceAtop)
            newImage.unlockFocus()
            newImage.draw(in: rect, from: rect, operation: .sourceOver, fraction: 0.75)

            return newImage
        }
        return nil
    }
}

extension NSProgressIndicator {
    func stopSpinning() {
        self.isHidden = true
        self.stopAnimation(self)
    }

    func startSpinning() {
        self.startAnimation(self)
        self.isHidden = false
    }
}

extension NSViewController {
    func showErrorAlert(title: String, message: String) {
        let alert: NSAlert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.alertStyle = .critical
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
    
    func showInfoAlert(title: String, message: String) {
        let alert: NSAlert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.alertStyle = .informational
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
}

extension URL {
    enum Filestatus {
        case isFile
        case isDir
        case isNot
    }

    var filestatus: Filestatus {
        get {
            let filestatus: Filestatus
            var isDir: ObjCBool = false
            if FileManager.default.fileExists(atPath: self.path, isDirectory: &isDir) {
                if isDir.boolValue {
                    // file exists and is a directory
                    filestatus = .isDir
                }
                    else {
                        // file exists and is not a directory
                        filestatus = .isFile
                }
            }
                else {
                    // file does not exist
                    filestatus = .isNot
            }
            return filestatus
        }
    }
}

func matches(for regex: String, in text: String) -> [String] {
    
    do {
        let regex = try NSRegularExpression(pattern: regex)
        let results = regex.matches(in: text,
                                    range: NSRange(text.startIndex..., in: text))
        return results.map {
            String(text[Range($0.range, in: text)!])
        }
    } catch let error {
        print("invalid regex: \(error.localizedDescription)")
        return []
    }
}
