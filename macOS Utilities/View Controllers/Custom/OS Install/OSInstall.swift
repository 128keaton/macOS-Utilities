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

    var chosenInstaller: Installer?

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
            currentStep.outputTextView?.textStorage?.append(NSAttributedString(string: newline))
        }
    }
    
    func updateStep() {
        if let stepController = self.stepController {
            if let confirmViewController = self.currentStep as? ConfirmViewController {
                confirmViewController.versionToInstall = self.chosenInstaller!.version.name
                
                stepController.selectedTabViewItemIndex = currentStepIndex
                self.currentStep = self.getAllSteps()[currentStepIndex]
            } else {
                OSInstallHelper.setInstaller(self.chosenInstaller!)
                OSInstallHelper.kickoffInstaller()
            }
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
}

