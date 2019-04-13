//
//  RemoteConfigurationPreferences.swift
//  macOS Utilities
//
//  Created by Keaton Burleson on 4/12/19.
//  Copyright © 2019 Keaton Burleson. All rights reserved.
//

import Foundation

class RemoteConfigurationPreferences: Codable, Equatable {
    var remoteURL: URL
    var configurationURLs: [URL]
    var name: String
    
    static func == (lhs: RemoteConfigurationPreferences, rhs: RemoteConfigurationPreferences) -> Bool {
        return lhs.remoteURL == rhs.remoteURL
    }
    
    init(remoteURL: URL?, configurationURLs: [URL]?, name: String?){
        if let _urls = configurationURLs{
            self.configurationURLs = _urls
        }else{
            self.configurationURLs = [URL]()
        }
        
        if let _url = remoteURL{
            self.remoteURL = _url
        }else{
            self.remoteURL = URL(string: "http://invalid.co")!
        }
        
        if let _name = name{
            self.name = _name
        }else{
            self.name = String()
        }
    }
    
    convenience init(){
        self.init(remoteURL: nil, configurationURLs: nil, name: nil)
    }
}
