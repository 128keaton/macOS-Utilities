//
//  CameraPreview.swift
//  Apple Evaluation
//
//  Created by Keaton Burleson on 5/17/19.
//  Copyright © 2019 Keaton Burleson. All rights reserved.
//

import Foundation
import AppKit

class CameraPreview: NSView {
    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        
        self.layer?.cornerRadius = 4
        self.wantsLayer = true
    }
}
