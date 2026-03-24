//
//  DailyRecoverySummary.swift
//  OCKSample
//
//  Created by Yulin on 3/22/26.
//

import Foundation

enum DailyTaskSignalStatus: String, Codable {
    case completed
    case incomplete
    case missing
}

struct DailyRecoverySummary: Codable {
    let date: Date
    let postOpDay: Int
    let voiceDiscomfort: Int?
    let swallowingDiscomfort: Int?
    let hydrationTaskStatus: DailyTaskSignalStatus
    let walkingTaskStatus: DailyTaskSignalStatus
    let stepCount: Int?
    let restingHeartRate: Double?

    func prettyPrintedJSON() -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601

        guard let data = try? encoder.encode(self),
              let text = String(data: data, encoding: .utf8) else {
            return "Could not encode DailyRecoverySummary."
        }

        return text
    }
}
