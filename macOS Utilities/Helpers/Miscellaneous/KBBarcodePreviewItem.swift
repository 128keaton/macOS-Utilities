//
//  KBBarcodePreviewItem.swift
//  macOS Utilities
//
//  Created by Keaton Burleson on 5/31/19.
//  Copyright © 2019 Keaton Burleson. All rights reserved.
//

import Foundation
import AppKit
import Quartz
import QuickLook

class KBBarcodePreviewItem: NSObject, QLPreviewItem {
    var previewItemURL: URL?
    var previewItemTitle: String!
}
