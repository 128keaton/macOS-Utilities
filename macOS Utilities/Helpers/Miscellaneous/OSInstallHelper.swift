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
    func didError(_ error: String)
}

class OSInstallHelper {
    private static var delegate: OSInstallDelegate?
    private static var installerPath: String = ""
    private static var installer: Installer?

    public static func setDelegate(_ newDelegate: OSInstallDelegate) {
        self.delegate = newDelegate
    }

    public static func setInstaller(_ installer: Installer) {
        self.installerPath = installer.installerPath
        self.installer = installer
    }

    public static func getInstaller() -> Installer? {
        return self.installer
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
            if let line = String(data: pipe.availableData, encoding: String.Encoding.utf8),
                (line.count > 1) {
                DispatchQueue.main.async {
                    self.delegate?.updateOutput(line)
                }
                print("New ouput: \(line)")
            } else {
                print("Error decoding data: \(pipe.availableData)")
            }
        }

        errorHandle.readabilityHandler = { pipe in
            if let line = String(data: pipe.availableData, encoding: String.Encoding.utf8) {
                if (line.contains("Error:")) {
                    DispatchQueue.main.async {
                        self.delegate?.didError(line)
                    }
                }
            } else {
                print("Error decoding data: \(pipe.availableData)")
            }
        }

        installTask.launch()
    }
}
