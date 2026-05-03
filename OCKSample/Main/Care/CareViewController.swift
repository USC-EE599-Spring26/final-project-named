/*
 Copyright (c) 2019, Apple Inc. All rights reserved.
 
 Redistribution and use in source and binary forms, with or without modification,
 are permitted provided that the following conditions are met:
 
 1.  Redistributions of source code must retain the above copyright notice, this
 list of conditions and the following disclaimer.
 
 2.  Redistributions in binary form must reproduce the above copyright notice,
 this list of conditions and the following disclaimer in the documentation and/or
 other materials provided with the distribution.
 
 3. Neither the name of the copyright holder(s) nor the names of any contributors
 may be used to endorse or promote products derived from this software without
 specific prior written permission. No license is granted to the trademarks of
 the copyright holders even if such marks are included in this software.
 
 THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
 AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
 IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
 ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE
 FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
 DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
 SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER
 CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY,
 OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
 OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

import CareKit
import CareKitEssentials
import CareKitStore
import CareKitUI
import os.log
import ResearchKitSwiftUI
import SwiftUI
import UIKit
#if os(iOS)
@preconcurrency import ResearchKit
@preconcurrency import ResearchKitActiveTask
#endif
// swiftlint:disable type_body_length
@MainActor
final class CareViewController: OCKDailyPageViewController, @unchecked Sendable {

    private var isSyncing = false
    private var isLoading = false
    private let swiftUIPadding: CGFloat = 15
    private var style: Styler { CustomStylerKey.defaultValue }

    override func viewDidLoad() {
        super.viewDidLoad()
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            barButtonSystemItem: .refresh,
            target: self,
            action: #selector(synchronizeWithRemote)
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(synchronizeWithRemote),
            name: Notification.Name(
                rawValue: Constants.requestSync
            ),
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(updateSynchronizationProgress(_:)),
            name: Notification.Name(rawValue: Constants.progressUpdate),
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(reloadView(_:)),
            name: Notification.Name(rawValue: Constants.finishedAskingForPermission),
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(reloadView(_:)),
            name: Notification.Name(rawValue: Constants.shouldRefreshView),
            object: nil
        )
    }

    @objc private func updateSynchronizationProgress(
        _ notification: Notification
    ) {
        guard let receivedInfo = notification.userInfo as? [String: Any],
            let progress = receivedInfo[Constants.progressUpdate] as? Int else {
            return
        }

        switch progress {
        case 100:
            self.navigationItem.rightBarButtonItem = UIBarButtonItem(
                title: "\(progress)",
                style: .plain, target: self,
                action: #selector(self.synchronizeWithRemote)
            )
            self.navigationItem.rightBarButtonItem?.tintColor = self.view.tintColor

            // Give sometime for the user to see 100
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                guard let self else { return }
                self.navigationItem.rightBarButtonItem = UIBarButtonItem(
                    barButtonSystemItem: .refresh,
                    target: self,
                    action: #selector(self.synchronizeWithRemote)
                )
                self.navigationItem.rightBarButtonItem?.tintColor = self.navigationItem.leftBarButtonItem?.tintColor
            }
        default:
            self.navigationItem.rightBarButtonItem = UIBarButtonItem(
                title: "\(progress)",
                style: .plain, target: self,
                action: #selector(self.synchronizeWithRemote)
            )
            self.navigationItem.rightBarButtonItem?.tintColor = self.view.tintColor
        }
    }

    @objc private func synchronizeWithRemote() {
        guard !isSyncing else { return }
        isSyncing = true
        AppDelegateKey.defaultValue?.store.synchronize { error in
            let errorString = error?.localizedDescription ?? "Successful sync with remote!"
            Logger.feed.info("\(errorString)")
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                if error != nil {
                    self.navigationItem.rightBarButtonItem?.tintColor = .red
                } else {
                    self.navigationItem.rightBarButtonItem?.tintColor = self.navigationItem.leftBarButtonItem?.tintColor
                }
                self.isSyncing = false
            }
        }
    }

    @objc private func reloadView(_ notification: Notification? = nil) {
        guard !isLoading else { return }
        reload()
    }

    /*
     This will be called each time the selected date changes.
     Use this as an opportunity to rebuild the content shown to the user.
     */
    override func dailyPageViewController(
        _ dailyPageViewController: OCKDailyPageViewController,
        prepare listViewController: OCKListViewController,
        for date: Date
    ) {
        self.isLoading = true

        // Always call this method to ensure dates for
        // queries are correct.
        let date = modifyDateIfNeeded(date)
        let isCurrentDay = isSameDay(as: date)

        Task {
            let onboardingPending = await isOnboardingPending(on: date)

            #if os(iOS)
            if !onboardingPending {
                appendRecoveryTipIfNeeded(
                    for: date,
                    isCurrentDay: isCurrentDay,
                    to: listViewController
                )
            }
            #endif

            await fetchAndDisplayTasks(
                on: listViewController,
                for: date,
                onboardingPending: onboardingPending
            )
        }
    }

    private func isSameDay(as date: Date) -> Bool { Calendar.current.isDate(date, inSameDayAs: Date()) }

    private func modifyDateIfNeeded(_ date: Date) -> Date {
        guard date < .now else {
            return date
        }
        guard !isSameDay(as: date) else {
            return .now
        }
        return date.endOfDay
    }

    private func fetchAndDisplayTasks(
        on listViewController: OCKListViewController,
        for date: Date,
        onboardingPending: Bool
    ) async {
        let tasks = await self.fetchTasks(
            on: date,
            onboardingPending: onboardingPending
        )
        appendTasks(tasks, to: listViewController, date: date)
    }

    private func isOnboardingPending(on date: Date) async -> Bool {
        var query = OCKTaskQuery(for: date)
        query.ids = [TaskID.onboard]
        query.excludesTasksWithNoEvents = true

        do {
            let tasks = try await store.fetchAnyTasks(query: query)
            return !tasks.isEmpty
        } catch {
            Logger.feed.error("Could not determine onboarding state: \(error, privacy: .public)")
            return false
        }
    }

    private func fetchTasks(
        on date: Date,
        onboardingPending: Bool
    ) async -> [any OCKAnyTask] {
        var query = OCKTaskQuery(for: date)
        query.excludesTasksWithNoEvents = true
        do {
            let tasks = try await store.fetchAnyTasks(query: query)

            if onboardingPending {
                guard isSameDay(as: date) else {
                    return []
                }
                return tasks.filter { $0.id == TaskID.onboard }
            }

            /*let orderedTasks = TaskID.ordered.compactMap { orderedTaskID in
                tasks.first(where: { $0.id == orderedTaskID })
            }
            let knownTaskIDs = Set(orderedTasks.map { $0.id })
            let customTasks = tasks.filter { !knownTaskIDs.contains($0.id) }
            return orderedTasks + customTasks*/
            guard let tasksWithPriority = tasks as? [CareTask] else {
                Logger.feed.warning("Could not cast all tasks to \"CareTask\"")
                return tasks
            }
            let orderedPriorityTasks = tasksWithPriority.sortedByPriority()
            let orderedTasks = orderedPriorityTasks.compactMap { orderedPriorityTask in
                tasks.first(where: { $0.id == orderedPriorityTask.id })
            }
            return orderedTasks
            // return tasks
        } catch {
            Logger.feed.error("Could not fetch tasks: \(error, privacy: .public)")
            return []
        }
    }
    #if os(iOS)
    @objc private func handleKneeModelTap() {
        presentThyroidModel()
        fetchAndPrintResults(for: TaskID.symptomTracking)
        fetchAllOutcomes()
        fetchAndPrintResult(for: TaskID.symptomTracking)
    }
    #endif
    // swiftlint:disable:next cyclomatic_complexity
    private func taskViewControllers(
        _ task: any OCKAnyTask,
        on date: Date
    ) -> [UIViewController]? {

        var query = OCKEventQuery(for: date)
        query.taskIDs = [task.id]

        if let standardTask = task as? OCKTask {

                    switch standardTask.card {

                    case .button:
                        #if os(iOS)
                        // This is a UIKit based card.
                        let card = OCKButtonLogTaskViewController(
                            query: query,
                            store: self.store
                        )
                        #else
                        let card = EventQueryView<SimpleTaskView>(
                            query: query
                        )
                        .padding(.vertical, swiftUIPadding)
                        .formattedHostingController()
                        #endif
                        return [card]

                    case .checklist:
                        #if os(iOS)
                        // This is a UIKit based card.
                        let card = OCKChecklistTaskViewController(
                            query: query,
                            store: self.store
                        )
                        #else
                        let card = EventQueryView<SimpleTaskView>(
                            query: query
                        )
                        .padding(.vertical, swiftUIPadding)
                        .formattedHostingController()
                        #endif
                        return [card]

                    case .featured:
                        #if os(iOS)
                        let card = featuredTaskViewController(for: standardTask)
                        #else
                        let card = EventQueryView<SimpleTaskView>(
                            query: query
                        )
                        .padding(.vertical, swiftUIPadding)
                        .formattedHostingController()
                        #endif
                        return [card]

                    case .grid:
                        #if os(iOS)
                        let card = OCKGridTaskViewController(
                            query: query,
                            store: self.store
                        )
                        #else
                        let card = EventQueryView<SimpleTaskView>(
                            query: query
                        )
                        .padding(.vertical, swiftUIPadding)
                        .formattedHostingController()
                        #endif
                        return [card]

                    case .instruction:
                        let card = EventQueryView<InstructionsTaskView>(
                            query: query
                        )
                        .padding(.vertical, swiftUIPadding)
                        .formattedHostingController()

                        return [card]

                    case .link:
                        #if os(iOS)
                        let card = linkTaskViewController(for: standardTask)
                        #else
                        let card = EventQueryView<SimpleTaskView>(
                            query: query
                        )
                        .padding(.vertical, swiftUIPadding)
                        .formattedHostingController()
                        #endif
                        return [card]

                    case .simple:

                        let card = EventQueryView<SimpleTaskView>(
                            query: query
                        )
                        .padding(.vertical, swiftUIPadding)
                        .formattedHostingController()

                        return [card]

                    case .survey:
                                    guard let card = researchSurveyViewController(
                                        query: query,
                                        task: standardTask
                                    ) else {
                                        Logger.feed.warning(
                                            "Unable to create research survey view controller"
                                        )
                                        return nil
                                    }

                                    return [card]

                    case .custom:
                        let shouldEnableInteraction = isSameDay(as: date)
                        if standardTask.id == TaskID.onboard {
                            let card = EventQueryView<OnboardTaskView>(
                                query: query
                            )
                            .cardEnabled(shouldEnableInteraction)
                            .padding(.vertical, swiftUIPadding)
                            .formattedHostingController()

                            return [card]
                        } else if standardTask.id == TaskID.rangeOfMotion {
                            let card = EventQueryView<RangeOfMotionTaskView>(
                                query: query
                            )
                            .cardEnabled(shouldEnableInteraction)
                            .padding(.vertical, swiftUIPadding)
                            .formattedHostingController()

                            return [card]
                        } else if standardTask.id == TaskID.neckMobility {
                            let card = EventQueryView<NeckMobilityTaskView>(
                                query: query
                            )
                            .cardEnabled(shouldEnableInteraction)
                            .padding(.vertical, swiftUIPadding)
                            .formattedHostingController()

                            return [card]
                        } else if standardTask.id == TaskID.comfortScore {
                            let card = EventQueryView<ComfortScoreCardView>(
                                query: query
                            )
                            .cardEnabled(shouldEnableInteraction)
                            .padding(.vertical, swiftUIPadding)
                            .formattedHostingController()

                            return [card]
                        } else {
                            let card = EventQueryView<MyCustomCardView>(
                                query: query
                            )
                            .cardEnabled(shouldEnableInteraction)
                            .padding(.vertical, swiftUIPadding)
                            .formattedHostingController()

                            return [card]
                        }
                    #if os(iOS)
                    case .thyroidModel:

                        let card = OCKSimpleTaskViewController(
                                query: query,
                                store: self.store
                            )

                        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(handleKneeModelTap))
                        card.view.addGestureRecognizer(tapGesture)
                        card.view.isUserInteractionEnabled = true

                        return [card]
                        #endif

                    default:
                        return nil
                    }

                } else if let healthTask = task as? OCKHealthKitTask {
                    switch healthTask.card {

                    case .labeledValue:
                        let card = EventQueryView<LabeledValueTaskView>(
                            query: query
                        )
                        .padding(.vertical, swiftUIPadding)
                        .formattedHostingController()
                        return [card]

                    case .numericProgress:
                        let card = EventQueryView<NumericProgressTaskView>(
                            query: query
                        )
                        .padding(.vertical, swiftUIPadding)
                        .formattedHostingController()

                        return [card]
                    default:
                        return nil
                    }
                } else {
                    return nil
                }

    }
    /*
    private func researchSurveyViewController(
            query: OCKEventQuery,
            task: OCKTask
        ) -> UIViewController? {

            guard let steps = task.surveySteps else {
                return nil
            }

            let surveyViewController = EventQueryContentView<ResearchSurveyView>(
                query: query
            ) {
                EventQueryContentView<ResearchCareForm>(
                    query: query
                ) {
                    ForEach(steps) { step in
                        ResearchFormStep(
                            title: task.title,
                            subtitle: task.instructions
                        ) {
                            ForEach(step.questions) { question in
                                question.view()
                            }
                        }
                    }
                }
            }
            .padding(.vertical, swiftUIPadding)
            .formattedHostingController()

            return surveyViewController
        }*/

    private func fetchAndPrintResults(for taskId: String) {
        var query = OCKOutcomeQuery()
        query.taskIDs = [taskId]

        store.fetchAnyOutcomes(query: query, callbackQueue: .main) { result in
            switch result {
            case .success(let outcomes):
                print("========== Survey Results ==========")
                for outcome in outcomes {
                    for value in outcome.values {
                        print("Answer: \(value.value)")
                    }
                }
                print("==============================")
            case .failure(let error):
                print("Read Failed: \(error)")
            }
        }
    }

    private func researchSurveyViewController(
            query: OCKEventQuery,
            task: OCKTask
        ) -> UIViewController? {

            guard let steps = task.surveySteps else {
                return nil
            }

            let surveyViewController = SurveyCardWithAnswersView(
                query: query,
                taskTitle: task.title ?? "Survey",
                taskInstructions: task.instructions,
                steps: steps
            )
            .padding(.vertical, swiftUIPadding)
            .formattedHostingController()

            return surveyViewController
        }

    private func fetchAndPrintResult(for taskId: String) {
        let query = OCKOutcomeQuery()
        // query.taskIDs = [taskId]

        store.fetchAnyOutcomes(query: query, callbackQueue: .main) { result in
            switch result {
            case .success(let outcomes):
                for outcome in outcomes {
                    for value in outcome.values {

                        if let kind = value.kind {
                            print("Question: \(kind), Answer: \(value.value)")
                        } else {
                            print("Answer: \(value.value)")
                        }
                    }
                }
            case .failure(let error):
                print("Read Failed: \(error)")
            }
        }
    }
    #if os(iOS)
    private func fetchAllOutcomes() {
        let query = OCKOutcomeQuery()
        store.fetchAnyOutcomes(query: query, callbackQueue: .main) { result in
            Task { @MainActor in
                switch result {
                case .success(let outcomes):
                    print("Total \(outcomes.count) results")
                    for outcome in outcomes {
                        let taskUUID = outcome.taskUUID
                        var taskQuery = OCKTaskQuery()
                        taskQuery.uuids = [taskUUID]
                        self.store.fetchAnyTasks(query: taskQuery, callbackQueue: .main) { taskResult in
                            switch taskResult {
                            case .success(let tasks):
                                let taskId = tasks.first?.id ?? "unknown"
                                print("Task ID: \(taskId)")
                            case .failure:
                                print("Task ID: Failed")
                            }
                        }

                        print("values: \(outcome.values)")
                        print("---")
                    }
                case .failure(let error):
                    print("Failed: \(error)")
                }
            }
        }
    }
    #endif
    private func appendTasks(
        _ tasks: [any OCKAnyTask],
        to listViewController: OCKListViewController,
        date: Date
    ) {
        let isCurrentDay = isSameDay(as: date)
        tasks.compactMap {
            let isLinkCardTask = ($0 as? OCKTask)?.card == .link
            let shouldEnableInteraction = isCurrentDay || isLinkCardTask

            let cards = self.taskViewControllers(
                $0,
                on: date
            )
            cards?.forEach {
                if let carekitView = $0.view as? OCKView {
                    carekitView.customStyle = style
                }
                $0.view.isUserInteractionEnabled = shouldEnableInteraction
                $0.view.alpha = shouldEnableInteraction ? 1.0 : 0.4
            }
            return cards
        }.forEach { (cards: [UIViewController]) in
            cards.forEach {
                let card = $0
                listViewController.appendViewController(card, animated: true)
            }
        }
        self.isLoading = false
    }
    #if os(iOS)
    /// Create Thyroid 3D Model Visualization Task
    func createThyroidModelTask() -> ORKTask {
        let instructionStep = ORKInstructionStep(identifier: "thyroid.instruction")
        instructionStep.title = "Your Thyroid Post-Op Anatomy"
        instructionStep.detailText = "A 3D model will be presented to help you understand"
        instructionStep.iconImage = UIImage(systemName: "waveform.path.ecg")

        // Replace "thyroid_model" with your actual USDZ model file name
        let modelLoc: String = "Thyroid"
        let modelManager = ORKUSDZModelManager(usdzFileName: modelLoc)
        let modelStep = ORK3DModelStep(identifier: "thyroid.model", modelManager: modelManager)

        return ORKOrderedTask(identifier: "thyroid.visualization", steps: [instructionStep, modelStep])
    }

    /// Present Thyroid 3D Model
    func presentThyroidModel() {
        let task = createThyroidModelTask()
        let taskViewController = ORKTaskViewController(task: task, taskRun: nil)
        taskViewController.delegate = self
        present(taskViewController, animated: true)
    }
    #endif

}

