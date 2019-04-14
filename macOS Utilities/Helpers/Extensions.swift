//
//  Extensions.swift
//  macOS Utilities
//
//  Created by Keaton Burleson on 7/26/18.
//  Copyright © 2018 Keaton Burleson. All rights reserved.
//

import Foundation
import AppKit
import CocoaLumberjack
import CommonCrypto

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

protocol GenericType {
    func isEqualTo(other: GenericType) -> Bool
}
extension GenericType where Self: Equatable {
    func isEqualTo(other: GenericType) -> Bool {
        if let o = other as? Self { return self == o }
        return false
    }
}

extension UInt: GenericType { }
extension String: GenericType { }
extension Bool: GenericType { }


extension NSApplication {
    func isDarkMode(view: NSView?) -> Bool {
        if #available(OSX 10.14, *) {
            if let appearance = view?.effectiveAppearance ?? NSAppearance.current {
                return (appearance.name == .darkAqua)
            }
        }
        return false
    }
    
    public func getName() -> String{
        return Bundle.main.object(forInfoDictionaryKey: "CFBundleName") as! String
    }
    
    public func getVersion() -> String {
        return Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as! String
    }
    
    public func getBuild() -> String {
       return  Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as! String
    }
    
    public func getVerboseName() -> String{
        return "\(getName())-v\(getVersion())-b\(getBuild())"
    }
}

extension NSTextField{
    func setEnabled(_ flag: Bool = true){
        if flag{
            return self.enable()
        }
        return self.disable()
    }
    
    func disable(){
        NSAnimationContext.runAnimationGroup { (context) in
            context.duration = 0.5
            self.animator().alphaValue = 0.5
        }
    }
    
    func enable(){
        NSAnimationContext.runAnimationGroup { (context) in
            context.duration = 0.5
            self.animator().alphaValue = 1.0
        }
    }
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
        DispatchQueue.main.async {
            alert.runModal()
        }
    }

    func showInfoAlert(title: String, message: String) {
        let alert: NSAlert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.alertStyle = .informational
        alert.addButton(withTitle: "OK")
        DispatchQueue.main.async {
            alert.runModal()
        }
    }

    func showInfoAlert(title: String, message: String, completion: @escaping (Bool) -> ()) {
        let alert: NSAlert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.alertStyle = .informational
        alert.addButton(withTitle: "OK")
        DispatchQueue.main.async {
            completion(alert.runModal() == .alertFirstButtonReturn)
        }
    }

    func showConfirmationAlert(question: String, text: String) -> Bool {
        let alert = NSAlert()
        alert.messageText = question
        alert.informativeText = text
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Yes")
        alert.addButton(withTitle: "No")
        return alert.runModal() == .alertFirstButtonReturn
    }
}

extension MutableCollection where Self: RandomAccessCollection {
    /// Sort `self` in-place using criteria stored in a NSSortDescriptors array
    public mutating func sort(sortDescriptors theSortDescs: [NSSortDescriptor]) {
        sort { by:
                for sortDesc in theSortDescs {
                    switch sortDesc.compare($0, to: $1) {
                    case .orderedAscending: return true
                    case .orderedDescending: return false
                    case .orderedSame: continue
                    }
            }
            return false
        }
    }
}

class KBTableView: NSTableView {
    override open func mouseDown(with event: NSEvent) {
        let globalLocation = event.locationInWindow
        let localLocation = convert(globalLocation, from: nil)
        let clickedRow = row(at: localLocation)

        if clickedRow == -1 {
            self.deselectAll(self)
            if let delegate = self.delegate {
                if delegate is NSTableViewDelegateDeselectListener {
                    (delegate as! NSTableViewDelegateDeselectListener).tableView?(self, didDeselectAllRows: true)
                    return
                }
            }
            return super.mouseDown(with: event)
        } else {
            if let delegate = self.delegate {
                if delegate is NSTableViewDelegateDeselectListener {
                    if let shouldSelect = delegate.tableView?(self, shouldSelectRow: clickedRow) {
                        if shouldSelect {
                            return self.selectRowIndexes(IndexSet(integer: clickedRow), byExtendingSelection: false)
                        }
                    }
                }
            }
            return super.mouseDown(with: event)
        }
    }
}

