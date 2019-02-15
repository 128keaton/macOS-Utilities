//
//  Extensions.swift
//  macOS Utilities
//
//  Created by Keaton Burleson on 7/26/18.
//  Copyright © 2018 Keaton Burleson. All rights reserved.
//

import Foundation
import AppKit

extension NSImage{
    func darkened() -> NSImage {
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
}