private struct SurveyCardWithAnswersView: View {
    @CareStoreFetchRequest private var events: CareStoreFetchedResults<OCKAnyEvent, OCKEventQuery>
    @State private var isPresentingAnswers = false

    let query: OCKEventQuery
    let taskTitle: String
    let taskInstructions: String?
    let steps: [SurveyStep]

    init(
        query: OCKEventQuery,
        taskTitle: String,
        taskInstructions: String?,
        steps: [SurveyStep]
    ) {
        self.query = query
        self.taskTitle = taskTitle
        self.taskInstructions = taskInstructions
        self.steps = steps
        _events = CareStoreFetchRequest(query: query)
    }

    var body: some View {
        if let event = events.latest.first?.result, event.isComplete {
            CompletedSurveyCardView(
                event: event,
                isPresentingAnswers: $isPresentingAnswers
            )
            .sheet(isPresented: $isPresentingAnswers) {
                NavigationStack {
                    ScrollView {
                        SurveyAnswerSummaryView(
                            event: event,
                            questions: steps.flatMap(\.questions),
                            showsEmptyState: true
                        )
                        .padding()
                    }
                    .navigationTitle("Survey Answers")
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Done") {
                                isPresentingAnswers = false
                            }
                        }
                    }
                }
            }
        } else {
            EventQueryContentView<ResearchSurveyView>(
                query: query
            ) {
                EventQueryContentView<ResearchCareForm>(
                    query: query
                ) {
                    ForEach(steps) { step in
                        ResearchFormStep(
                            title: taskTitle,
                            subtitle: taskInstructions
                        ) {
                            ForEach(step.questions) { question in
                                question.view()
                            }
                        }
                    }
                }
            }
        }
    }
}

