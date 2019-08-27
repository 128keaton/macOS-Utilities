//
//  PaddedTextField.swift
//  macOS Utilities
//
//  Created by Keaton Burleson on 4/16/19.
//  Copyright © 2019 Keaton Burleson. All rights reserved.
//

import Foundation
import Cocoa
// Stolen from https://stackoverflow.com/a/38138336
class PaddedTextField: NSTextFieldCell {
    
    @IBInspectable var leftPadding: CGFloat = 10.0
    
    override func drawingRect(forBounds rect: NSRect) -> NSRect {
        let rectInset = NSMakeRect(rect.origin.x + leftPadding, rect.origin.y, rect.size.width - leftPadding, rect.size.height)
        return super.drawingRect(forBounds: rectInset)
    }
}
