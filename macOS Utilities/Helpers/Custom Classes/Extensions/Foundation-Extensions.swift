//
//  Foundation-Extensions.swift
//  macOS Utilities
//
//  Created by Keaton Burleson on 4/19/19.
//  Copyright © 2019 Keaton Burleson. All rights reserved.
//

import Foundation
import CommonCrypto
import WebKit

class WKNoScrollWebView: WKWebView {
    public var canScroll = false

    open override func scrollWheel(with event: NSEvent) {
        if !canScroll {
            self.nextResponder?.scrollWheel(with: event)
        } else {
            super.scrollWheel(with: event)
        }
    }

    public func hide(animated: Bool = true) {
        if !animated {
            self.alphaValue = 0.0
            return
        }

        NSAnimationContext.runAnimationGroup { (context) in
            context.duration = 0.5
            self.animator().alphaValue = 0.0
        }
    }

    public func show() {
        NSAnimationContext.runAnimationGroup { (context) in
            context.duration = 0.5
            self.animator().alphaValue = 1.0
        }
    }

    private func buildJavaScriptRemove(elementsToRemove elementIDs: [String]) -> String {
        var javaScript = ""

        for elementID in elementIDs {
            javaScript = "\(javaScript) document.getElementById('\(elementID)').remove();"
        }

        return javaScript
    }

    public func removeWebViewElements(completion: @escaping () -> ()) {
        let baseJavaScript = buildJavaScriptRemove(elementsToRemove: ["view-selector-6", "ac-globalnav", "ac-gn-placeholder", "wcTitleCheck", "wcTitleStatus", "local-header-wrapper", "dispute"])

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            self.evaluateJavaScript(baseJavaScript, completionHandler: { _, _ in
                completion()
            })
        }
    }

    public func scrollToElementInWebView(elementID: String, offset: Int = 25, completion: @escaping () -> ()) {
        let scrollJavaScript = "document.getElementById('\(elementID)').scrollIntoView(); window.scrollBy(0, \(offset))"
        self.evaluateJavaScript(scrollJavaScript) { (_, _) in
            completion()
        }
    }
}

extension String {
    var condensed: String {
        let components = self.components(separatedBy: .whitespacesAndNewlines)
        return components.filter { !$0.isEmpty }.joined(separator: " ")
    }

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
    var dashedFileName: String {
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
            print("invalid regex: \(error.localizedDescription)")
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
        print(self.absoluteString.replacingOccurrences(of: "file://", with: "").replacingOccurrences(of: "%20", with: " "))
        return self.absoluteString.replacingOccurrences(of: "file://", with: "").replacingOccurrences(of: "%20", with: " ")
    }
}

extension FileManager {
    public func copyFile(from: String, to: String) -> (Bool, Error?) {
        do {
            try self.copyItem(atPath: from, toPath: to)
        } catch {
            return (false, error)
        }
        return (true, nil)
    }

    public func writeImageToTemporaryDirectory(image: NSImage, resourceName: String, fileExtension: String) -> URL?
    {

        // Get the file path in the bundle
        let tempDirectoryURL = NSURL.fileURL(withPath: NSTemporaryDirectory(), isDirectory: true)

        // Create a destination URL.
        let targetURL = tempDirectoryURL.appendingPathComponent("\(resourceName).\(fileExtension)")

        let properties = [NSBitmapImageRep.PropertyKey.compressionFactor: 1.0]
        guard
            let imageData = image.tiffRepresentation,
            let imageRep = NSBitmapImageRep(data: imageData),
            let fileData = imageRep.representation(using: .png, properties: properties) else {
                return nil
        }

        do {
            try fileData.write(to: targetURL)
            return targetURL
        } catch {
            KBLogDebug("Could not write image: \(error)")
        }
        
        return nil
    }
}

// MARK: Generic type equalizations
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

extension Double {
    /// Rounds the double to decimal places value
    func rounded(toPlaces places: Int) -> Double {
        let divisor = pow(10.0, Double(places))
        return (self * divisor).rounded() / divisor
    }
}
