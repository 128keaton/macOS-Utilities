//
//  SystemProfilerData.swift
//  macOS Utilities
//
//  Created by Keaton Burleson on 5/17/19.
//  Copyright © 2019 Keaton Burleson. All rights reserved.
//

import Foundation
import CocoaLumberjack

struct SystemProfilerItem: Decodable, CustomStringConvertible {
    var dataType: SPDataType
    var items: [Any]?

    enum CodingKeys: String, CodingKey {
        case dataType = "_dataType"
        case parentDataType = "_parentDataType"
        case items = "_items"
    }

    var description: String {
        return "\(self.dataType) - \(String(describing: self.items))"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        dataType = SPDataType(rawValue: try container.decode(String.self, forKey: .dataType)) ?? .invalid

        if let decode = SystemProfilerItem.decoders[dataType] {
            do {
                items = try decode(container) as? [Any]
            } catch let DecodingError.typeMismatch(type, context)  {
                DDLogError("Type '\(type)' mismatch: \(context.debugDescription)")
                DDLogVerbose("codingPath: \(context.codingPath)")
            } catch let DecodingError.dataCorrupted(context) {
                DDLogError("Data Corrupted: \(context.debugDescription)")
            } catch {
                DDLogError(error.localizedDescription)
            }
        } else {
            items = nil
        }
    }

    private typealias SystemProfilerDataDecoder = (KeyedDecodingContainer<CodingKeys>) throws -> Any

    private static var decoders: [SPDataType: SystemProfilerDataDecoder] = [:]

    func getItems<A: ItemType>(_ type: A.Type) -> [A] {
        if A.isNested, let items = self.items, let nestedItem = items.first as? NestedItemType {
            return nestedItem.items as! [A]
        }

        if let validItems = self.items as? [A] {
            return validItems
        }
        
        DDLogVerbose("Items were nil for \(A.self)")
        return [A]()
    }

    static func register<A: Decodable>(_ type: A.Type, for dataType: SPDataType) {
        decoders[dataType] = { container in
            try container.decode([A].self, forKey: .items)
        }
    }
}

