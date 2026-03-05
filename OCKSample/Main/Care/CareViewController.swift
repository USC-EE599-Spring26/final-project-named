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
import SwiftUI
import UIKit

@MainActor
final class CareViewController: OCKDailyPageViewController, @unchecked Sendable {

    private var isSyncing = false
    private var isLoading = false
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

        #if os(iOS)
        appendRecoveryTipIfNeeded(
            for: date,
            isCurrentDay: isCurrentDay,
            to: listViewController
        )
        #endif

        fetchAndDisplayTasks(on: listViewController, for: date)
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
        for date: Date
    ) {
        Task {
            let tasks = await self.fetchTasks(on: date)
            appendTasks(tasks, to: listViewController, date: date)
        }
    }

    private func fetchTasks(on date: Date) async -> [any OCKAnyTask] {
        var query = OCKTaskQuery(for: date)
        query.excludesTasksWithNoEvents = true
        do {
            let tasks = try await store.fetchAnyTasks(query: query)
            /*let orderedTasks = TaskID.ordered.compactMap { orderedTaskID in
                tasks.first(where: { $0.id == orderedTaskID })
            }
            let knownTaskIDs = Set(orderedTasks.map { $0.id })
            let customTasks = tasks.filter { !knownTaskIDs.contains($0.id) }
            return orderedTasks + customTasks*/
            return tasks
        } catch {
            Logger.feed.error("Could not fetch tasks: \(error, privacy: .public)")
            return []
        }
    }

    private func taskViewControllers(
        _ task: any OCKAnyTask,
        on date: Date
    ) -> [UIViewController]? {

        var query = OCKEventQuery(for: date)
        query.taskIDs = [task.id]

        switch task.id {
        case TaskID.steps:
            let card = OCKSimpleTaskViewController(
                query: query,
                store: self.store
            )

            return [card]

        case TaskID.ovulationTestResult:
            let card = OCKSimpleTaskViewController(
                query: query,
                store: self.store
            )

            return [card]

        case TaskID.stretch:
            let card = OCKInstructionsTaskViewController(
                query: query,
                store: self.store
            )

            return [card]

        case TaskID.kegels:
            /*
             Since the kegel task is only scheduled every other day, there will be cases
             where it is not contained in the tasks array returned from the query.
             */
            let card = OCKSimpleTaskViewController(
                query: query,
                store: self.store
            )

            return [card]

        case let id where id.hasPrefix("custom-task-"):
            return customTaskViewControllers(
                for: task,
                query: query,
                store: self.store
            )

        case let id where id.hasPrefix("custom-healthkit-"):
            return customHealthKitTaskViewControllers(
                for: task,
                query: query,
                store: self.store
            )
        #if os(iOS)
        // Create a card for the doxylamine task if there are events for it on this day.
        case TaskID.doxylamine:

            // This is a UIKit based card.
            let card = OCKChecklistTaskViewController(
                query: query,
                store: self.store
            )

            return [card]
        #endif

        case TaskID.nausea:

            #if os(iOS)
            /*
             Also create a card (UIKit view) that displays a single event.
             The event query passed into the initializer specifies that only
             today's log entries should be displayed by this log task view controller.
             */
            let nauseaCard = OCKButtonLogTaskViewController(
                query: query,
                store: self.store
            )

            return [nauseaCard]

            #else
            return []
            #endif

        default:
            #if os(iOS)
            let card = OCKSimpleTaskViewController(
                query: query,
                store: self.store
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
    }

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
        let card = OCKButtonLogTaskViewController(
            query: query,
            store: store
        )
        return [card]
    }

    if selectedCard == .checklist {
        let card = OCKChecklistTaskViewController(
            query: query,
            store: store
        )
        return [card]
    }

    if selectedCard == .grid {
        let card = OCKGridTaskViewController(
            query: query,
            store: store
        )
        return [card]
    }

    if selectedCard == .instruction {
        let card = OCKInstructionsTaskViewController(
            query: query,
            store: store
        )
        return [card]
    }

    if selectedCard == .featured {
        let card = featuredTaskViewController(for: savedTask)
        return [card]
    }

    if selectedCard == .link {
        let card = linkTaskViewController(for: savedTask)
        return [card]
    }

    let card = OCKSimpleTaskViewController(
        query: query,
        store: store
    )
    return [card]
}

@MainActor private func featuredTaskViewController(
    for task: OCKTask?
) -> UIViewController {
    let featuredView = OCKFeaturedContentView(imageOverlayStyle: .light)
    featuredView.directionalLayoutMargins = NSDirectionalEdgeInsets(
        top: 20,
        leading: 20,
        bottom: 36,
        trailing: 20
    )
    featuredView.label.text = task?.title ?? "Voice Recovery Milestone"
    featuredView.imageView.image = UIImage(
        systemName: task?.asset ?? "mic.fill",
        withConfiguration: UIImage.SymbolConfiguration(
            pointSize: 120,
            weight: .regular
        )
    )
    featuredView.imageView.contentMode = .center

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
}

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
        let card = OCKSimpleTaskViewController(
            query: query,
            store: store
        )
        return [card]
    }

    let card = OCKSimpleTaskViewController(
        query: query,
        store: store
    )
    return [card]
}

private extension View {
    /// Convert SwiftUI view to UIKit view.
    func formattedHostingController() -> UIHostingController<Self> {
        let viewController = UIHostingController(rootView: self)
        viewController.view.backgroundColor = .clear
        return viewController
    }
}
