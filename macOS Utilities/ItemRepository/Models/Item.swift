//
//  Item.swift
//  macOS Utilities
//
//  Created by Keaton Burleson on 4/4/19.
//  Copyright © 2019 Keaton Burleson. All rights reserved.
//

import Foundation
import AppKit
import CocoaLumberjack

protocol Item: CustomStringConvertible, Equatable {
    var id: String { get }
    var description: String  { get }
    func addToRepo()
}

class ItemType : Item {
    var id: String = ""
    var description: String = ""
    func addToRepo() {}
    
    static func == (lhs: ItemType, rhs: ItemType) -> Bool {
        return lhs.id == rhs.id
    }
}
