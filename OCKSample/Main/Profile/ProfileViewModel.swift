//
//  Profile.swift
//  OCKSample
//
//  Created by Corey Baker on 11/25/20.
//  Copyright © 2020 Network Reconnaissance Lab. All rights reserved.
//

import CareKit
import CareKitStore
import CareKitEssentials
import HealthKit
import SwiftUI
import os.log

struct RegularTaskPayload {
    let assetName: String
    let linkURL: String?
    let checklistItem: String?
}

struct HealthKitTaskPayload {
    let assetName: String
    let numericGoalValue: Double?
}

@MainActor
class ProfileViewModel: ObservableObject {

    // MARK: Public read/write properties

    var firstName = ""
    var lastName = ""
    var birthday = Date()

    var patient: OCKPatient? {
        willSet {
            if let currentFirstName = newValue?.name.givenName {
                firstName = currentFirstName
            }
            if let currentLastName = newValue?.name.familyName {
                lastName = currentLastName
            }
            if let currentBirthday = newValue?.birthday {
                birthday = currentBirthday
            }
        }
    }

    // MARK: Helpers (public)

    func updatePatient(_ patient: OCKAnyPatient) {
        guard let patient = patient as? OCKPatient else {
            return
        }
        objectWillChange.send()
        self.patient = patient
    }

    // MARK: User intentional behavior

    func saveProfile() async throws {

        guard var patientToUpdate = patient else {
            throw AppError.errorString("The profile is missing the Patient")
        }

        // If there is a currentPatient that was fetched, check to see if any of the fields changed
        var patientHasBeenUpdated = false

        if patient?.name.givenName != firstName {
            patientHasBeenUpdated = true
            patientToUpdate.name.givenName = firstName
        }

        if patient?.name.familyName != lastName {
            patientHasBeenUpdated = true
            patientToUpdate.name.familyName = lastName
        }

        if patient?.birthday != birthday {
            patientHasBeenUpdated = true
            patientToUpdate.birthday = birthday
        }

        if patientHasBeenUpdated {
            if let anyPatient = try await AppDelegateKey.defaultValue?.store.updateAnyPatient(patientToUpdate),
               let updatedPatient = anyPatient as? OCKPatient {
                objectWillChange.send()
                self.patient = updatedPatient
                Logger.profile.info("Successfully updated patient and synced local state.")
            } else {
                Logger.profile.error("Patient was updated in store but could not be cast to OCKPatient.")
            }
        }
    }
}

@MainActor
class AddHealthKitTaskViewModel: ObservableObject {
    // OCKHealthKitTask
    func saveTask(
        title: String,
        instructions: String,
        scheduleStart: Date,
        cardType: CareKitCard,
        payload: HealthKitTaskPayload
    ) {
        // Validate form input.
        let taskTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let taskInstructions = instructions.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !taskTitle.isEmpty, !taskInstructions.isEmpty else {
            return
        }

        // Get the shared stores.
        guard let appDelegate = AppDelegateKey.defaultValue else {
            return
        }

        guard let healthKitStore = appDelegate.healthKitStore else {
            return
        }

        // Build a task from form data.
        let task = makeHealthKitTask(
            title: taskTitle,
            instructions: taskInstructions,
            scheduleStart: scheduleStart,
            cardType: cardType,
            payload: payload
        )

        // Save task.
        healthKitStore.addTasks([task]) { result in
            switch result {
            case .success:
                healthKitStore.requestHealthKitPermissionsForAllTasksInStore()
                NotificationCenter.default.post(
                    name: .init(rawValue: Constants.shouldRefreshView),
                    object: nil
                )

            case .failure(let error):
                Logger.profile.error("Could not save HealthKit task: \(error)")
            }
        }
    }

    func saveRegularTask(
        title: String,
        instructions: String,
        scheduleStart: Date,
        cardType: CareKitCard,
        payload: RegularTaskPayload
    ) {
        // Validate form input.
        let taskTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let taskInstructions = instructions.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !taskTitle.isEmpty, !taskInstructions.isEmpty else {
            return
        }

        // Get the shared stores.
        guard let appDelegate = AppDelegateKey.defaultValue else {
            return
        }

        // Build a task from form data.
        let task = makeRegularTask(
            title: taskTitle,
            instructions: taskInstructions,
            scheduleStart: scheduleStart,
            cardType: cardType,
            payload: payload
        )

        // Save task.
        appDelegate.store.addTasks([task]) { result in
            switch result {
            case .success:
                NotificationCenter.default.post(
                    name: .init(rawValue: Constants.shouldRefreshView),
                    object: nil
                )

            case .failure(let error):
                Logger.profile.error("Could not save OCKTask: \(error)")
            }
        }
    }
    // MARK: Helpers (private)

