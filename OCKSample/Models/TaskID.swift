//
//  TaskID.swift
//  OCKSample
//
//  Created by Corey Baker on 4/14/23.
//  Copyright © 2023 Network Reconnaissance Lab. All rights reserved.
//

import Foundation

enum TaskID {
    static let doxylamine = "doxylamine"
    static let nausea = "nausea"
    static let stretch = "stretch"
    static let kegels = "kegels"
    static let walking = "walking"
    static let neckMobility = "neckMobility"
    static let onboard = "onboard"
    static let rangeOfMotion = "rangeOfMotion"
    static let steps = "steps"
    static let ovulationTestResult = "restingHeartRate"
    static let keckResource = "custom-task-keck-resource"
    static let symptomTracking = "symptomTracking"
    static let WeeklyEvaluation = "weeklyEvaluation"
    static let thyroidModel = "thyroidModel"

    static var ordered: [String] {
        orderedObjective + orderedSubjective
    }

    static var orderedObjective: [String] {
        [ Self.steps, Self.ovulationTestResult ]
    }

    static var orderedSubjective: [String] {
        [ Self.doxylamine, Self.kegels, Self.stretch, Self.nausea ]
    }

    static var orderedWatchOS: [String] {
        [ Self.doxylamine, Self.kegels, Self.stretch ]
    }
}
