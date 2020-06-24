//
//  TabbedPreferenceViewController.swift
//  macOS Utilities
//
//  Created by Keaton Burleson on 6/23/20.
//  Copyright © 2020 Keaton Burleson. All rights reserved.
//

import Foundation

class TabbedPreferenceViewController: NSTabViewController {
    var childPreferenceViews: [PreferencesViewType] = []

    override func viewDidLoad() {
        super.viewDidLoad()

        self.childPreferenceViews = self.tabViewItems.map {
            return $0.viewController as! PreferencesViewType
        }
    }

    override func viewWillDisappear() {
        self.childPreferenceViews.forEach {
            $0.savePreferences()
        }

        if let preferenceLoader = PreferenceLoader.sharedInstance,
            let preferences = PreferenceLoader.currentPreferences {

            preferenceLoader.save(preferences)
        }
    }
}
