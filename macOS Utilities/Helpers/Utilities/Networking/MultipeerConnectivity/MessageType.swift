//
//  MessageType.swift
//  macOS Utilities
//
//  Created by Keaton Burleson on 8/28/19.
//  Copyright © 2019 Keaton Burleson. All rights reserved.
//

import Foundation

enum MessageType: UInt32 {
    case clientInfoRequest = 1
    case locateRequest = 2
    case clientInfoResponse = 3
    case locateResponse = 4
}
