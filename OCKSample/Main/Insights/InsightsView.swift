//
//  InsightsView.swift
//  OCKSample
//
//  Created by Corey Baker on 4/17/25.
//  Copyright © 2025 Network Reconnaissance Lab. All rights reserved.
//

import CareKit
import CareKitEssentials
import CareKitStore
import CareKitUI
import SwiftUI
import Charts
// swiftlint:disable type_body_length
// swiftlint:disable cyclomatic_complexity

struct InsightsView: View {

    @CareStoreFetchRequest(query: query()) private var events
    @State var intervalSelected = 0 // Default to week since chart isn't working for others.
    @State var chartInterval = DateInterval()
    @State var period: PeriodComponent = .day
    @State var configurations: [CKEDataSeriesConfiguration] = []
    @State var sortedTaskIDs: [String: Int] = [:]
    @Environment(\.careStore) var store

    @State var swallowingDict: [String: Double] = [:]  // Swallowing
    @State var fatigueDict: [String: Double] = [:]     // Fatigue
    @State var tempDict: [String: Double] = [:]        // Temperature

    var body: some View {
        NavigationStack {
            dateIntervalSegmentView
                .padding()
            ScrollView {
                VStack {
                    // This is for loop is useful when you want a chart for
                    // for every task which may not always be the case.

                    Text("Symptoms Tracking")
                       .font(.title2)
                       .fontWeight(.semibold)
                       .frame(maxWidth: .infinity, alignment: .leading)
                       .padding(.horizontal)

                   // Swallowing
                   SingleScatterView(
                       title: "Difficulty Swallowing",
                       data: swallowingDict,
                       pointColor: .purple,
                       yAxisLabel: "Rate (0-10)"
                   )
                   .frame(height: 250)

                   // Fatigue
                   SingleScatterView(
                       title: "Fatigue",
                       data: fatigueDict,
                       pointColor: .orange,
                       yAxisLabel: "Rate (0-10)"
                   )
                   .frame(height: 250)

                   // Temp
                   SingleScatterView(
                       title: "Temperature",
                       data: tempDict,
                       pointColor: .red,
                       yAxisLabel: "Temperature (°C)"
                   )
                   .frame(height: 250)

                   Divider()
                       .padding(.vertical)

                    ForEach(orderedEvents) { event in
                        let eventResult = event.result
                        let dataStrategy = determineDataStrategy(for: eventResult.task.id)
                        if eventResult.task.id != TaskID.doxylamine
                            && eventResult.task.id != TaskID.nausea {

                            // dynamic gradient colors
                            let meanGradientStart = Color(TintColorFlipKey.defaultValue)
                            let meanGradientEnd = Color.accentColor

                            // Can add muliple plots on a single
                            // chart by adding multiple configurations.
                            let meanConfiguration = CKEDataSeriesConfiguration(
                                taskID: eventResult.task.id,
                                dataStrategy: dataStrategy,
                                mark: .bar,
                                legendTitle: String(localized: "AVERAGE"),
                                showMarkWhenHighlighted: true,
                                showMeanMark: false,
                                showMedianMark: false,
                                color: meanGradientEnd,
                                gradientStartColor: meanGradientStart
                            ) { event in
                                event.computeProgress(by: .maxOutcomeValue())
                            }

                            let sumConfiguration = CKEDataSeriesConfiguration(
                                taskID: eventResult.task.id,
                                dataStrategy: .sum,
                                mark: .bar,
                                legendTitle: String(localized: "TOTAL"),
                                color: Color(TintColorFlipKey.defaultValue) // Set to app color.
                            ) { event in
                                event.computeProgress(by: .maxOutcomeValue())
                            }

                            CareKitEssentialChartView(
                                title: eventResult.title,
                                subtitle: subtitle,
                                dateInterval: $chartInterval,
                                period: $period,
                                configurations: [
                                    meanConfiguration,
                                    sumConfiguration
                                ]
                            )

                        }
                        /*else if eventResult.task.id == TaskID.doxylamine {
                         // Example of showing nausea vs doxlymine
                         
                         // dynamic gradient colors
                         let nauseaGradientStart = Color(TintColorFlipKey.defaultValue)
                         let nauseaGradientEnd = Color.accentColor
                         
                         let nauseaConfiguration = CKEDataSeriesConfiguration(
                         taskID: TaskID.nausea,
                         dataStrategy: .sum,
                         mark: .bar,
                         legendTitle: String(localized: "NAUSEA"),
                         showMarkWhenHighlighted: true,
                         showMeanMark: true,
                         showMedianMark: false,
                         color: nauseaGradientEnd,
                         gradientStartColor: nauseaGradientStart,
                         stackingMethod: .unstacked
                         ) { event in
                         // This event occurs all-day and can be submitted
                         // multiple times, since we want to understand
                         // the "total" amount of times a patient experiences
                         // nausea, we sum the outcomes for each event.
                         event.computeProgress(by: .summingOutcomeValues())
                         }
                         
                         let doxylamineConfiguration = CKEDataSeriesConfiguration(
                         taskID: eventResult.task.id,
                         dataStrategy: .sum,
                         mark: .bar,
                         legendTitle: String(localized: "DOXYLAMINE"),
                         color: .gray,
                         gradientStartColor: .gray.opacity(0.3),
                         stackingMethod: .unstacked,
                         symbol: .diamond,
                         interpolation: .catmullRom
                         ) { event in
                         event.computeProgress(by: .averagingOutcomeValues())
                         }
                         
                         CareKitEssentialChartView(
                         title: String(localized: "NAUSEA_DOXYLAMINE_INTAKE"),
                         subtitle: subtitle,
                         dateInterval: $chartInterval,
                         period: $period,
                         configurations: [
                         nauseaConfiguration,
                         doxylamineConfiguration
                         ]
                         )
                         }*/
                    }
                }
                .padding()
            }
            .onAppear {
                let taskIDs = TaskID.orderedWatchOS + TaskID.orderedObjective
                print("taskIDs: \(taskIDs)")
                sortedTaskIDs = computeTaskIDOrder(taskIDs: taskIDs)
                events.query.taskIDs = taskIDs
                events.query.dateInterval = eventQueryInterval
                setupChartPropertiesForSegmentSelection(intervalSelected)
                fetchAndPrintResults(for: TaskID.symptomTracking)
            }
#if os(iOS)
            .onChange(of: intervalSelected) { _, intervalSegmentValue in
                setupChartPropertiesForSegmentSelection(intervalSegmentValue)
            }
#else
            .onChange(of: intervalSelected, initial: true) { _, newSegmentValue in
                setupChartPropertiesForSegmentSelection(newSegmentValue)
            }
#endif
        }
    }

