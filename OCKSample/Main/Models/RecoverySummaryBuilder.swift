//
//  RecoverySummaryBuilder.swift
//  OCKSample
//
//  Created by Yulin on 3/22/26.
//

import CareKit
import CareKitStore
import Foundation
import ParseSwift

@MainActor
final class RecoverySummaryBuilder {

    func buildSummary(for date: Date = Date()) async throws -> DailyRecoverySummary {
        guard let appDelegate = AppDelegateKey.defaultValue else {
            throw AppError.errorString("AppDelegate is missing.")
        }

        let summaryDate = Calendar.current.startOfDay(for: date)
        let query = OCKEventQuery(for: summaryDate)
        let events = try await appDelegate.storeCoordinator.fetchAnyEvents(query: query)

        let voiceDiscomfort = surveyNumber(
            for: "\(TaskID.symptomTracking)-voice",
            in: events
        )
        let swallowingDiscomfort = surveyNumber(
            for: "\(TaskID.symptomTracking)-swallowing",
            in: events
        )
        let hydrationTaskStatus = taskStatus(
            for: TaskID.doxylamine,
            in: events
        )
        let walkingTaskStatus = taskStatus(
            for: TaskID.walking,
            in: events
        )
        let stepCount = intValue(
            for: TaskID.steps,
            in: events
        )
        let restingHeartRate = doubleValue(
            for: TaskID.ovulationTestResult,
            in: events
        )
        let postOpDay = await makePostOpDay(for: summaryDate)

        return DailyRecoverySummary(
            date: summaryDate,
            postOpDay: postOpDay,
            voiceDiscomfort: voiceDiscomfort,
            swallowingDiscomfort: swallowingDiscomfort,
            hydrationTaskStatus: hydrationTaskStatus,
            walkingTaskStatus: walkingTaskStatus,
            stepCount: stepCount,
            restingHeartRate: restingHeartRate
        )
    }

    private func makePostOpDay(for date: Date) async -> Int {
        guard let user = try? await User.current(),
              let createdAt = user.createdAt else {
            return 1
        }

        let startDate = Calendar.current.startOfDay(for: createdAt)
        let targetDate = Calendar.current.startOfDay(for: date)
        let days = Calendar.current.dateComponents([.day], from: startDate, to: targetDate).day ?? 0

        return max(days + 1, 1)
    }

    private func surveyNumber(for questionID: String, in events: [OCKAnyEvent]) -> Int? {
        for event in events {
            guard let values = event.outcome?.values else {
                continue
            }

            for value in values {
                guard value.kind == questionID else {
                    continue
                }

                if let intValue = value.integerValue {
                    return intValue
                }

                if let doubleValue = value.doubleValue {
                    return Int(doubleValue.rounded())
                }
            }
        }

        return nil
    }

    private func taskStatus(for taskID: String, in events: [OCKAnyEvent]) -> DailyTaskSignalStatus {
        let taskEvents = events.filter { $0.task.id == taskID }

        if taskEvents.isEmpty {
            return .missing
        }

        let allCompleted = taskEvents.allSatisfy { event in
            guard let outcome = event.outcome else {
                return false
            }

            return outcome.values.isEmpty == false
        }

        return allCompleted ? .completed : .incomplete
    }

    private func intValue(for taskID: String, in events: [OCKAnyEvent]) -> Int? {
        let taskEvents = events.filter { $0.task.id == taskID }

        for event in taskEvents {
            guard let values = event.outcome?.values else {
                continue
            }

            for value in values {
                if let intValue = value.integerValue {
                    return intValue
                }

                if let doubleValue = value.doubleValue {
                    return Int(doubleValue.rounded())
                }
            }
        }

        return nil
    }

    // Returns summaries for the most recent windowDays days
    // Order: [today, yesterday, day before, ...]
    func buildRecentSummaries(windowDays: Int = 3) async throws -> [DailyRecoverySummary] {
        var summaries: [DailyRecoverySummary] = []
        let today = Date()

        for dayOffset in 0..<windowDays {
            let targetDate = Calendar.current.date(byAdding: .day, value: -dayOffset, to: today)!
            let summary = try await buildSummary(for: targetDate)
            summaries.append(summary)
        }

        return summaries
    }

    private func doubleValue(for taskID: String, in events: [OCKAnyEvent]) -> Double? {
        let taskEvents = events.filter { $0.task.id == taskID }

        for event in taskEvents {
            guard let values = event.outcome?.values else {
                continue
            }

            for value in values {
                if let doubleValue = value.doubleValue {
                    return doubleValue
                }

                if let intValue = value.integerValue {
                    return Double(intValue)
                }
            }
        }

        return nil
    }
}
