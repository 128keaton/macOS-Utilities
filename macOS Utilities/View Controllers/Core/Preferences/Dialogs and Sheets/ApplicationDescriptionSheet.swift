//
//  ApplicationDescriptionSheet.swift
//  macOS Utilities
//
//  Created by Keaton Burleson on 6/23/20.
//  Copyright © 2020 Keaton Burleson. All rights reserved.
//

import Foundation

class ApplicationDescriptionSheet: NSViewController {
    public var application: Application?

    @IBOutlet var appDescriptionTextView: NSTextView?
    @IBOutlet var editingLabel: NSTextField?

    override func viewDidLoad() {
        if let application = self.application,
            let description = application.appDescription {
            self.appDescriptionTextView?.string = description
            self.editingLabel?.stringValue = "Editing description for \(application.name)"

        } else if let application = self.application {
            self.editingLabel?.stringValue = "Adding description for \(application.name)"
        }
    }

    @IBAction func doneEditing(_ sender: NSButton) {
        if let applicationsPrefsController = self.presentingViewController as? PreferencesApplicationsViewController {
            applicationsPrefsController.appDescriptionUpdated(self.appDescriptionTextView!.string)
        }
        
        self.dismiss(self)
    }

    @IBAction func cancelEditing(_ sender: NSButton) {
        self.dismiss(self)
    }
}
