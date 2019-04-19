//
//  DiskOrPartition.swift
//  macOS Utilities
//
//  Created by Keaton Burleson on 4/19/19.
//  Copyright © 2019 Keaton Burleson. All rights reserved.
//

import Foundation

enum DataType{
    case disk
    case partition
}

protocol DiskOrPartition{
    var dataType: DataType { get }
}
