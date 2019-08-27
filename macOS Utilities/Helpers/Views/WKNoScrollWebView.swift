//
//  WKNoScrollWebView.swift
//  macOS Utilities
//
//  Created by Keaton Burleson on 5/31/19.
//  Copyright © 2019 Keaton Burleson. All rights reserved.
//

import Foundation
import WebKit
import AppKit

class WKNoScrollWebView: WKWebView {
    public var canScroll = false
    
    override init(frame: CGRect, configuration: WKWebViewConfiguration) {
        super.init(frame: frame, configuration: configuration)
        print(self.canScroll)
    }
    
    required init?(coder: NSCoder) {
       super.init(coder: coder)
    }
    
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
