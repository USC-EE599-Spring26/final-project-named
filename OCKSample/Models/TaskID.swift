//
//  TaskID.swift
//  OCKSample
//
//  Created by Corey Baker on 4/14/23.
//  Copyright © 2023 Network Reconnaissance Lab. All rights reserved.
//

import Foundation

enum TaskID {
    static let levothyroxineMedication = "levothyroxineMedication"
    static let calciumSupplement = "calciumSupplement"
    static let incisionCareCheck = "incisionCareCheck"
    static let symptomScore = "symptomScore"
    static let voiceRestExercise = "voiceRestExercise"
    static let followUpReminder = "followUpReminder"
    static let recoveryStepCount = "recoveryStepCount"
    static let restingHeartRateTrend = "restingHeartRateTrend"

    static let doxylamine = "doxylamine"
    static let nausea = "nausea"
    static let stretch = "stretch"
    static let kegels = "kegels"
    static let steps = "steps"
    static let ovulationTestResult = "ovulationTestResult"

    static var ordered: [String] {
        orderedObjective + orderedSubjective
    }

    static var orderedObjective: [String] {
        [
            Self.levothyroxineMedication,
            Self.calciumSupplement,
            Self.incisionCareCheck,
            Self.voiceRestExercise,
            Self.followUpReminder,
            Self.recoveryStepCount,
            Self.restingHeartRateTrend
        ]
    }

    static var orderedSubjective: [String] {
        [ Self.symptomScore ]
    }

    static var orderedWatchOS: [String] {
        [ Self.doxylamine, Self.kegels, Self.stretch ]
    }
}
