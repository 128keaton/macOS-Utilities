//
//  OutputParser.swift
//  macOS Utilities
//
//  Created by Keaton Burleson on 5/13/19.
//  Copyright © 2019 Keaton Burleson. All rights reserved.
//

import Foundation
import CocoaLumberjack

class OutputParser {
    public func parseOutput<T: RawOutputType>(_ inputString: String, toolType: OutputToolType, outputType: OutputType) throws -> T {
        if let rawData = inputString.data(using: .utf8) {
            switch toolType {
            case .diskUtility:
                switch outputType {
                case .info:
                    return try decode(DiskUtilityInfo.self, from: rawData, string: inputString) as! T
                case .list:
                    return try decode(DiskUtilityList.self, from: rawData, string: inputString) as! T
                case .coreStorageList:
                    return try decode(DiskUtilityCoreStorageList.self, from: rawData, string: inputString) as! T
                default:
                    throw OutputParserError.invalidOutput(forTool: toolType)
                }
            case .hdiutil:
                switch outputType {
                case .mount:
                    return try decode(hdiutilMount.self, from: rawData, string: inputString) as! T
                default:
                    throw OutputParserError.invalidOutput(forTool: toolType)
                }
            case .invalid:
                throw OutputParserError.invalidOutputTool
            }

        }
        throw OutputParserError.parseFailed(reason: "\(inputString) was invalid")
    }

    private func decode<T: RawOutputType>(_ type: T.Type, from objectData: Data, string objectRawData: String) throws -> T where T: Decodable {
        let propertyListDecoder = PropertyListDecoder()
        do {
            return try propertyListDecoder.decode(type, from: objectData)
        } catch {
            if error is DecodingError {
                DDLogVerbose("Parsing error was thrown on data. Data: \n\(objectRawData). Error: \n\(error.localizedDescription) ")
                throw OutputParserError.parseFailed(reason: "Unable to parse for type \(type): \(error.localizedDescription)")
            } else {
                throw OutputParserError.parseFailed(reason: "Unable to parse for type \(type): \(error)")
            }
        }
    }
}

enum OutputParserError: Error {
    case parseFailed(reason: String)
    case invalidOutputTool
    case invalidOutput(forTool: OutputToolType)
}

enum OutputToolType {
    case invalid
    case hdiutil
    case diskUtility
}

enum OutputType {
    case invalid
    case info
    case mount
    case list
    case coreStorageList
}
