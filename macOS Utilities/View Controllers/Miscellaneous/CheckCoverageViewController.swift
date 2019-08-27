//
//  CheckCoverageViewController.swift
//  macOS Utilities
//
//  Created by Keaton Burleson on 5/31/19.
//  Copyright © 2019 Keaton Burleson. All rights reserved.
//

import Foundation
import AppKit
import WebKit

class CheckCoverageViewController: NSViewController {
    @IBOutlet public var webView: WKNoScrollWebView!

    public var urlToOpen: URL? = nil

    private var progressIndicator: NSProgressIndicator? = nil

    override func viewDidLoad() {
        webView.hide(animated: false)
    }

    override func viewDidAppear() {
        super.viewDidAppear()

        createProgressIndicator()
        webView.hide()
        webView.navigationDelegate = self
        webView.allowsLinkPreview = false
        webView.configuration.preferences.setValue(true, forKey: "developerExtrasEnabled")

        if let validURL = self.urlToOpen {
            webView.load(URLRequest(url: validURL))
        }
    }

    private func createProgressIndicator() {
        if progressIndicator == nil {
            let size: CGFloat = 18.0
            let xValue = (self.view.frame.width / 2.0) - (size / 2.0)
            let yValue = (self.view.frame.height / 2.0) - (size / 2.0)

            progressIndicator = NSProgressIndicator(frame: NSRect(x: xValue, y: yValue, width: size, height: size))
            progressIndicator?.style = .spinning
            progressIndicator?.startSpinning()

            self.view.addSubview(progressIndicator!)
        }
    }

    private func removeProgressIndicator() {
        if let _progressIndicator = self.progressIndicator {
            _progressIndicator.removeFromSuperview()
            self.progressIndicator = nil
        }
    }

    @IBAction func doneButtonPressed(_ sender: NSButton) {
        self.dismiss(self)
    }
}

extension CheckCoverageViewController: WKNavigationDelegate {
    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        if (navigationAction.request.url?.absoluteString.contains("checkcoverage.apple.com"))! {
            self.webView.hide()
            self.createProgressIndicator()
            decisionHandler(WKNavigationActionPolicy.allow)
        } else {
            decisionHandler(WKNavigationActionPolicy.cancel)
        }
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        if webView.url?.absoluteString.contains("/us/en/") ?? false {
            (webView as! WKNoScrollWebView).removeWebViewElements {
                (webView as! WKNoScrollWebView).scrollToElementInWebView(elementID: "product", completion: {
                    self.webView.show()
                    self.webView.canScroll = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5, execute: {
                            self.removeProgressIndicator()
                        })
                })
            }
        } else {
            (webView as! WKNoScrollWebView).scrollToElementInWebView(elementID: "view-selector-4", offset: -15, completion: {
                self.webView.show()
                self.webView.canScroll = false
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5, execute: {
                        self.removeProgressIndicator()
                    })
            })

        }
    }
}
