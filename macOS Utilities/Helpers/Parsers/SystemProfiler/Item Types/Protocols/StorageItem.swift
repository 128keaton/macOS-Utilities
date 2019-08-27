//
//  StorageItem.swift
//  AVTest
//
//  Created by Keaton Burleson on 5/17/19.
//  Copyright © 2019 Keaton Burleson. All rights reserved.
//

import Foundation

protocol StorageItem: ItemType {
    var serialNumber: String { get }
    var storageItemType: String { get }
    var manufacturer: String { get }
    var isSSD: Bool { get }
    var name: String { get }
    var size: String { get }
    var rawSize: Double { get }
    var rawSizeUnit: String { get }
    subscript(key: String) -> String { get }
}
