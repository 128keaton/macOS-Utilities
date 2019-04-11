//
//  TaskHandler.swift
//  macOS Utilities
//
//  Created by Keaton Burleson on 4/1/19.
//  Copyright © 2019 Keaton Burleson. All rights reserved.
//

import Foundation
import CocoaLumberjack

class TaskHandler {
    public static func createTask(command: String, arguments: [String], printStandardOutput: Bool = false, hideTaskFailed: Bool = false, returnEscaping: @escaping (String?) -> ()) {
        let task = Process()
        let errorPipe = Pipe()
        let standardPipe = Pipe()

        task.standardError = errorPipe
        task.standardOutput = standardPipe

        task.launchPath = command
        task.arguments = arguments

        task.terminationHandler = { (process) in
            if(process.isRunning == false) {
                let errorHandle = errorPipe.fileHandleForReading
                let errorData = errorHandle.readDataToEndOfFile()
                let taskErrorOutput = String (data: errorData, encoding: String.Encoding.utf8)

                let standardHandle = standardPipe.fileHandleForReading
                let standardData = standardHandle.readDataToEndOfFile()
                let taskStandardOutput = String (data: standardData, encoding: String.Encoding.utf8)

                if(taskErrorOutput != nil && taskErrorOutput!.count > 0 && hideTaskFailed == false) {
                    DDLogVerbose("Task \(task.launchPath ?? "") \(task.arguments.map { "\($0) " } ?? ""): ")
                    DDLogVerbose("Task failed with: \(taskErrorOutput ?? "No errors..") \(taskStandardOutput ?? "No standard output..") ")
                    returnEscaping("\(taskErrorOutput ?? "No errors..") \(taskStandardOutput ?? "No standard output..") ")
                    return
                } else if(taskErrorOutput != nil && taskErrorOutput!.count > 0 && hideTaskFailed == true) {
                    returnEscaping("\(taskErrorOutput ?? "No errors..") \(taskStandardOutput ?? "No standard output..") ")
                    return
                }

                if(printStandardOutput) {
                    DDLogInfo(taskStandardOutput ?? "")
                }

                DDLogInfo("Task \(task.launchPath ?? "") \(task.arguments?.joined(separator: " ") ?? "") was executed")
                returnEscaping(taskStandardOutput)
            }
        }

        DDLogInfo("Task \(task.launchPath ?? "") \(task.arguments?.joined(separator: " ") ?? "") was scheduled.")
        task.launch()
    }

    public static func createTask(command: String, arguments: [String], timeout: TimeInterval, returnEscaping: @escaping (String?) -> ()) {
        DispatchQueue.global(qos: .default).async {
            let task = Process()
            let errorPipe = Pipe()
            let standardPipe = Pipe()

            let standardHandle = standardPipe.fileHandleForReading
            standardHandle.waitForDataInBackgroundAndNotify()

            let errorHandle = errorPipe.fileHandleForReading
            errorHandle.waitForDataInBackgroundAndNotify()

            task.standardError = errorPipe
            task.standardOutput = standardPipe

            task.launchPath = command
            task.arguments = arguments

            DDLogInfo("Task \(task.launchPath ?? "") \(task.arguments?.joined(separator: " ") ?? "") was scheduled with timeout \(timeout).")

            var standardOutputDataListener: NSObjectProtocol!

            standardOutputDataListener = NotificationCenter.default.addObserver(forName: NSNotification.Name.NSFileHandleDataAvailable, object: standardHandle, queue: nil) { notification -> Void in
                let standardData = standardHandle.availableData
                if standardData.count > 0 {
                    if let outputString = String(data: standardData, encoding: String.Encoding.utf8) {
                        DDLogInfo("Task \(task.launchPath ?? "") - \(outputString)")
                    }
                    standardHandle.waitForDataInBackgroundAndNotify()
                } else {
                    NotificationCenter.default.removeObserver(standardOutputDataListener!)
                }
            }

            var errorOutputDataListener: NSObjectProtocol!

            errorOutputDataListener = NotificationCenter.default.addObserver(forName: NSNotification.Name.NSFileHandleDataAvailable, object: standardHandle, queue: nil) { notification -> Void in
                let errorData = errorHandle.availableData
                if errorData.count > 0 {
                    if let outputString = String(data: errorData, encoding: String.Encoding.utf8) {
                        DDLogVerbose("Task \(task.launchPath ?? "") - \(outputString)")
                    }
                    errorHandle.waitForDataInBackgroundAndNotify()
                } else {
                    NotificationCenter.default.removeObserver(errorOutputDataListener!)
                }
            }

            var taskTerminatedListener: NSObjectProtocol!
            taskTerminatedListener = NotificationCenter.default.addObserver(forName: Process.didTerminateNotification, object: task, queue: nil) { _ -> Void in
                NotificationCenter.default.removeObserver(standardOutputDataListener!)
                NotificationCenter.default.removeObserver(errorOutputDataListener!)
                NotificationCenter.default.removeObserver(taskTerminatedListener!)
            }

            let taskGroup = DispatchGroup()
            task.terminationHandler = { (_) in
                taskGroup.leave()
            }

            taskGroup.enter()
            task.launch()

            let waitOutput = taskGroup.wait(timeout: DispatchTime.now() + DispatchTimeInterval.seconds(Int(timeout)))
            DDLogInfo("Task \(task.launchPath ?? "") \(task.arguments?.joined(separator: " ") ?? "") wait output: \(waitOutput)")

            DispatchQueue.main.sync {
                if(task.isRunning == false) {
                    let errorData = errorHandle.readDataToEndOfFile()
                    let taskErrorOutput = String (data: errorData, encoding: String.Encoding.utf8)

                    let standardData = standardHandle.readDataToEndOfFile()
                    let taskStandardOutput = String (data: standardData, encoding: String.Encoding.utf8)

                    if(taskErrorOutput != nil && taskErrorOutput!.count > 0) {
                        returnEscaping("\(taskErrorOutput ?? "No errors..") \(taskStandardOutput ?? "No standard output..") ")
                        return
                    }

                    DDLogInfo("Task \(task.launchPath ?? "") \(task.arguments?.joined(separator: " ") ?? "") was executed")
                    returnEscaping(taskStandardOutput)
                } else {
                    let status = kill(task.processIdentifier, Int32(15))
                    DDLogInfo("Task \(task.launchPath ?? "") \(task.arguments?.joined(separator: " ") ?? "") was killed: \(status)")
                    returnEscaping("Task \(task.launchPath ?? "") \(task.arguments?.joined(separator: " ") ?? "") was killed: \(status)")
                }
            }
        }
    }

    public static func createTaskWithStatus(command: String, arguments: [String]) -> Bool {
        let task = Process()
        let errorPipe = Pipe()
        let standardPipe = Pipe()

        task.standardError = errorPipe
        task.standardOutput = standardPipe

        task.launchPath = command
        task.arguments = arguments

        task.launch()
        task.waitUntilExit()

        let errorHandle = errorPipe.fileHandleForReading
        let errorData = errorHandle.readDataToEndOfFile()
        let taskErrorOutput = String (data: errorData, encoding: String.Encoding.utf8)

        let standardHandle = standardPipe.fileHandleForReading
        let standardData = standardHandle.readDataToEndOfFile()
        let taskStandardOutput = String (data: standardData, encoding: String.Encoding.utf8)

        if(taskErrorOutput != nil && taskErrorOutput!.count > 0) {
            DDLogVerbose("Task failed with: \(taskErrorOutput ?? "No errors..") \(taskStandardOutput ?? "No standard output..") ")
            return false
        }

        return true
    }
}
