//
//  SystemProfilerData.swift
//  macOS Utilities
//
//  Created by Keaton Burleson on 5/17/19.
//  Copyright © 2019 Keaton Burleson. All rights reserved.
//

import Foundation

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
            } catch {
                print(error)
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

        return self.items as! [A]
    }

    static func register<A: Decodable>(_ type: A.Type, for dataType: SPDataType) {
        decoders[dataType] = { container in
            try container.decode([A].self, forKey: .items)
        }
    }
}