    private var orderedEvents: [CareStoreFetchedResult<OCKAnyEvent>] {
        events.latest.sorted(by: { left, right in
            let leftTaskID = left.result.task.id
            let rightTaskID = right.result.task.id

            return sortedTaskIDs[leftTaskID] ?? 0 < sortedTaskIDs[rightTaskID] ?? 0
        })
    }

    private var dateIntervalSegmentView: some View {
        Picker(
            "CHOOSE_DATE_INTERVAL",
            selection: $intervalSelected.animation()
        ) {
            Text("TODAY")
                .tag(0)
            Text("WEEK")
                .tag(1)
            Text("MONTH")
                .tag(2)
            Text("YEAR")
                .tag(3)
        }
#if !os(watchOS)
        .pickerStyle(.segmented)
#else
        .pickerStyle(.automatic)
#endif
    }

    private var subtitle: String {
        switch intervalSelected {
        case 0:
            return String(localized: "TODAY")
        case 1:
            return String(localized: "WEEK")
        case 2:
            return String(localized: "MONTH")
        case 3:
            return String(localized: "YEAR")
        default:
            return String(localized: "WEEK")
        }
    }

    // Currently only look for events for the last.
    // We don't need to vary this because it's only
    // used to find taskID's. The chartInterval will
    // find all of the needed data for the chart.
    private var eventQueryInterval: DateInterval {
        let interval = Calendar.current.dateInterval(
            of: .weekOfYear,
            for: Date()
        )!
        return interval
    }

