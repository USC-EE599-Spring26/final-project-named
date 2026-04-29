//
//  RecoveryAdvisorService.swift
//  OCKSample
//
//  Created by Yulin on 4/20/26.
//

import Foundation

// ── Ollama API request / response structures ─────────────────

// Full request body sent to Ollama
private struct OllamaRequest: Codable {
    let model: String
    let stream: Bool
    let messages: [OllamaMessage]
}

// A single chat message (role = "user" or "assistant")
private struct OllamaMessage: Codable {
    let role: String
    let content: String
}

// Ollama response body — we only need the message field
private struct OllamaResponse: Codable {
    let message: OllamaMessage
}

// ── SLM input structures (match training data input format exactly) ──

// The "today" field
private struct SLMTodayInput: Codable {
    let voiceDiscomfort: Int
    let swallowingDiscomfort: Int
    let hydrationTaskStatus: String  // "completed" / "incomplete" / "missing"
    let walkingTaskStatus: String
    let stepCount: Int
    let restingHeartRate: Int
}

// Each day in the "history" array (same as today but includes postOpDay)
private struct SLMHistoryDayInput: Codable {
    let voiceDiscomfort: Int
    let swallowingDiscomfort: Int
    let hydrationTaskStatus: String
    let walkingTaskStatus: String
    let stepCount: Int
    let restingHeartRate: Int
    let postOpDay: Int
}

// Top-level SLM input object
private struct SLMInput: Codable {
    let postOpDay: Int
    let today: SLMTodayInput
    let history: [SLMHistoryDayInput]
}

// SLM output structure (matches training data output format exactly)
private struct SLMOutput: Codable {
    let trend: String
    let riskLevel: String
    let recommendedActions: [String]
}

// ── Main service class ────────────────────────────────────────

final class RecoveryAdvisorService {

    // Local Ollama server URL (accessible from iOS Simulator via localhost)
    private let ollamaURL = URL(string: "http://localhost:11434/api/chat")!

    // Model name must match what was used in `ollama create`
    private let modelName = "thyro-qwen3"

    // Main entry point: takes recent daily summaries, returns SLM analysis result
    // summaries[0] = today, summaries[1] = yesterday, summaries[2] = day before
    func analyze(summaries: [DailyRecoverySummary]) async throws -> RecoveryAdvisoryResult {

        // ── Trigger condition checks ──────────────────────────

        // Need at least 3 days of data
        guard summaries.count >= 3 else {
            throw AdvisorError.notEnoughDays
        }

        let todaySummary = summaries[0]

        // Today must have at least one task completed (hydration or walking)
        guard todaySummary.hydrationTaskStatus != .missing ||
              todaySummary.walkingTaskStatus != .missing else {
            throw AdvisorError.noTodayData
        }

        // At least 2 history days must have some task data
        let historyWithData = summaries.dropFirst().filter {
            $0.hydrationTaskStatus != .missing || $0.walkingTaskStatus != .missing
        }
        guard historyWithData.count >= 2 else {
            throw AdvisorError.notEnoughDays
        }

        // ── Build SLM input ───────────────────────────────────

        let todayInput = SLMTodayInput(
            voiceDiscomfort: todaySummary.voiceDiscomfort ?? 0,
            swallowingDiscomfort: todaySummary.swallowingDiscomfort ?? 0,
            hydrationTaskStatus: todaySummary.hydrationTaskStatus.rawValue,
            walkingTaskStatus: todaySummary.walkingTaskStatus.rawValue,
            stepCount: todaySummary.stepCount ?? 0,
            restingHeartRate: Int(todaySummary.restingHeartRate ?? 0)
        )

        // Convert all days except today into history format
        var historyInputs: [SLMHistoryDayInput] = []
        for summary in summaries.dropFirst() {
            let day = SLMHistoryDayInput(
                voiceDiscomfort: summary.voiceDiscomfort ?? 0,
                swallowingDiscomfort: summary.swallowingDiscomfort ?? 0,
                hydrationTaskStatus: summary.hydrationTaskStatus.rawValue,
                walkingTaskStatus: summary.walkingTaskStatus.rawValue,
                stepCount: summary.stepCount ?? 0,
                restingHeartRate: Int(summary.restingHeartRate ?? 0),
                postOpDay: summary.postOpDay
            )
            historyInputs.append(day)
        }

        let slmInput = SLMInput(
            postOpDay: todaySummary.postOpDay,
            today: todayInput,
            history: historyInputs
        )

        // ── Send HTTP request to Ollama ───────────────────────

        let encoder = JSONEncoder()

        // Encode slmInput as JSON string — this becomes the user message content
        let inputData = try encoder.encode(slmInput)
        let inputString = String(data: inputData, encoding: .utf8)!

        let ollamaRequest = OllamaRequest(
            model: modelName,
            stream: false,
            messages: [OllamaMessage(role: "user", content: inputString)]
        )

        var urlRequest = URLRequest(url: ollamaURL)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.httpBody = try encoder.encode(ollamaRequest)
        urlRequest.timeoutInterval = 120  // wait up to 2 minutes for inference

        let (data, _) = try await URLSession.shared.data(for: urlRequest)

        // ── Parse response ────────────────────────────────────

        // Decode Ollama's outer response wrapper to get message.content
        let ollamaResponse = try JSONDecoder().decode(OllamaResponse.self, from: data)

        // Trim whitespace/newlines before parsing, in case the model adds extra characters
        let contentString = ollamaResponse.message.content.trimmingCharacters(in: .whitespacesAndNewlines)

        // Parse the content string as JSON to get the SLM output
        guard let contentData = contentString.data(using: .utf8) else {
            throw AdvisorError.invalidResponse
        }
        let slmOutput = try JSONDecoder().decode(SLMOutput.self, from: contentData)

        return RecoveryAdvisoryResult(
            trend: slmOutput.trend,
            riskLevel: slmOutput.riskLevel,
            recommendedActions: slmOutput.recommendedActions
        )
    }
}

// ── Error types ───────────────────────────────────────────────

enum AdvisorError: LocalizedError {
    case notEnoughDays
    case tooEarly
    case noTodayData
    case invalidResponse

    var errorDescription: String? {
        switch self {
        case .notEnoughDays:  return "Need at least 3 days of data to generate advice."
        case .tooEarly:       return "AI advice is available from Day 3 onwards."
        case .noTodayData:    return "Please complete today's symptom check first."
        case .invalidResponse: return "Could not parse model response. Please try again."
        }
    }
}
