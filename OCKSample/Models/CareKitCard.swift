//
//  CareKitCard.swift
//  OCKSample
//
//  Created by Corey Baker on 2/26/26.
//  Copyright © 2026 Network Reconnaissance Lab. All rights reserved.
//

import Foundation

enum CareKitCard: String, CaseIterable, Identifiable {
    var id: Self { self }
    case button = "Log"
    case checklist = "Remainder"
    case featured = "Featured"
    case grid = "Grid"
    case instruction = "Instruction"
    case labeledValue = "Labeled Value"
    case link = "Link"
    case numericProgress = "Numeric Progress"
    case simple = "TODO"
    case survey = "Survey"
    case custom = "Custom"

    static func fromStoredValue(_ value: String) -> CareKitCard? {
        if let currentValue = CareKitCard(rawValue: value) {
            return currentValue
        }

        switch value {
        case "Button":
            return .button
        case "Checklist":
            return .checklist
        case "Simple":
            return .simple
        default:
            return nil
        }
    }

    // add
    var supportHealthKitTask: Bool {
        switch self {
        case .numericProgress, .labeledValue:
            return true
        default:
            return false
        }
    }
}