    private func determineDataStrategy(for taskID: String) -> CKEDataSeriesConfiguration.DataStrategy {
        switch taskID {
        case TaskID.ovulationTestResult, TaskID.steps:
            return .max
        default:
            return .mean
        }
    }

    private func setupChartPropertiesForSegmentSelection(_ segmentValue: Int) {
        let now = Date()
        let calendar = Calendar.current
        // This changes the interval of what will be
        // shown in the graph.
        switch segmentValue {
        case 0:
            let startOfDay = Calendar.current.startOfDay(
                for: now
            )
            let interval = DateInterval(
                start: startOfDay,
                end: now
            )

            period = .day
            chartInterval = interval

        case 1:
            let startDate = calendar.date(
                byAdding: .weekday,
                value: -7,
                to: now
            )!
            period = .week
            chartInterval = DateInterval(start: startDate, end: now)

        case 2:
            let startDate = calendar.date(
                byAdding: .month,
                value: -1,
                to: now
            )!
            period = .month
            chartInterval = DateInterval(start: startDate, end: now)

        case 3:
            let startDate = calendar.date(
                byAdding: .year,
                value: -1,
                to: now
            )!
            period = .month
            chartInterval = DateInterval(start: startDate, end: now)

        default:
            let startDate = calendar.date(
                byAdding: .weekday,
                value: -7,
                to: now
            )!
            period = .week
            chartInterval = DateInterval(start: startDate, end: now)

        }

    }

    private func computeTaskIDOrder(taskIDs: [String]) -> [String: Int] {
        // Tie index values to TaskIDs.
        let sortedTaskIDs = taskIDs.enumerated().reduce(into: [String: Int]()) { taskDictionary, task in
            taskDictionary[task.element] = task.offset
        }

        return sortedTaskIDs
    }

    static func query() -> OCKEventQuery {
        let query = OCKEventQuery(dateInterval: .init())
        return query
    }

    /*
     private func extractAnswer(from event: OCKAnyEvent, questionId: String) -> Double? {
     guard let outcome = event.outcome,
     let values = outcome.values as? [OCKOutcomeValue] else {
     return nil
     }
     
     for value in values {
     if value.kind == questionId {
     if let doubleValue = value.value as? Double {
     return doubleValue
     } else if let intValue = value.value as? Int {
     return Double(intValue)
     }
     }
     }
     return nil
     }*/

    private var symptomConfigurations: [CKEDataSeriesConfiguration] {
        let taskId = TaskID.symptomTracking

        // Futigue
        let fatigueConfig = CKEDataSeriesConfiguration(
            taskID: taskId,
            dataStrategy: .mean,
            mark: .bar,
            legendTitle: "Fatigue (0-10)",
            color: .orange,
            gradientStartColor: .orange.opacity(0.5)
        ) { event in
            event.computeProgress(by: .maxOutcomeValue(kind: "\(TaskID.symptomTracking)-temp"))
        }

        // sawllowing
        let swallowingConfig = CKEDataSeriesConfiguration(
            taskID: taskId,
            dataStrategy: .mean,
            mark: .bar,
            legendTitle: "Swallowing (0-10)",
            color: .purple,
            gradientStartColor: .purple.opacity(0.5)
        ) { event in
            event.computeProgress(by: .maxOutcomeValue(kind: "\(TaskID.symptomTracking)-swallowing"))
        }

        // Temp
        let tempConfig = CKEDataSeriesConfiguration(
            taskID: taskId,
            dataStrategy: .mean,
            mark: .line,
            legendTitle: "Temperature (°C)",
            color: .red,
            gradientStartColor: .red.opacity(0.5),
            symbol: .circle,
            interpolation: .catmullRom
        ) { event in
            event.computeProgress(by: .maxOutcomeValue(kind: "\(TaskID.symptomTracking)-temp"))
        }

        return [fatigueConfig, swallowingConfig, tempConfig]
    }

