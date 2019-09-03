//
//  Client.swift
//  macOS Utilities
//
//  Created by Keaton Burleson on 8/28/19.
//  Copyright © 2019 Keaton Burleson. All rights reserved.
//

import Foundation
import MultiPeer

class Client {
    private (set) public var ipAddress: String
    private (set) public var modelIdentifier: String
    private (set) public var peer: Peer
    
    private var _serialNumber: String?
    
    public var hasSerialNumber: (String) -> () = { _ in }
    
    init(_ fromPeer: Peer) {
        self.peer = fromPeer
        
        let splitPeerDisplayName = fromPeer.peerID.displayName.split(separator: ":")
        
        if (splitPeerDisplayName.indices.contains(0) && splitPeerDisplayName.indices.contains(1)) {
            ipAddress = String(splitPeerDisplayName[1])
            modelIdentifier = String(splitPeerDisplayName[0])
        } else {
            ipAddress = "Unknown"
            modelIdentifier = "Unknown"
        }
    }
    
    public var serialNumber: String? {
        get {
            return self._serialNumber
        }
        set {
            self._serialNumber = newValue
            
            if let validSerialNumber = newValue {
                self.hasSerialNumber(validSerialNumber)
            }
        }
    }
    
    public var displayName: String {
        get {
            return self.peer.peerID.displayName
        }
    }
}

