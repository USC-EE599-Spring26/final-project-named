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
import SwiftUI
import os.log

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
                self.patient = updatedPatient
                Logger.profile.info("Successfully updated patient and synced local state.")
            } else {
                Logger.profile.error("Patient was updated in store but could not be cast to OCKPatient.")
            }
        }
    }
}

@MainActor
final class TaskManagementViewModel: ObservableObject {
    @Published var title = ""
    @Published var instructions = ""
    @Published var scheduleTime = Date()
    @Published private(set) var statusMessage = ""
    @Published private(set) var hasError = false
    @Published private(set) var isProcessing = false

    func createTask() async {
        guard !isProcessing else { return }

        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTitle.isEmpty else {
            hasError = true
            statusMessage = "Task title is required."
            return
        }

        guard let store = AppDelegateKey.defaultValue?.store else {
            hasError = true
            statusMessage = "Care store is unavailable."
            return
        }

        isProcessing = true
        defer { isProcessing = false }

        do {
            let schedule = makeDailySchedule(time: scheduleTime)
            var task = OCKTask(
                id: makeTaskID(from: trimmedTitle),
                title: trimmedTitle,
                carePlanUUID: nil,
                schedule: schedule
            )
            let trimmedInstructions = instructions.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmedInstructions.isEmpty {
                task.instructions = trimmedInstructions
            }
            task.asset = "checkmark.circle"
            _ = try await store.addTask(task)

            NotificationCenter.default.post(
                .init(name: Notification.Name(rawValue: Constants.shouldRefreshView))
            )
            hasError = false
            statusMessage = "Task added successfully."
            title = ""
            instructions = ""
        } catch {
            hasError = true
            statusMessage = "Failed to add task: \(error.localizedDescription)"
        }
    }

    private func makeDailySchedule(time: Date) -> OCKSchedule {
        let components = Calendar.current.dateComponents(
            [.hour, .minute],
            from: time
        )
        let startDate = Calendar.current.date(
            bySettingHour: components.hour ?? 8,
            minute: components.minute ?? 0,
            second: 0,
            of: Date()
        ) ?? Date()

        return OCKSchedule(
            composing: [
                OCKScheduleElement(
                    start: startDate,
                    end: nil,
                    interval: DateComponents(day: 1)
                )
            ]
        )
    }

    private func makeTaskID(from title: String) -> String {
        let slug = title
            .lowercased()
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }
            .joined(separator: "_")
        let sanitizedTitle = slug.isEmpty ? "custom_task" : slug
        let shortUUID = UUID().uuidString.prefix(8).lowercased()
        return "\(sanitizedTitle)_\(shortUUID)"
    }
}
