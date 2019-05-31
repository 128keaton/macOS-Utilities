//
//  KBTableView.swift
//  macOS Utilities
//
//  Created by Keaton Burleson on 4/19/19.
//  Copyright © 2019 Keaton Burleson. All rights reserved.
//

import Foundation
import AppKit

class KBTableView: NSTableView {
    override open func mouseDown(with event: NSEvent) {
        let globalLocation = event.locationInWindow
        let localLocation = convert(globalLocation, from: nil)
        let clickedRow = row(at: localLocation)

        if clickedRow == -1 {
            self.deselectAll(self)
            if let delegate = self.delegate {
                if delegate is NSTableViewDelegateDeselectListener {
                    (delegate as! NSTableViewDelegateDeselectListener).tableView?(self, didDeselectAllRows: true)
                    return
                }
            }
            return super.mouseDown(with: event)
        } else {
            if let delegate = self.delegate {
                if delegate is NSTableViewDelegateDeselectListener {
                    if let shouldSelect = delegate.tableView?(self, shouldSelectRow: clickedRow) {
                        if shouldSelect {
                            return self.selectRowIndexes(IndexSet(integer: clickedRow), byExtendingSelection: false)
                        }
                    }
                }
            }
            return super.mouseDown(with: event)
        }
    }
}

@objc protocol NSTableViewDelegateDeselectListener: NSTableViewDelegate {
    @objc optional func tableView(_ tableView: NSTableView, didDeselectAllRows: Bool)
}
