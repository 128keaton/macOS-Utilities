//
//  SystemProfilerProtocols.swift
//  macOS Utilities
//
//  Created by Keaton Burleson on 6/23/20.
//  Copyright © 2020 Keaton Burleson. All rights reserved.
//

import Foundation

protocol ConcreteItemType: ItemType {
    associatedtype ItemType
}

protocol ConcreteStorageItemType: ConcreteItemType, StorageItem {
    associatedtype StorageItem
}