private struct CompletedSurveyCardView: View {
    let event: OCKAnyEvent
    @Binding var isPresentingAnswers: Bool

    var body: some View {
        CardView {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(event.title)
                            .font(.headline)
                        Text(scheduleText)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(.secondary)
                }

                Divider()

                HStack(spacing: 10) {
                    Text("Completed")
                        .font(.headline)
                        .foregroundColor(Color(red: 0.70, green: 0.18, blue: 0.20))
                        .frame(maxWidth: .infinity, minHeight: 48)
                        .background(Color.secondary.opacity(0.10))
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

                    Button {
                        isPresentingAnswers = true
                    } label: {
                        Label("Survey Answers", systemImage: "list.bullet.clipboard")
                            .font(.headline)
                            .frame(maxWidth: .infinity, minHeight: 48)
                    }
                    .background(Color.accentColor.opacity(0.14))
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
            }
            .padding()
        }
    }

    private var scheduleText: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm"
        let start = formatter.string(from: event.scheduleEvent.start)
        let end = formatter.string(from: event.scheduleEvent.end)
        return "\(start) to \(end)"
    }
}

private struct SurveyAnswerSummaryView: View {
    let event: OCKAnyEvent
    let questions: [SurveyQuestion]
    var showsEmptyState = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Survey Answers", systemImage: "list.bullet.clipboard")
                .font(.headline)

