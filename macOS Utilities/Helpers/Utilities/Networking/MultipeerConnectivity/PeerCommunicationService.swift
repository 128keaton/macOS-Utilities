//
//  PeerCommunicationService.swift
//  macOS Utilities
//
//  Created by Keaton Burleson on 8/28/19.
//  Copyright © 2019 Keaton Burleson. All rights reserved.
//

import Foundation
import MultiPeer
import MultipeerConnectivity
import CocoaLumberjack
import AVFoundation

public class PeerCommunicationService {
    public static let instance = PeerCommunicationService()
    
    private var audioPlayer: AVAudioPlayer?
    
    init() {
        let modelIdentifier = Sysctl.model
        let ipAddress = NetworkUtils.getNetworkAddress()

        MultiPeer.instance.delegate = self

        MultiPeer.instance.initialize(serviceType: "mac-os-utils", deviceName: "\(modelIdentifier):\(ipAddress)")
        MultiPeer.instance.startAccepting()
        
        do {
            if let fileURL = Bundle.main.path(forResource: "SwTest1_Haptic", ofType: "caf") {
                audioPlayer = try AVAudioPlayer(contentsOf: URL(fileURLWithPath: fileURL))
            } else {
                print("No file with specified name exists")
            }
        } catch let error {
            print("Can't play the audio file failed with an error \(error.localizedDescription)")
        }

    }
    
    var serialNumber: String? {
        let platformExpert = IOServiceGetMatchingService(kIOMasterPortDefault, IOServiceMatching("IOPlatformExpertDevice"))
        
        guard platformExpert > 0 else {
            return nil
        }
        
        guard let serialNumber = (IORegistryEntryCreateCFProperty(platformExpert, kIOPlatformSerialNumberKey as CFString, kCFAllocatorDefault, 0).takeUnretainedValue() as? String)?.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines) else {
            return nil
        }
        
        
        IOObjectRelease(platformExpert)
        
        return serialNumber
    }
}

extension PeerCommunicationService: MultiPeerDelegate {
    public func multiPeer(didReceiveData data: Data, ofType type: UInt32) {
        let clientPeerID = MultiPeer.instance.devicePeerID

        switch type {
        case MessageType.locateRequest.rawValue:
            DDLogVerbose("Computer beep requested")
            
            if let audioPlayer = self.audioPlayer {
                audioPlayer.play()
            }
            
            break

        case MessageType.clientInfoRequest.rawValue:
            DDLogVerbose("clientInfoRequest")

            let serverPeerID = data.convert() as! MCPeerID
            let serverPeer = Peer(peerID: serverPeerID, state: .connected)

            if let serialNumber = self.serialNumber {
                DDLogVerbose("Sending serial number response with serial number: \(serialNumber)")
                NSKeyedArchiver.setClassName("ClientInfo", for: ClientInfo.self)

                let clientInfo = ClientInfo(serialNumber: serialNumber, peerID: clientPeerID!)
                let data = NSKeyedArchiver.archivedData(withRootObject: clientInfo)

                MultiPeer.instance.send(data: data, type: MessageType.clientInfoResponse.rawValue, toPeer: serverPeer)
            }
            break

        default:
            break
        }
    }

    public func multiPeer(connectedPeersChanged peers: [Peer]) {
        print("Connected devices changed: \(peers)")
        
        if (peers.count == 1) {
            DDLogVerbose("Stop accepting connections, we have a single peer")
            MultiPeer.instance.stopAccepting()
        } else {
            DDLogVerbose("Start accepting connections, we have no peer")
            MultiPeer.instance.startAccepting()
        }
    }
}
