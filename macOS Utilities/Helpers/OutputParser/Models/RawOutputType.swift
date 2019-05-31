//
//  RawOutputType.swift
//  macOS Utilities
//
//  Created by Keaton Burleson on 5/13/19.
//  Copyright © 2019 Keaton Burleson. All rights reserved.
//

import Foundation

protocol RawOutputType {
    var toolType: OutputToolType { set get }
    var type: OutputType { set get }
}