@objc protocol NSTableViewDelegateDeselectListener: NSTableViewDelegate {
    @objc optional func tableView(_ tableView: NSTableView, didDeselectAllRows: Bool)
}

extension String {
    var doubleValue: Double {
        if let potentialValue = Double(self.replacingOccurrences(of: "[^0-9.]", with: "", options: .regularExpression)) {
            return potentialValue
        }
        print("Unable to make \(self) into a double.")
        return 0.0
    }

    var fileURL: URL {
        return URL(fileURLWithPath: self)
    }
    
    var escaped: String {
        return self.addingPercentEncoding(withAllowedCharacters: .urlHostAllowed) ?? ""
    }
    
    /// Returns a safe file name e.g. "A Cool Document" becomes "A-Cool-Document"
    var dashedFileName: String{
        return self.replacingOccurrences(of: " ", with: "-")
    }
    
    var md5Value: String {
        let length = Int(CC_MD5_DIGEST_LENGTH)
        var digest = [UInt8](repeating: 0, count: length)

        if let d = self.data(using: .utf8) {
            _ = d.withUnsafeBytes { body -> String in
                CC_MD5(body.baseAddress, CC_LONG(d.count), &digest)

                return ""
            }
        }

        return (0 ..< length).reduce("") {
            $0 + String(format: "%02x", digest[$1])
        }
    }

    static func random(_ length: Int, numericOnly: Bool = false) -> String {
        var letters = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"

        if(numericOnly) {
            letters = "123456789"
        }

        return String((0..<length).map { _ in letters.randomElement()! })
    }


    func matches(_ regex: String, stripR: [String] = []) -> [String] {
        do {
            let regex = try NSRegularExpression(pattern: regex)
            let results = regex.matches(in: self,
                range: NSRange(self.startIndex..., in: self))
            return results.map {
                String(self[Range($0.range, in: self)!]).replacingOccurrences(of: stripR.joined(separator: "|"), with: "", options: .regularExpression)
            }
        } catch let error {
            DDLogInfo("invalid regex: \(error.localizedDescription)")
            return []
        }
    }
}

extension Array {
    func chunked(into size: Int) -> [[Element]] {
        return stride(from: 0, to: count, by: size).map {
            Array(self[$0 ..< Swift.min($0 + size, count)])
        }
    }

    mutating func move(from start: Index, to end: Index) {
        guard (0..<count) ~= start, (0...count) ~= end else { return }
        if start == end { return }
        let targetIndex = start < end ? end - 1: end
        insert(remove(at: start), at: targetIndex)
    }

    mutating func move(with indexes: IndexSet, to toIndex: Index) {
        let movingData = indexes.map { self[$0] }
        let targetIndex = toIndex - indexes.filter { $0 < toIndex }.count
        for (i, e) in indexes.enumerated() {
            remove(at: e - i)
        }
        insert(contentsOf: movingData, at: targetIndex)
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
    
    /// Absolute path of file from URL
    var absolutePath: String {
        return self.absoluteString.replacingOccurrences(of: "file://", with: "").replacingOccurrences(of: "%20", with: " ")
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
        DDLogInfo("invalid regex: \(error.localizedDescription)")
        return []
    }
}

func getSystemUUID() -> String? {
    let dev = IOServiceMatching("IOPlatformExpertDevice")
    let platformExpert: io_service_t = IOServiceGetMatchingService(kIOMasterPortDefault, dev)
    let serialNumberAsCFString = IORegistryEntryCreateCFProperty(platformExpert, kIOPlatformUUIDKey as CFString, kCFAllocatorDefault, 0)
    IOObjectRelease(platformExpert)
    let ser: CFTypeRef = serialNumberAsCFString!.takeUnretainedValue()
    if let result = ser as? String {
        return result
    }
    return nil
}
