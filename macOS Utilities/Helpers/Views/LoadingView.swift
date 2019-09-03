//
//  LoadingView.swift
//  AVTest
//
//  Created by Keaton Burleson on 5/24/19.
//  Copyright © 2019 Keaton Burleson. All rights reserved.
//

import Foundation
import AppKit

class LoadingView: NSView {
    @IBOutlet private var progressIndicator: NSProgressIndicator!
    @IBOutlet private var contentView: NSView!

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        loadInterface()
    }

    required init?(coder decoder: NSCoder) {
        super.init(coder: decoder)
        loadInterface()
    }

    private func loadInterface() {
        Bundle.main.loadNibNamed("LoadingView", owner: self, topLevelObjects: nil)
        
        addSubview(contentView)
        contentView.frame = self.bounds
        contentView.autoresizingMask = [.height, .width]

        startProgressIndicator()
    }

    public func startProgressIndicator() {
        self.progressIndicator.startAnimation(self)
    }
}
