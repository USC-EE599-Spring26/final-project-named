//
//  AdvisoryView.swift
//  OCKSample
//
//  Created by Yulin on 4/20/26.
//

#if !os(watchOS)
import SwiftUI

struct AdvisoryView: View {

    // SLM analysis result, nil means not yet fetched
    @State private var result: RecoveryAdvisoryResult?

    // True while waiting for the SLM to respond
    @State private var isLoading = false

    // User-facing message for errors or insufficient data
    @State private var message: String?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {

                    // ── Loading state ─────────────────────────
                    if isLoading {
                        VStack(spacing: 12) {
                            ProgressView()
                                .scaleEffect(1.4)
                            Text("Analyzing your recovery...")
                                .foregroundColor(.secondary)
                        }
                        .padding(.top, 80)
                    }

                    // ── Info / error message ──────────────────
                    if let msg = message, !isLoading {
                        VStack(spacing: 10) {
                            Image(systemName: "info.circle.fill")
                                .font(.system(size: 40))
                                .foregroundColor(.secondary)
                            Text(msg)
                                .multilineTextAlignment(.center)
                                .foregroundColor(.secondary)
                                .padding(.horizontal)
                        }
                        .padding(.top, 80)
                    }

                    // ── Result card ───────────────────────────
                    if let result = result, !isLoading {
                        resultCard(result: result)
                    }

                    // ── Refresh button ────────────────────────
                    if !isLoading {
                        Button {
                            Task { await fetchAdvice() }
                        } label: {
                            Label("Refresh Analysis", systemImage: "arrow.clockwise")
                                .padding(.horizontal, 28)
                                .padding(.vertical, 12)
                                .background(Color.accentColor)
                                .foregroundColor(.white)
                                .cornerRadius(12)
                        }
                        .padding(.top, 4)
                    }
                }
                .padding()
            }
            .navigationTitle("AI Recovery Advice")
        }
        // Auto-trigger analysis when the tab is first opened
        .task {
            await fetchAdvice()
        }
    }

    // ── Result card ───────────────────────────────────────────

    @ViewBuilder
    private func resultCard(result: RecoveryAdvisoryResult) -> some View {
        VStack(alignment: .leading, spacing: 16) {

            // Trend row
            HStack {
                Text("Recovery Trend")
                    .fontWeight(.semibold)
                Spacer()
                Text(result.trendDisplayText)
                    .fontWeight(.bold)
                    .foregroundColor(trendColor(result.trend))
            }

            Divider()

            // Risk level row
            HStack {
                Text("Risk Level")
                    .fontWeight(.semibold)
                Spacer()
                HStack(spacing: 6) {
                    Circle()
                        .fill(riskColor(result.riskLevel))
                        .frame(width: 10, height: 10)
                    Text(result.riskLevel.capitalized)
                        .fontWeight(.bold)
                        .foregroundColor(riskColor(result.riskLevel))
                }
            }

            Divider()

            // Recommendations list
            Text("Recommendations")
                .fontWeight(.semibold)

            ForEach(result.recommendedActions, id: \.self) { action in
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.accentColor)
                        .padding(.top, 2)
                    Text(RecoveryAdvisoryResult.actionDisplayText(action))
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .padding(20)
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.08), radius: 8, x: 0, y: 2)
    }

    // ── Color helpers ─────────────────────────────────────────

    private func trendColor(_ trend: String) -> Color {
        switch trend {
        case "improving": return .green
        case "stable":    return .orange
        case "worsening": return .red
        default:          return .primary
        }
    }

    private func riskColor(_ level: String) -> Color {
        switch level {
        case "low":    return .green
        case "medium": return .orange
        case "high":   return .red
        default:       return .primary
        }
    }

    // ── Core logic: fetch summaries → call SLM ────────────────

    @MainActor
    private func fetchAdvice() async {
        isLoading = true
        result = nil
        message = nil

        do {
            // Create inside @MainActor function to satisfy Swift 6 concurrency rules
            let builder = RecoverySummaryBuilder()
            let service = RecoveryAdvisorService()

            // Fetch the last 3 days of recovery summaries (today + 2 previous days)
            let summaries = try await builder.buildRecentSummaries(windowDays: 3)

            // Run SLM analysis
            let advisory = try await service.analyze(summaries: summaries)

            result = advisory
        } catch {
            message = error.localizedDescription
        }

        isLoading = false
    }
}

struct AdvisoryView_Previews: PreviewProvider {
    static var previews: some View {
        AdvisoryView()
            .environment(\.appDelegate, AppDelegate())
            .environment(\.careStore, Utility.createPreviewStore())
    }
}
#endif
