//
//  NestedItemType.swift
//  macOS Utilities
//
//  Created by Keaton Burleson on 5/25/19.
//  Copyright © 2019 Keaton Burleson. All rights reserved.
//

import Foundation

protocol NestedItemType: Decodable {
    var items: [Decodable] { get }
}
