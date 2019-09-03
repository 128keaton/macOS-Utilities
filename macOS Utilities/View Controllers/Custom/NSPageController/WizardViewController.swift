//
//  WizardViewController.swift
//  macOS Utilities
//
//  Created by Keaton Burleson on 4/9/19.
//  Copyright © 2019 Keaton Burleson. All rights reserved.
//

import Foundation
import AppKit
import CocoaLumberjack

class WizardViewController: NSViewController {
    static let cancelButtonNotification = Notification.Name(rawValue: "NSPageCancelButtonClicked")

    @IBOutlet weak var loadingSpinner: NSProgressIndicator?
    @IBOutlet weak var titleTextField: NSTextField?
    @IBOutlet weak var finishedImageView: NSImageView?
    @IBOutlet weak var descriptionLabel: NSTextField?
    @IBOutlet weak var dismissButton: NSButton?
    @IBOutlet weak var otherButton: NSButton?
    @IBOutlet weak var cancelButton: NSButton?

    public var titleText: String = "Loading" {
        didSet {
            updateLoadingLabel()
        }
    }

    public var descriptionText: String = "" {
        didSet {
            updateDescriptionLabel()
        }
    }

    public var viewMode: WizardViewMode = .loading {
        didSet {
            updateViewMode()
        }
    }

    public var otherButtonSelector: Selector? = nil {
        didSet {
            updateOtherButtonSelector()
        }
    }

    public var otherButtonSelectorTarget: AnyObject? = nil {
        didSet {
            updateOtherButtonSelector()
        }
    }

    public var otherButtonTitle: String = "Next" {
        didSet {
            updateOtherButtonTitle()
        }
    }

    public var cancelButtonIdentifier: String? = nil {
        didSet {
            if let validCancelButton = self.cancelButton {
                validCancelButton.isHidden = false
            }
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        updateView()
    }

    public func updateView() {
        updateViewMode()
        updateLoadingLabel()
        updateDescriptionLabel()
        updateOtherButtonSelector()
        updateOtherButtonTitle()

        if cancelButtonIdentifier == nil,
            let validCancelButton = self.cancelButton {
            validCancelButton.isHidden = true
        }
    }

    public func updateViewMode() {
        switch viewMode {
        case .loading:
            hideFinishedImageView()
            showLoadingSpinner()
        default:
            hideLoadingSpinner()
            showFinishedImageView()
        }
    }

    public func updateLoadingLabel() {
        guard isViewLoaded else {
            return
        }
        self.titleTextField?.stringValue = self.titleText
    }

    public func updateDescriptionLabel() {
        guard isViewLoaded else {
            return
        }
        self.descriptionLabel?.stringValue = self.descriptionText
    }

    override func viewWillAppear() {
        if(viewMode == .loading) {
            loadingSpinner?.startSpinning()
        }
    }

    override func viewWillDisappear() {
        loadingSpinner?.stopSpinning()
    }

    private func hideLoadingSpinner() {
        guard let loadingSpinner = self.loadingSpinner
            else {
                return
        }
        loadingSpinner.stopSpinning()
        loadingSpinner.isHidden = true
    }

    private func showLoadingSpinner() {
        guard let loadingSpinner = self.loadingSpinner
            else {
                return
        }
        loadingSpinner.startSpinning()
        loadingSpinner.isHidden = false
    }

    private func hideFinishedImageView() {
        guard let finishedImageView = self.finishedImageView
            else {
                return
        }
        finishedImageView.isHidden = true
    }

    private func showFinishedImageView() {
        guard let finishedImageView = self.finishedImageView
            else {
                return
        }
        finishedImageView.isHidden = false
    }

    private func updateOtherButtonSelector() {
        guard let otherButton = self.otherButton
            else {
                return
        }

        if otherButtonSelector == nil {
            otherButton.isHidden = true
        } else {
            otherButton.isHidden = false
        }

        otherButton.isHidden = false

        otherButton.action = #selector(performOtherButtonAction)
        otherButton.target = self
    }

    @objc private func performOtherButtonAction() {
        guard let otherButtonSelector = self.otherButtonSelector
            else {
                return
        }

        guard let otherButtonSelectorTarget = self.otherButtonSelectorTarget
            else {
                return
        }

        DDLogInfo("Performing action: \(otherButtonSelector) on target \(otherButtonSelectorTarget)")
        let _ = otherButtonSelectorTarget.perform(otherButtonSelector)
    }

    @IBAction func cancelButtonAction(_ sender: NSButton) {
        NotificationCenter.default.post(name: WizardViewController.cancelButtonNotification, object: cancelButtonIdentifier)
    }

    private func updateOtherButtonTitle() {
        guard let otherButton = self.otherButton
            else {
                return
        }

        otherButton.title = otherButtonTitle
    }

    @IBAction func dismissPageController(_ sender: NSButton) {
        PageController.shared.dismissPageController()
    }
}

enum WizardViewMode {
    case loading
    case finish
}
