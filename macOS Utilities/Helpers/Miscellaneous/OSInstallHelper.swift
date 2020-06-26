//
//  OSInstallHelper.swift
//  macOS Utilities
//
//  Created by Keaton Burleson on 6/25/20.
//  Copyright © 2020 Keaton Burleson. All rights reserved.
//

import Foundation

protocol OSInstallDelegate {
    func updateOutput(_ newline: String)
}

class OSInstallHelper {
    private static var delegate: OSInstallDelegate?
    private static var installerPath: String = ""
    
    public static func setDelegate(_ newDelegate: OSInstallDelegate) {
        self.delegate = newDelegate
    }
    
    public static func setInstaller(_ installer: Installer) {
        self.installerPath = installer.installerPath
    }
    
    public static func kickoffInstaller() {
        let installTask = Process()
        installTask.launchPath = "\(self.installerPath)/Contents/Resources/startosinstall"
        installTask.arguments = ["--agreetolicense", "--volume", "/Volumes/Macintosh HD"]
        
        let outputPipe = Pipe()
        let errorPipe = Pipe()
        
        installTask.standardOutput = outputPipe
        installTask.standardError = errorPipe
        
        let outputHandle = outputPipe.fileHandleForReading
        let errorHandle = errorPipe.fileHandleForReading

        outputHandle.readabilityHandler = { pipe in
            if let line = String(data: pipe.availableData, encoding: String.Encoding.utf8) {
                self.delegate?.updateOutput(line)
                print("New ouput: \(line)")
            } else {
                print("Error decoding data: \(pipe.availableData)")
            }
        }
        
        errorHandle.readabilityHandler = { pipe in
            if let line = String(data: pipe.availableData, encoding: String.Encoding.utf8) {
                print("New ouput: \(line)")
            } else {
                print("Error decoding data: \(pipe.availableData)")
            }
        }

    }
}