            if answerRows.isEmpty, showsEmptyState {
                Text("Complete the survey to see your answers here.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            } else if !answerRows.isEmpty {
                ForEach(answerRows) { row in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(row.question)
                            .font(.caption.weight(.semibold))
                            .foregroundColor(.secondary)
                        Text(row.answer)
                            .font(.subheadline)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(10)
                    .background(Color.secondary.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
            }
        }
        .padding(14)
        .background(Color.accentColor.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private var answerRows: [SurveyAnswerRow] {
        guard let values = event.outcome?.values else {
            return []
        }

        return values.enumerated().compactMap { index, value in
            let answer = formattedAnswer(for: value)
            guard !answer.isEmpty else {
                return nil
            }

            let question = questionTitle(for: value.kind) ?? "Answer"
            return SurveyAnswerRow(
                id: "\(value.kind ?? "answer")-\(index)",
                question: question,
                answer: answer
            )
        }
    }

    private func questionTitle(for kind: String?) -> String? {
        guard let kind else {
            return nil
        }
        return questions.first { $0.id == kind }?.title
    }

    private func formattedAnswer(for value: OCKOutcomeValue) -> String {
        if let string = value.value as? String {
            return string
        }
        if let bool = value.value as? Bool {
            return bool ? "Yes" : "No"
        }
        if let int = value.integerValue {
            return String(int)
        }
        if let double = value.doubleValue {
            return formattedNumber(double)
        }
        if let date = value.value as? Date {
            return DateFormatter.localizedString(
                from: date,
                dateStyle: .medium,
                timeStyle: .short
            )
        }
        if let data = value.value as? Data {
            return "\(data.count) bytes"
        }
        return String(describing: value.value)
    }

    private func formattedNumber(_ value: Double) -> String {
        let rounded = value.rounded()
        if abs(value - rounded) < 0.001 {
            return String(Int(rounded))
        }
        return String(format: "%.1f", value)
    }
}

private struct SurveyAnswerRow: Identifiable {
    let id: String
    let question: String
    let answer: String
}

@MainActor private func customTaskViewControllers(
    for task: any OCKAnyTask,
    query: OCKEventQuery,
    store: OCKAnyStoreProtocol
) -> [UIViewController] {
    var selectedCard = CareKitCard.simple
    var savedTask: OCKTask?// in order to access the asset for the featured card

    if let regularTask = task as? OCKTask {
        selectedCard = regularTask.card
        savedTask = regularTask
    }

    if selectedCard == .button {
        #if os(iOS)
        let card = OCKButtonLogTaskViewController(
            query: query,
            store: store
        )
        return [card]
        #else
        let card = EventQueryView<SimpleTaskView>(
            query: query
        )
        .formattedHostingController()
        return [card]
        #endif
    }

    if selectedCard == .checklist {
        #if os(iOS)
        let card = OCKChecklistTaskViewController(
            query: query,
            store: store
        )
        return [card]
        #else
        let card = EventQueryView<SimpleTaskView>(
            query: query
        )
        .formattedHostingController()
        return [card]
        #endif
    }

    if selectedCard == .grid {
        #if os(iOS)
        let card = OCKGridTaskViewController(
            query: query,
            store: store
        )
        return [card]
        #else
        let card = EventQueryView<SimpleTaskView>(
            query: query
        )
        .formattedHostingController()
        return [card]
        #endif
    }

    if selectedCard == .instruction {
        #if os(iOS)
        let card = OCKInstructionsTaskViewController(
            query: query,
            store: store
        )

        return [card]
        #else
        let card = EventQueryView<InstructionsTaskView>(
            query: query
        )
        .formattedHostingController()
        return [card]
        #endif
    }

    if selectedCard == .featured {
        #if os(iOS)
        let card = featuredTaskViewController(for: savedTask)
        return [card]
        #else
        let card = EventQueryView<SimpleTaskView>(
            query: query
        )
        .formattedHostingController()
        return [card]
        #endif
    }

    if selectedCard == .link {
        #if os(iOS)
        let card = linkTaskViewController(for: savedTask)
        return [card]
        #else
        let card = EventQueryView<SimpleTaskView>(
            query: query
        )
        .formattedHostingController()
        return [card]
        #endif
    }

    #if os(iOS)
    let card = OCKSimpleTaskViewController(
        query: query,
        store: store
    )
    return [card]
    #else
    let card = EventQueryView<SimpleTaskView>(
        query: query
    )
    .formattedHostingController()
    return [card]
    #endif
}

#if os(iOS)
@MainActor private func featuredTaskViewController(
    for task: OCKTask?
) -> UIViewController {
    let featuredView = TipView()
    featuredView.headerView.titleLabel.text = task?.title ?? "Voice Recovery Milestone"
    featuredView.headerView.detailLabel.text = task?.instructions ?? "Complete this recovery milestone today."
    featuredView.imageView.image = UIImage(
        systemName: task?.asset ?? "mic.fill",
        withConfiguration: UIImage.SymbolConfiguration(
            pointSize: 120,
            weight: .regular
        )
    )
    featuredView.imageView.contentMode = .center
    featuredView.imageView.tintColor = UIColor(red: 0.70, green: 0.23, blue: 0.23, alpha: 1.0)
    featuredView.imageView.backgroundColor = UIColor(red: 0.99, green: 0.97, blue: 0.93, alpha: 1.0)

    let viewController = UIViewController()
    viewController.view = featuredView
    return viewController
}

@MainActor private func linkTaskViewController(
    for task: OCKTask?
) -> UIViewController {
    let resourceURLString = resolvedLinkURLString(for: task)
    let openLinkTitle = task?.title ?? "Open Link"
    let detailText = URL(string: resourceURLString)?.host?
        .replacingOccurrences(of: "www.", with: "") ?? "Recovery Resource"
    let title = Text(task?.title ?? "Recovery Resource")
    let detail = Text(detailText)
    let instructions = Text(
        task?.instructions ??
        "Open the Keck Medicine thyroidectomy page for recovery guidance."
    )

    let card = LinkView(
        title: title,
        detail: detail,
        instructions: instructions,
        links: [
            .website(
                resourceURLString,
                title: openLinkTitle
            )
        ]
    )
    .contentShape(Rectangle())
    .onTapGesture {
        guard let url = URL(string: resourceURLString) else { return }
        UIApplication.shared.open(url)
    }
    .formattedHostingController()

    return card
}

private func resolvedLinkURLString(for task: OCKTask?) -> String {
    if let taskURLString = normalizedHTTPURLString(task?.linkURL) {
        return taskURLString
    }
    return Constants.defaultRecoveryResourceURL
}

private func normalizedHTTPURLString(_ value: String?) -> String? {
    guard let value,
          let parsedURL = URL(string: value),
          let scheme = parsedURL.scheme?.lowercased(),
          scheme == "http" || scheme == "https" else {
        return nil
    }
    return value
}

@MainActor private func appendRecoveryTipIfNeeded(
    for date: Date,
    isCurrentDay: Bool,
    to listViewController: OCKListViewController
) {
    guard isCurrentDay else { return }
    guard Calendar.current.isDate(date, inSameDayAs: Date()) else { return }

    let tipView = TipView()
    tipView.headerView.titleLabel.text = "Voice Recovery Tips"
    tipView.headerView.detailLabel.text = """
    Hydration, gentle voice rest, and walking can support thyroid surgery recovery.
    """
    tipView.imageView.image = UIImage(systemName: "mic.fill")
    tipView.imageView.contentMode = .scaleAspectFit
    tipView.imageView.tintColor = UIColor(red: 0.70, green: 0.23, blue: 0.23, alpha: 1.0)
    tipView.imageView.backgroundColor = UIColor(red: 0.99, green: 0.97, blue: 0.93, alpha: 1.0)
    tipView.customStyle = CustomStylerKey.defaultValue
    listViewController.appendView(tipView, animated: false)

    let customFeaturedView = CustomFeaturedContentViewController(
        image: UIImage(named: "TheroPatientEdu.jpg") ?? UIImage(),
        text: "Thyroid Cancer Education",
        textColor: .white,
        imageOverlayStyle: .unspecified
    )
    customFeaturedView.url = URL(string: "https://mtceducate.org/")
    customFeaturedView.customStyle = CustomStylerKey.defaultValue
    listViewController.appendView(customFeaturedView, animated: false)
}
#endif

@MainActor private func customHealthKitTaskViewControllers(
    for task: any OCKAnyTask,
    query: OCKEventQuery,
    store: OCKAnyStoreProtocol
) -> [UIViewController] {
    var selectedCard = CareKitCard.numericProgress

    if let healthKitTask = task as? OCKHealthKitTask {
        selectedCard = healthKitTask.card
    }

    if selectedCard == .labeledValue {
        let card = EventQueryView<LabeledValueTaskView>(
            query: query,
            // controller: controller
        )
        .formattedHostingController()
        return [card]
    }

    let card = EventQueryView<NumericProgressTaskView>(
        query: query,
        // store: store
    )
    .formattedHostingController()
    return [card]
}
#if os(iOS)
class ThyroidModelTaskViewController: OCKInstructionsTaskViewController {
    override func taskView(
        _ taskView: UIView & OCKTaskDisplayable,
        didCompleteEvent isComplete: Bool,
        at indexPath: IndexPath,
        sender: Any?
    ) {

        if let parent = parent as? CareViewController {
            parent.presentThyroidModel()
        }
    }
}
#endif
@MainActor private extension View {
    /// Convert SwiftUI view to UIKit view.
    func formattedHostingController() -> UIHostingController<Self> {
        let viewController = UIHostingController(rootView: self)
        viewController.view.backgroundColor = .clear
        return viewController
    }
}
// swiftlint:disable type_body_length
#if os(iOS)
extension CareViewController: ORKTaskViewControllerDelegate {
    nonisolated func taskViewController(
        _ taskViewController: ORKTaskViewController,
        didFinishWith reason: ORKTaskFinishReason,
        error: Error?
    ) {
        DispatchQueue.main.async {
            taskViewController.dismiss(animated: true, completion: nil)
        }
    }
}
#endif
