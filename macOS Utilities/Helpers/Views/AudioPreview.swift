//
//  AudioPreview.swift
//  Apple Evaluation
//
//  Created by Keaton Burleson on 5/17/19.
//  Copyright © 2019 Keaton Burleson. All rights reserved.
//

import Foundation
import AppKit
import AudioKitUI

class AudioPreview: EZAudioPlot {
    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        
        self.layer?.cornerRadius = 4
        
        self.wantsLayer = true
    }
}
