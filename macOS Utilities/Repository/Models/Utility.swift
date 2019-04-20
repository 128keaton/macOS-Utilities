//
//  Utility.swift
//  macOS Utilities
//
//  Created by Keaton Burleson on 4/19/19.
//  Copyright © 2019 Keaton Burleson. All rights reserved.
//

import Foundation

class Utility: NSObject, Item, Codable  {
    static let prohibatoryIcon = NSImage(named: "NSHaltIcon")
    var name: String
    var path: String
    var isInvalid = false
    var id: String {
        get {
            return self.name.md5Value
        }
    }
    
    var showInApplicationsWindow = true
    
    override var description: String {
        return "\(self.name): \(self.path)"
    }
    
    func addToRepo() {
        // Not needed
    }
    
    init(name: String, path: String, showInApplicationsWindow: Bool = false) {
        self.path = path
        self.name = name
        
        if path == "" {
            self.isInvalid = true
        }
        
        self.showInApplicationsWindow = showInApplicationsWindow
    }
    
    public func open() {
        NSWorkspace.shared.open(URL(fileURLWithPath: self.path))
    }
    
    static func == (lhs: Utility, rhs: Utility) -> Bool {
        return lhs.path == rhs.path &&
            lhs.name == rhs.name && lhs.id == rhs.id
    }
}
