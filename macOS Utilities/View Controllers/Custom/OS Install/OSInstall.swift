//
//  OSInstall.swift
//  macOS Utilities
//
//  Created by Keaton Burleson on 6/25/20.
//  Copyright © 2020 Keaton Burleson. All rights reserved.
//

import Foundation

class OSInstallStep: NSViewController { }

class OSInstall: NSViewController, OSInstallDelegate {
    @IBOutlet var statusLabel: NSTextField?
    @IBOutlet var nextButton: NSButton?
    @IBOutlet var backButton: NSButton?

    var currentStep: OSInstallStep?
    var currentStepIndex: Int = 0
    var stepController: NSTabViewController?



    override func viewDidLoad() {
        OSInstallHelper.setDelegate(self)
        self.statusLabel?.stringValue = "Install macOS"
    }

    override func prepare(for segue: NSStoryboardSegue, sender: Any?) {
        if segue.identifier == "showStepView", let stepController = segue.destinationController as? NSTabViewController {
            self.stepController = stepController
            self.currentStepIndex = stepController.selectedTabViewItemIndex
            self.currentStep = self.getAllSteps()[currentStepIndex]
            self.updateStep()
        }
    }

    func updateOutput(_ newline: String) {
        if let currentStep = self.currentStep as? OutputViewController {
            let attributedLine = NSMutableAttributedString(string: newline)
            attributedLine.addAttribute(.foregroundColor, value: NSColor.labelColor, range: NSRange(location: 0, length: newline.count))
            currentStep.outputTextView?.textStorage?.append(attributedLine)
        }
    }

    func didError(_ error: String) {
        self.showErrorSheet(message: error)
    }

    func updateStep() {
        if let stepController = self.stepController {
            stepController.selectedTabViewItemIndex = currentStepIndex
            self.currentStep = self.getAllSteps()[currentStepIndex]
        }
    }

    func getAllSteps() -> [OSInstallStep] {
        return self.stepController!.tabViewItems.map {
            return $0.viewController as! OSInstallStep
        }
    }

    @IBAction func goNext(_ sender: NSButton) {
        self.backButton?.isEnabled = false

        self.currentStepIndex += 1
        self.updateStep()
    }

    @IBAction func goBack(_ sender: NSButton) {
        self.view.window?.close()
    }

    private func showErrorSheet(message: String) {
        let errorAlert = NSAlert()

        errorAlert.messageText = "Error"
        errorAlert.informativeText = message.replacingOccurrences(of: "Error: ", with: "")
        errorAlert.alertStyle = .critical
        errorAlert.addButton(withTitle: "OK")

        errorAlert.beginSheetModal(for: self.view.window!) { (_) in
            DispatchQueue.main.async {
                self.view.window?.close()
            }
        }
    }
}

