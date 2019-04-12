//
//  InstallerServerPreferences.swift
//  macOS Utilities
//
//  Created by Keaton Burleson on 4/10/19.
//  Copyright © 2019 Keaton Burleson. All rights reserved.
//

import Foundation

class InstallerServerPreferences: Codable, Equatable {
    var serverPath: String
    var serverIP: String
    var serverType: String
    var mountPath: String
    var serverEnabled: Bool
    
    func isMountable() -> Bool {
        return serverPath.trimmingCharacters(in: .whitespaces) != "" && serverIP.trimmingCharacters(in: .whitespaces) != "" && mountPath.trimmingCharacters(in: .whitespaces) != ""
    }
    
    static func isMountable(_ installerServerPreferences: InstallerServerPreferences) -> Bool {
        return installerServerPreferences.isMountable()
    }

    static func ==(lhs: InstallerServerPreferences, rhs: InstallerServerPreferences) -> Bool {
        
        let mLhs = Mirror(reflecting: lhs).children.filter { $0.label != nil }
        let mRhs = Mirror(reflecting: rhs).children.filter { $0.label != nil }
        
        for i in 0..<mLhs.count {
            guard let valLhs = mLhs[i].value as? GenericType, let valRhs = mRhs[i].value as? GenericType else {
                print("Invalid: Properties 'lhs.\(mLhs[i].label!)' and/or 'rhs.\(mRhs[i].label!)' are not of 'MyGenericType' types.")
                return false
            }
            if !valLhs.isEqualTo(other: valRhs) {
                return false
            }
        }
        return true
    }
    
    init(serverEnabled: Bool? = true, serverPath: String?, serverIP: String?, serverType: String?, mountPath: String?) {
        if let _enabled = serverEnabled {
            self.serverEnabled = _enabled
        } else {
            self.serverEnabled = false
        }
        
        if let _sPath = serverPath {
            self.serverPath = _sPath
        } else {
            self.serverPath = String()
        }
        
        if let _ip = serverIP {
            self.serverIP = _ip
        } else {
            self.serverIP = String()
        }
        
        if let _type = serverType {
            self.serverType = _type
        } else {
            self.serverType = String()
        }
        
        if let _mPath = serverType {
            self.mountPath = _mPath
        } else {
            self.mountPath = String()
        }
    }
    
    convenience init() {
        self.init(serverEnabled: true, serverPath: nil, serverIP: nil, serverType: nil, mountPath: nil)
    }
}
