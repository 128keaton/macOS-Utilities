//
//  TestPreferenceLoader.swift
//  macOS UtilitiesTests
//
//  Created by Keaton Burleson on 4/19/19.
//  Copyright © 2019 Keaton Burleson. All rights reserved.
//

import XCTest
import Foundation
import Cocoa

class TestPreferenceLoader: XCTestCase {
    var preferenceLoader: PreferenceLoader? = nil

    override func setUp() {
        PreferenceLoader.setup()
        self.preferenceLoader = PreferenceLoader.sharedInstance
    }


    func testPreferenceLoaderExists() {
        XCTAssert(self.preferenceLoader != nil, "Preference loader exists")
    }
}
