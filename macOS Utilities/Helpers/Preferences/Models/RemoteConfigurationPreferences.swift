//
//  RemoteConfigurationPreferences.swift
//  macOS Utilities
//
//  Created by Keaton Burleson on 4/12/19.
//  Copyright © 2019 Keaton Burleson. All rights reserved.
//

import Foundation

class RemoteConfigurationPreferences: Codable, Equatable {
    var hostURL: URL?
    var configurationURL: URL?
    var filePath: URL?
    var name: String

    static func == (lhs: RemoteConfigurationPreferences, rhs: RemoteConfigurationPreferences) -> Bool {
        return lhs.hostURL == rhs.hostURL
    }

    var isValid: Bool {
        return self.configurationURL != nil
    }

    init(hostURL: URL?, configurationURL: URL?, name: String?) {
        self.configurationURL = configurationURL
        self.hostURL = hostURL

        if let _name = name {
            self.name = _name
        } else {
            self.name = String()
        }
    }
    
    convenience init(filePath: URL, name: String?) {
        self.init(hostURL: nil, configurationURL: nil, name: nil)
        
        self.filePath = filePath
        
        if let _name = name {
            self.name = _name
        } else {
            self.name = String()
        }
    }

    convenience init() {
        self.init(hostURL: nil, configurationURL: nil, name: nil)
    }

    func generateTestHTMLContent() -> String? {
        if let fileURL = self.configurationURL {
            let urlScheme = "open-utilities://"
            return "<a href=\"\(urlScheme)\(self.hostURL!)\(fileURL.absolutePath.dashedFileName)\">\(self.name)</a>"
        }
        return nil
    }
}
