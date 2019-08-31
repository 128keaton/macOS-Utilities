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

public class PeerCommunicationService: NSObject {
    private var audioPlayer: AVAudioPlayer?
    private var serverPeer: Peer?

    public static var instance = PeerCommunicationService()

    private let notificationCenter = NSUserNotificationCenter.default

    override init() {
        super.init()

        let modelIdentifier = Sysctl.model
        let ipAddress = NetworkUtils.getNetworkAddress()

        self.notificationCenter.delegate = self

        MultiPeer.instance.delegate = self

        MultiPeer.instance.initialize(serviceType: "mac-os-utils", deviceName: "\(modelIdentifier):\(ipAddress)")
        MultiPeer.instance.startAccepting()


        do {
            if let fileURL = Bundle.main.path(forResource: "fmd_sound", ofType: "aiff") {
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

    private func createAlertNotification() {
        let notification = NSUserNotification()

        notification.title = "macOS Utilities"
        notification.subtitle = "An alert was sent from the hypervisor"

        notificationCenter.deliver(notification)
    }

    private func flashScreen() {
        let inDuration: CGDisplayFadeInterval = 0.2
        let outDuration: CGDisplayFadeInterval = 1.5
        let color = NSColor.white

        var fadeToken: CGDisplayFadeReservationToken = 0
        let colorToUse = color.usingColorSpaceName(NSColorSpaceName.calibratedRGB)!
        let err = CGAcquireDisplayFadeReservation(inDuration + outDuration, &fadeToken)

        if err != CGError.success {
            DDLogError("Error acquiring fade reservation")
            return
        }

        CGDisplayFade(fadeToken, inDuration,
                      0.0 as CGDisplayBlendFraction, 0.2 as CGDisplayBlendFraction,
                      Float(colorToUse.redComponent), Float(colorToUse.greenComponent), Float(colorToUse.blueComponent),
                      boolean_t(1))
        CGDisplayFade(fadeToken, outDuration,
                      0.2 as CGDisplayBlendFraction, 0.0 as CGDisplayBlendFraction,
                      Float(colorToUse.redComponent), Float(colorToUse.greenComponent), Float(colorToUse.blueComponent),
                      boolean_t(1))
    }

    public func updateStatus(_ status: String) {
        if let validServerPeer = self.serverPeer {
            let clientInfo = ClientInfo(serialNumber: serialNumber!, peerID: MultiPeer.instance.devicePeerID!)
            clientInfo.status = status

            NSKeyedArchiver.setClassName("ClientInfo", for: ClientInfo.self)
            let data = NSKeyedArchiver.archivedData(withRootObject: clientInfo)

            MultiPeer.instance.send(data: data, type: MessageType.clientInfoResponse.rawValue, toPeer: validServerPeer)
        } else {
            DDLogError("No valid server peer")
        }
    }
}

extension PeerCommunicationService: MultiPeerDelegate {
    public func multiPeer(didReceiveData data: Data, ofType type: UInt32) {
        let clientPeerID = MultiPeer.instance.devicePeerID
        let serverPeerID = data.convert() as! MCPeerID

        self.serverPeer = Peer(peerID: serverPeerID, state: .connected)

        switch type {
        case MessageType.locateRequest.rawValue:
            DDLogVerbose("Computer beep requested")

            if let audioPlayer = self.audioPlayer {
                audioPlayer.play()
            }

            self.createAlertNotification()
            self.flashScreen()

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                self.flashScreen()
                if let audioPlayer = self.audioPlayer {
                    audioPlayer.play()
                }
            }

            MultiPeer.instance.send(object: MultiPeer.instance.devicePeerID!, type: MessageType.locateResponse.rawValue, toPeer: self.serverPeer!)
            break

        case MessageType.clientInfoRequest.rawValue:
            DDLogVerbose("clientInfoRequest")

            if let serialNumber = self.serialNumber {
                DDLogVerbose("Sending serial number response with serial number: \(serialNumber)")
                NSKeyedArchiver.setClassName("ClientInfo", for: ClientInfo.self)

                let clientInfo = ClientInfo(serialNumber: serialNumber, peerID: clientPeerID!)
                let data = NSKeyedArchiver.archivedData(withRootObject: clientInfo)

                MultiPeer.instance.send(data: data, type: MessageType.clientInfoResponse.rawValue, toPeer: self.serverPeer!)
            }
            break

        default:
            break
        }
    }

    public func multiPeer(connectedPeersChanged peers: [Peer]) {
        print("Connected devices changed: \(peers)")

        if (peers.filter { $0.state == .connected }.count >= 1) {
            DDLogVerbose("Stop accepting connections, we have a single peer")
            MultiPeer.instance.stopAccepting()
        } else {
            DDLogVerbose("Start accepting connections, we have no peer")
            MultiPeer.instance.startAccepting()
        }
    }
}

extension PeerCommunicationService: NSUserNotificationCenterDelegate {
    public func userNotificationCenter(_ center: NSUserNotificationCenter, shouldPresent notification: NSUserNotification) -> Bool {
        return true
    }
}
