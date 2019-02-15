//
//  NSCollectionAppCell.swift
//  macOS Utilities
//
//  Created by Keaton Burleson on 7/26/18.
//  Copyright © 2018 Keaton Burleson. All rights reserved.
//

import Foundation
import AppKit

class NSCollectionAppCell: NSCollectionViewItem {
    @IBOutlet weak var icon: NSImageView?
    @IBOutlet weak var titleLabel: NSTextField?
    
    public var regularImage: NSImage? = nil
    public var darkenedImage: NSImage? = nil
    
    override var isSelected: Bool {
        didSet {
            icon?.image = isSelected ? self.darkenedImage:self.regularImage
        }
    }
    

}
