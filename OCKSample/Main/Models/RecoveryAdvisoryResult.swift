//
//  RecoveryAdvisoryResult.swift
//  OCKSample
//
//  Created by Yulin on 4/20/26.
//

import Foundation

// The result returned by the SLM, matches training data output format exactly
struct RecoveryAdvisoryResult {
    let trend: String                // "improving" / "stable" / "worsening"
    let riskLevel: String            // "low" / "medium" / "high"
    let recommendedActions: [String] // e.g. ["contactDoctor", "recommendVoiceRest"]
}

extension RecoveryAdvisoryResult {

    // Convert trend code to a display string with direction indicator
    var trendDisplayText: String {
        switch trend {
        case "improving": return "Improving ↑"
        case "stable":    return "Stable →"
        case "worsening": return "Worsening ↓"
        default:          return trend
        }
    }

    // Convert action code to a human-readable sentence
    static func actionDisplayText(_ action: String) -> String {
        let lookup: [String: String] = [
            "contactDoctor": "Contact your doctor",
            "continueCurrentPlan": "Continue current plan",
            "increaseSymptomCheck": "Monitor symptoms more frequently",
            "recommendVoiceRest": "Rest your voice",
            "recommendSoftDiet": "Eat soft foods",
            "reviewPainManagement": "Review pain management",
            "monitorHeartRate": "Monitor your heart rate",
            "encourageDeepBreathing": "Practice deep breathing",
            "encourageWalking": "Increase walking activity",
            "increaseHydrationReminder": "Drink more water",
            "increaseRestReminder": "Get more rest",
            "scheduleFollowUp": "Schedule a follow-up appointment",
            "reduceActivity": "Reduce physical activity"
        ]
        return lookup[action] ?? action
    }
}