    private func makeHealthKitTask(
        title: String,
        instructions: String,
        scheduleStart: Date,
        cardType: CareKitCard,
        payload: HealthKitTaskPayload
    ) -> OCKHealthKitTask {
        let linkage: OCKHealthKitLinkage
        let targetValues: [OCKOutcomeValue]

        switch cardType {
        case .labeledValue:
            let heartRateUnit = HKUnit.count().unitDivided(by: HKUnit.minute())
            linkage = OCKHealthKitLinkage(
                quantityIdentifier: .heartRate,
                quantityType: .discrete,
                unit: heartRateUnit
            )
            targetValues = []

        default:
            let stepUnit = HKUnit.count()
            let goalValue = payload.numericGoalValue ?? 1000.0
            linkage = OCKHealthKitLinkage(
                quantityIdentifier: .stepCount,
                quantityType: .cumulative,
                unit: stepUnit
            )
            targetValues = [OCKOutcomeValue(goalValue, units: stepUnit.unitString)]
        }

        let schedule = OCKSchedule(
            composing: [
                OCKScheduleElement(
                    start: scheduleStart,
                    end: nil,
                    interval: DateComponents(day: 1),
                    text: "Daily",
                    targetValues: targetValues,
                    duration: .allDay
                )
            ]
        )

        var task = OCKHealthKitTask(
            id: "custom-healthkit-\(UUID().uuidString)",
            title: title,
            carePlanUUID: nil,
            schedule: schedule,
            healthKitLinkage: linkage
        )
        task.instructions = instructions
        task.asset = payload.assetName
        task.card = cardType
        task.impactsAdherence = true
        return task
    }

    private func makeRegularTask(
        title: String,
        instructions: String,
        scheduleStart: Date,
        cardType: CareKitCard,
        payload: RegularTaskPayload
    ) -> OCKTask {
        let scheduleText: String
        if cardType == .checklist {
            scheduleText = payload.checklistItem ?? "Daily"
        } else {
            scheduleText = "Daily"
        }

        let schedule = OCKSchedule(
            composing: [
                OCKScheduleElement(
                    start: scheduleStart,
                    end: nil,
                    interval: DateComponents(day: 1),
                    text: scheduleText,
                    targetValues: [],
                    duration: .allDay
                )
            ]
        )

        var task = OCKTask(
            id: "custom-task-\(UUID().uuidString)",
            title: title,
            carePlanUUID: nil,
            schedule: schedule
        )
        task.instructions = instructions
        task.asset = payload.assetName
        task.card = cardType
        task.linkURL = payload.linkURL
        task.impactsAdherence = true
        return task
    }

}

@MainActor
class DeleteTasksViewModel: ObservableObject {
    @Published var tasks: [OCKAnyTask] = []
    @Published var errorMessage: String?

    func loadTasks() async {
        guard let appDelegate = AppDelegateKey.defaultValue else {
            return
        }

        // Keep the delete sheet aligned with the Care page by only showing
        // tasks that are currently effective today.
        var query = OCKTaskQuery(for: Date())
        query.sortDescriptors = [.title(ascending: true)]

        do {
            tasks = try await appDelegate.storeCoordinator.fetchAnyTasks(query: query)
            errorMessage = nil
        } catch {
            errorMessage = "Could not load tasks."
            Logger.profile.error("Could not load tasks: \(error)")
        }
    }

    func deleteTask(_ task: OCKAnyTask) async {
        guard let appDelegate = AppDelegateKey.defaultValue else {
            return
        }

        do {
            _ = try await appDelegate.storeCoordinator.deleteAnyTask(task)
            await loadTasks()
            NotificationCenter.default.post(
                name: .init(rawValue: Constants.shouldRefreshView),
                object: nil
            )
            errorMessage = nil
        } catch {
            errorMessage = "Could not delete task."
            Logger.profile.error("Could not delete task: \(error)")
        }
    }
}
