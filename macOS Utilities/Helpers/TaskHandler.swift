//
//  TaskHandler.swift
//  macOS Utilities
//
//  Created by Keaton Burleson on 4/1/19.
//  Copyright © 2019 Keaton Burleson. All rights reserved.
//

import Foundation
import CocoaLumberjack

class TaskHandler{
    public static func createTask(command: String, arguments: [String], printStandardOutput: Bool = false, returnEscaping: @escaping (String?) -> () ) {
        let task = Process()
        let errorPipe = Pipe()
        let standardPipe = Pipe()
        
        task.standardError = errorPipe
        task.standardOutput = standardPipe
        
        task.launchPath = command
        task.arguments = arguments
        
        task.terminationHandler = { (process) in
            if(process.isRunning == false){
                let errorHandle = errorPipe.fileHandleForReading
                let errorData = errorHandle.readDataToEndOfFile()
                let taskErrorOutput = String (data: errorData, encoding: String.Encoding.utf8)
                
                let standardHandle = standardPipe.fileHandleForReading
                let standardData = standardHandle.readDataToEndOfFile()
                let taskStandardOutput = String (data: standardData, encoding: String.Encoding.utf8)
                
                if(taskErrorOutput != nil && taskErrorOutput!.count > 0) {
                    DDLogError("Task \(task.launchPath ?? "") \(task.arguments.map { "\($0) " } ?? ""): ")
                    DDLogError("Task failed with: \(taskErrorOutput ?? "No errors..") \(taskStandardOutput ?? "No standard output..") ")
                    returnEscaping(String("\(taskErrorOutput ?? "No errors")\n\(taskStandardOutput ?? "No standard output")"))
                }
                
                if(printStandardOutput){
                    DDLogInfo(taskStandardOutput ?? "")
                }
                
                DDLogInfo("Task \(task.launchPath ?? "") \(task.arguments?.joined(separator: " ") ?? "") was executed")
                returnEscaping(taskStandardOutput)
            }
        }
        
        task.launch()
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
            DDLogError("Task failed with: \(taskErrorOutput ?? "No errors..") \(taskStandardOutput ?? "No standard output..") ")
            return false
        }
        
        return true
    }
}
