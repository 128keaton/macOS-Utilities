//
//  RepositoryItem.swift
//  macOS Utilities
//
//  Created by Keaton Burleson on 4/4/19.
//  Copyright © 2019 Keaton Burleson. All rights reserved.
//

import Foundation
import AppKit
import CocoaLumberjack

class RepositoryItem: NSObject {
    private(set) var id: String = ""
    private(set) var searchableEntityName: String = ""
    private(set) var sortNumber: NSNumber? = nil
    private(set) var sortString: String? = nil

    func addToRepo() { }

    static func == (lhs: RepositoryItem, rhs: RepositoryItem) -> Bool {
        return lhs.id == rhs.id
    }
}
