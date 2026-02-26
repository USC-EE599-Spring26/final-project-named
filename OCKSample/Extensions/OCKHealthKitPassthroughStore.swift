//
//  OCKHealthKitPassthroughStore.swift
//  OCKSample
//
//  Created by Corey Baker on 1/5/22.
//  Copyright © 2022 Network Reconnaissance Lab. All rights reserved.
//

import Foundation
import CareKitEssentials
import CareKitStore
import HealthKit
import os.log

extension OCKHealthKitPassthroughStore {

    func populateDefaultHealthKitTasks(
        startDate: Date = Date()
    ) async throws {

        let countUnit = HKUnit.count()
        let stepTargetValue = OCKOutcomeValue(
            4000.0,
            units: countUnit.unitString
        )
        let stepTargetValues = [ stepTargetValue ]
        let stepSchedule = OCKSchedule.dailyAtTime(
            hour: 8,
            minutes: 0,
            start: startDate,
            end: nil,
            text: nil,
            duration: .allDay,
            targetValues: stepTargetValues
        )
        var recoveryStepCount = OCKHealthKitTask(
            id: TaskID.recoveryStepCount,
            title: String(localized: "TASK_RECOVERY_STEPS_TITLE"),
            carePlanUUID: nil,
            schedule: stepSchedule,
            healthKitLinkage: OCKHealthKitLinkage(
                quantityIdentifier: .stepCount,
                quantityType: .cumulative,
                unit: countUnit
            )
        )
        recoveryStepCount.asset = "figure.walk"
        recoveryStepCount.instructions = String(localized: "TASK_RECOVERY_STEPS_INSTRUCTIONS")
        recoveryStepCount.userInfo = [
            Constants.taskCardStyleKey: "numericProgress",
            Constants.taskDomainKey: Constants.thyroidDomainValue
        ]

        let restingHeartRateSchedule = OCKSchedule.dailyAtTime(
            hour: 7,
            minutes: 0,
            start: startDate,
            end: nil,
            text: nil,
            duration: .allDay,
            targetValues: []
        )
        var restingHeartRateTrend = OCKHealthKitTask(
            id: TaskID.restingHeartRateTrend,
            title: String(localized: "TASK_RESTING_HR_TITLE"),
            carePlanUUID: nil,
            schedule: restingHeartRateSchedule,
            healthKitLinkage: OCKHealthKitLinkage(
                quantityIdentifier: .restingHeartRate,
                quantityType: .discrete,
                unit: HKUnit.count().unitDivided(by: .minute())
            )
        )
        restingHeartRateTrend.asset = "heart.circle.fill"
        restingHeartRateTrend.instructions = String(localized: "TASK_RESTING_HR_INSTRUCTIONS")
        restingHeartRateTrend.userInfo = [
            Constants.taskCardStyleKey: "labeledValue",
            Constants.taskDomainKey: Constants.thyroidDomainValue
        ]
        let tasks = [ recoveryStepCount, restingHeartRateTrend ]

        _ = try await addTasksIfNotPresent(tasks)

    }
}
