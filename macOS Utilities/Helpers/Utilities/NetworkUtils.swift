//
//  NetworkUtils.swift
//  macOS Utilities
//
//  Created by Keaton Burleson on 6/27/19.
//  Copyright © 2019 Keaton Burleson. All rights reserved.
//
// https://stackoverflow.com/a/25627545

import Foundation
import CocoaLumberjack

public final class NetworkUtils: NSObject, NetServiceDelegate {
    fileprivate var netService: NetService?

    public static func getAllAddresses(ipv6: Bool = false) -> [String] {
        var addresses = [String]()

        // Get list of all interfaces on the local machine:
        var ifaddr: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&ifaddr) == 0 else { return [] }
        guard let firstAddr = ifaddr else { return [] }

        // For each interface ...
        for ptr in sequence(first: firstAddr, next: { $0.pointee.ifa_next }) {
            let flags = Int32(ptr.pointee.ifa_flags)
            let addr = ptr.pointee.ifa_addr.pointee

            // Check for running IPv4, IPv6 interfaces. Skip the loopback interface.
            if (flags & (IFF_UP | IFF_RUNNING | IFF_LOOPBACK)) == (IFF_UP | IFF_RUNNING) {
                if addr.sa_family == UInt8(AF_INET) || (ipv6 && addr.sa_family == UInt8(AF_INET6)) {

                    // Convert interface address to a human readable string:
                    var hostname = [CChar](repeating: 0, count: Int(NI_MAXHOST))
                    if (getnameinfo(ptr.pointee.ifa_addr, socklen_t(addr.sa_len), &hostname, socklen_t(hostname.count),
                                    nil, socklen_t(0), NI_NUMERICHOST) == 0) {
                        let address = String(cString: hostname)
                        addresses.append(address)
                    }
                }
            }
        }

        freeifaddrs(ifaddr)

        return addresses
    }


    public func startPublishing() {
        guard let networkAddress = (NetworkUtils.getAllAddresses().first { (address) -> Bool in
            let validIP = "^(([0-9]|[1-9][0-9]|1[0-9]{2}|2[0-4][0-9]|25[0-5])\\.){3}([0-9]|[1-9][0-9]|1[0-9]{2}|2[0-4][0-9]|25[0-5])$"
            return (address.range(of: validIP, options: .regularExpression) != nil)
        }) else {
            return
        }
        
        let name = "\(networkAddress) - \(Sysctl.model)"
        netService = NetService(domain: "", type: "_mosu-logger._tcp", name: name, port: 8080)

        netService?.delegate = self
        
        netService?.includesPeerToPeer = true
        netService?.publish()

        RunLoop.current.run()

        DDLogInfo("Started advertising Bonjour service '_mosu-logger._tcp' \(Sysctl.model)")
    }

    public func netServiceWillPublish(_ sender: NetService) {
        DDLogInfo("Initializing advertising Bonjour service '_mosu-logger._tcp'")
    }

    public func netService(_ sender: NetService, didNotPublish errorDict: [String: NSNumber]) {
        DDLogError("Bonjour publishing error: \(errorDict)")
    }
}
