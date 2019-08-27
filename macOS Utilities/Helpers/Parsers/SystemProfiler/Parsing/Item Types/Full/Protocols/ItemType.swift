//
//  ItemType.swift
//  macOS Utilities
//
//  Created by Keaton Burleson on 5/17/19.
//  Copyright © 2019 Keaton Burleson. All rights reserved.
//

import Foundation

protocol ItemType: Codable, CustomStringConvertible {
    var dataType: SPDataType { get }
    static var isNested: Bool { get }
}
