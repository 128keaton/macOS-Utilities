//
//  Preference.swift
//  macOS Utilities
//
//  Created by Keaton Burleson on 4/10/19.
//  Copyright © 2019 Keaton Burleson. All rights reserved.
//

import Foundation

protocol GenericType {
    func isEqualTo(other: GenericType) -> Bool
}
extension GenericType where Self : Equatable {
    func isEqualTo(other: GenericType) -> Bool {
        if let o = other as? Self { return self == o }
        return false
    }
}

extension UInt : GenericType {}
extension String : GenericType {}
extension Bool : GenericType {}


class Preferences: Codable, NSCopying {
    
    func copy(with zone: NSZone? = nil) -> Any {
        let data = try! PropertyListEncoder().encode(self)
        return  try! PropertyListDecoder().decode(Preferences.self, from: data)
    }
    
    
    var helpEmailAddress: String?
    var deviceIdentifierAuthenticationToken: String?
    var loggingPreferences: LoggingPreferences
    var installerServerPreferences: InstallerServerPreferences
    var applications: Dict?

    private var mappedApplications: [Application]? = nil

    var useDeviceIdentifierAPI: Bool {
        return self.deviceIdentifierAuthenticationToken != nil
    }

    public func getApplications() -> [Application] {
        if (mappedApplications == nil) {
            if let applications = self.applications {
                mappedApplications = (applications.objectValue?.map {
                    Application(name: $0, path: $1.stringValue!)
                })!
            }
        }

        return mappedApplications!
    }
    
    public func setApplications(_ applications: [Application]){
        self.mappedApplications = applications
    }
}

enum Dict: Codable, CustomStringConvertible {
    func encode(to encoder: Encoder) throws {
        print("Encoding not working")
    }

    var description: String {
        switch self {
        case .string(let string): return "\"\(string)\""
        case .object(let object):
            return "\"\(object)\""
        case .null:
            return "null"
        }
    }

    var isEmpty: Bool {
        switch self {
        case .string(let string): return string.isEmpty
        case .object(let object): return object.isEmpty
        case .null: return true
        }
    }

    struct Key: CodingKey, Hashable, CustomStringConvertible {
        var description: String {
            return stringValue
        }

        func hash(into hasher: inout Hasher) {
            hasher.combine(stringValue)
        }

        static func == (lhs: Dict.Key, rhs: Dict.Key) -> Bool {
            return lhs.stringValue == rhs.stringValue
        }

        let stringValue: String
        init(_ string: String) { self.stringValue = string }
        init?(stringValue: String) { self.init(stringValue) }
        var intValue: Int? { return nil }
        init?(intValue: Int) { return nil }
    }

    case string(String)
    case object([Key: Dict])
    case null

    init(from decoder: Decoder) throws {
        if let string = try? decoder.singleValueContainer().decode(String.self) { self = .string(string) }
            else if let object = try? decoder.container(keyedBy: Key.self) {
                var result: [Key: Dict] = [:]
                for key in object.allKeys {
                    result[key] = (try? object.decode(Dict.self, forKey: key)) ?? .null
                }
                self = .object(result)

        } else {
                self = .null
        }
    }

    var objectValue: [String: Dict]? {
        switch self {
        case .object(let object):
            let mapped: [String: Dict] = Dictionary(uniqueKeysWithValues:
                object.map { (key, value) in (key.stringValue, value) })
            return mapped
        default: return nil
        }
    }

    subscript(key: String) -> Dict? {
        guard let DictKey = Key(stringValue: key),
            case .object(let object) = self,
            let value = object[DictKey]
            else { return nil }
        return value
    }

    var stringValue: String? {
        switch self {
        case .string(let string): return string
        default: return nil
        }
    }

    var doubleValue: Double? {
        return nil
    }

    var intValue: Int? {
        return nil
    }

    subscript(index: Int) -> Dict? {
        return nil
    }

    var boolValue: Bool? {
        return nil
    }
}
