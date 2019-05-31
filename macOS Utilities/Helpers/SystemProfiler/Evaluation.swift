//
//  Evaluation.swift
//  AVTest
//
//  Created by Keaton Burleson on 5/24/19.
//  Copyright © 2019 Keaton Burleson. All rights reserved.
//

import Foundation

struct Evaluation: Encodable {
    var testingNotes: String
    var machineInfo: CondensedSystemProfilerData

    init(testingNotes: String, condensedData machineInfo: CondensedSystemProfilerData) {
        self.machineInfo = machineInfo
        self.testingNotes = testingNotes
    }
}

enum CodingKeys: String, CodingKey {
    case machineInfo = "machine"
    case testingNotes
}