    private func fetchAndPrintResults(for taskId: String) {
        var query = OCKOutcomeQuery()
        query.taskIDs = [taskId]

        store.fetchAnyOutcomes(query: query, callbackQueue: .main) { [self] result in
            switch result {
            case .success(let outcomes):

                var swallowingDictPmP: [String: Double] = [:]  // Difficulty Swallowing
                var fatigueDictPmP: [String: Double] = [:]     // Fatigue
                var tempDictPmP: [String: Double] = [:]        // Temp

                let dateFormatter = DateFormatter()
                dateFormatter.dateFormat = "yyyy-MM-dd"

                print("========== Survey Results ==========")

                for outcome in outcomes {
                    // Get dates
                    let outcome1 = outcome as? OCKOutcome
                    var dateKey = ""
                    if let createdDate = outcome1?.effectiveDate {
                        let formatter = DateFormatter()
                        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
                        print("Complete date: \(formatter.string(from: createdDate))")
                        dateKey = dateFormatter.string(from: createdDate)
                    }

                    // Print All Answers
                    for value in outcome.values {
                        if let kind = value.kind {
                            print("Question: \(kind), Answer: \(value.value)")

                            // Get Value
                            let numericValue: Double?
                            if let doubleValue = value.value as? Double {
                                numericValue = doubleValue
                            } else if let intValue = value.value as? Int {
                                numericValue = Double(intValue)
                            } else if let stringValue = value.value as? String,
                                      let doubleFromString = Double(stringValue) {
                                numericValue = doubleFromString
                            } else {
                                numericValue = nil
                            }

                            guard let finalValue = numericValue else { continue }

                            switch kind {
                            case "\(TaskID.symptomTracking)-swallowing":
                                swallowingDictPmP[dateKey] = finalValue
                            case "\(TaskID.symptomTracking)-fatigue":
                                fatigueDictPmP[dateKey] = finalValue
                            case "\(TaskID.symptomTracking)-temp":
                                tempDictPmP[dateKey] = finalValue
                            default:
                                break
                            }
                        } else {
                            print("Answer: \(value.value)")
                        }
                    }
                    print("---")
                }

                Task {@MainActor in
                    self.swallowingDict = swallowingDictPmP
                    self.fatigueDict = fatigueDictPmP
                    self.tempDict = tempDictPmP
                    print("========== Difficulty Swallowing Data ==========")
                    print(swallowingDict)
                    print("========== Fatigue Data ==========")
                    print(fatigueDict)
                    print("========== Temp Data ==========")
                    print(tempDict)
                }
            case .failure(let error):
                print("Read Failed: \(error)")
            }
        }
    }

}

struct SingleScatterView: View {
    let title: String
    let data: [String: Double]
    let pointColor: Color
    let yAxisLabel: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
                .padding(.leading)

            if data.isEmpty {
                ContentUnavailableView(
                    "No Data",
                    systemImage: "chart.xyaxis.line",
                    description: Text("Please Check again after finished Survey")
                )
                .frame(height: 200)
            } else {
                Chart {
                    ForEach(lastSevenDays(), id: \.self) { date in
                        let value = data[dateFormatter.string(from: date)]

                        if let value = value {

                            PointMark(
                                x: .value("Date", date),
                                y: .value(title, value)
                            )
                            .foregroundStyle(pointColor)
                            .symbolSize(120)
                        } else {
                            // If no data
                            PointMark(
                                x: .value("Date", date),
                                y: .value(title, Double.nan)
                            )
                            .opacity(0)
                        }
                    }
                }
                .chartXAxisLabel("Date")
                .chartYAxisLabel(yAxisLabel)
                .frame(height: 200)
            }
        }
        .padding()
        .cornerRadius(12)
        .shadow(radius: 1)
    }

    private func lastSevenDays() -> [Date] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        return (0...6).map { dayOffset in
            calendar.date(byAdding: .day, value: -dayOffset, to: today)!
        }.reversed()
    }

    private var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }
}

#Preview {
    InsightsView()
		.environment(\.careStore, Utility.createPreviewStore())
		.careKitStyle(Styler())
}
