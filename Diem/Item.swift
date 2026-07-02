//
//  Item.swift
//  Diem
//
//  Created by Alex Villacres on 7/2/26.
//

import Foundation
import SwiftData

@Model
final class Item {
    var timestamp: Date
    
    init(timestamp: Date) {
        self.timestamp = timestamp
    }
}
