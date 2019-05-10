//
//  Utility.swift
//  macOS Utilities
//
//  Created by Keaton Burleson on 4/19/19.
//  Copyright © 2019 Keaton Burleson. All rights reserved.
//

import Foundation
import AppKit
import CocoaLumberjack

class Utility: Application  {
    override init(name: String, path: String, showInApplicationsWindow: Bool = false) {
        var utilityPath = path
        
        if !utilityPath.contains("/Applications/Utilities/") {
            utilityPath = "/Applications/Utilities/\(utilityPath)"
        }
        
        if !utilityPath.contains(".app") {
            utilityPath = "\(utilityPath).app"
        }
        
        super.init(name: name, path: utilityPath, showInApplicationsWindow: showInApplicationsWindow)
        self.isUtility = true
    }
    
    required init(from decoder: Decoder) throws {
        try super.init(from: decoder)
    }
    
    override var description: String {
        return "Utility: \(super.description)"
    }
    
    override func addToRepo() {
        ItemRepository.shared.addToRepository(newItem: self)
    }
    
    static func getFromUtilitiesFolder() {
        do {
            try FileManager.default.contentsOfDirectory(atPath: "/Applications/Utilities").forEach {
                let utilityPath = $0
                let utilityName = utilityPath.split(separator: "/").last!.replacingOccurrences(of: ".app", with: "")
                if utilityName.first! != "." {
                    Utility(name: utilityName, path: utilityPath).addToRepo()
                }
            }
        } catch {
            DDLogError("Could not get utilities from /Applications/Utilities")
        }
    }
}
