//
//  WizardViewController.swift
//  macOS Utilities
//
//  Created by Keaton Burleson on 4/9/19.
//  Copyright © 2019 Keaton Burleson. All rights reserved.
//

import Foundation
import AppKit

class WizardViewController: NSViewController {
    @IBOutlet weak var loadingSpinner: NSProgressIndicator?
    @IBOutlet weak var titleTextField: NSTextField?
    @IBOutlet weak var finishedImageView: NSImageView?
    @IBOutlet weak var descriptionLabel: NSTextField?

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

    override func viewDidLoad() {
        super.viewDidLoad()
        updateView()
    }

    public func updateView() {
        updateViewMode()
        updateLoadingLabel()
        updateDescriptionLabel()
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
}

enum WizardViewMode {
    case loading
    case finish
}
