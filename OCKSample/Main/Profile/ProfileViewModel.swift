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
import ParseSwift
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

struct TaskScheduleConfiguration {
    let startDate: Date
    let repeatEveryDays: Int

    var normalizedStartDate: Date {
        Calendar.current.startOfDay(for: startDate)
    }

    var recurrenceDescription: String {
        repeatEveryDays == 1 ? "Daily" : "Every \(repeatEveryDays) days"
    }
}

@MainActor
class ProfileViewModel: ObservableObject {

    // MARK: Public read/write properties

    @Published var firstName = ""
    @Published var lastName = ""
    @Published var birthday = Date()
    @Published var sex: OCKBiologicalSex = .other("other")
    @Published var sexOtherField = "other"
    @Published var note = ""
    @Published var street = ""
    @Published var city = ""
    @Published var state = ""
    @Published var zipcode = ""
    @Published var country = ""
    @Published var isShowingSaveAlert = false
    @Published var isPresentingAddTask = false
    @Published var isPresentingContact = false
    @Published var isPresentingImagePicker = false
    @Published var profileUIImage = UIImage(systemName: "person.fill") {
        willSet {
            guard self.profileUIImage != newValue,
                let inputImage = newValue else {
                return
            }

            if !isSettingProfilePictureForFirstTime {
                Task {
                    guard var currentUser = (try? await User.current()),
                          let image = inputImage.jpegData(compressionQuality: 0.25) else {
                        Logger.profile.error("User is not logged in or could not compress image")
                        return
                    }

                    let newProfilePicture = ParseFile(name: "profile.jpg", data: image)
                    // Use `.set()` to update ParseObject's that have already been saved before.
                    currentUser = currentUser.set(\.profilePicture, to: newProfilePicture)
                    do {
                        _ = try await currentUser.save()
                        Logger.profile.info("Saved updated profile picture successfully.")
                    } catch {
                        Logger.profile.error("Could not save profile picture: \(error.localizedDescription)")
                    }
                }
            }
        }
    }
    @Published private(set) var error: Error?
    private(set) var alertMessage = "All changs saved successfully!"
    private var contact: OCKContact? {
        willSet {
            street = newValue?.address?.street ?? ""
            city = newValue?.address?.city ?? ""
            state = newValue?.address?.state ?? ""
            zipcode = newValue?.address?.postalCode ?? ""
            country = newValue?.address?.country ?? ""
        }
    }

    // MARK: Private read/write properties
    private var isSettingProfilePictureForFirstTime = true

    var patient: OCKPatient? {
        willSet {
            if let currentFirstName = newValue?.name.givenName {
                firstName = currentFirstName
            } else {
                firstName = ""
            }
            if let currentLastName = newValue?.name.familyName {
                lastName = currentLastName
            } else {
                lastName = ""
            }
            if let currentBirthday = newValue?.birthday {
                birthday = currentBirthday
            } else {
                birthday = Date()
            }
        }
    }

    // MARK: Helpers (public)

    func updatePatient(_ patient: OCKAnyPatient) {
        guard let patient = patient as? OCKPatient,
              // Only update if we have a newer version.
              patient.uuid != self.patient?.uuid else {
            return
        }
        self.patient = patient

        // Fetch the profile picture if we have a patient.
        Task {
            do {
                try await fetchProfilePicture()
            } catch {
                Logger.profile.error("Failed to fetch profile picture: \(error.localizedDescription)")
            }
        }
    }

    func updateContact(_ contact: OCKAnyContact) {
        guard let currentPatient = self.patient,
              let contact = contact as? OCKContact,
              // Has to be my contact.
              contact.id == currentPatient.id,
              // Only update if we have a newer version.
              contact.uuid != self.contact?.uuid else {
            return
        }
        self.contact = contact
    }

    @MainActor
    private func fetchProfilePicture() async throws {

         // Profile pics are stored in Parse User.
        guard let currentUser = (try? await User.current().fetch()) else {
            Logger.profile.error("User is not logged in")
            return
        }

        if let pictureFile = currentUser.profilePicture {

            // Download picture from server if needed
            do {
                let profilePicture = try await pictureFile.fetch()
                guard let path = profilePicture.localURL?.relativePath else {
                    Logger.profile.error("Could not find relative path for profile picture.")
                    return
                }
                self.profileUIImage = UIImage(contentsOfFile: path)
            } catch {
                Logger.profile.error("Could not fetch profile picture: \(error.localizedDescription).")
            }
        }
        self.isSettingProfilePictureForFirstTime = false
    }

    // MARK: User intentional behavior

    @MainActor
    func saveProfile() async {
        alertMessage = "All changs saved successfully!"
        do {
            try await savePatient()
            try await saveContact()
        } catch {
            alertMessage = "Could not save profile: \(error)"
        }
        isShowingSaveAlert = true // Make alert pop up for user.
    }

    @MainActor
    func savePatient() async throws {
        if var patientToUpdate = patient {
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

            if patient?.sex != sex {
                patientHasBeenUpdated = true
                patientToUpdate.sex = sex
            }

            let notes = [OCKNote(author: firstName,
                                 title: "New Note",
                                 content: note)]
            if patient?.notes != notes {
                patientHasBeenUpdated = true
                patientToUpdate.notes = notes
            }

            if patientHasBeenUpdated {
                _ = try await AppDelegateKey.defaultValue?.store.updateAnyPatient(patientToUpdate)
                Logger.profile.info("Successfully updated patient")
            }

        } else {
            guard let remoteUUID = (try? await Utility.getRemoteClockUUID())?.uuidString else {
                Logger.profile.error("The user currently is not logged in")
                return
            }

            var newPatient = OCKPatient(id: remoteUUID,
                                        givenName: firstName,
                                        familyName: lastName)
            newPatient.birthday = birthday

            // This is new patient that has never been saved before
            _ = try await AppDelegateKey.defaultValue?.store.addAnyPatient(newPatient)
            Logger.profile.info("Succesffully saved new patient")
        }
    }

    @MainActor
    func saveContact() async throws {

        if var contactToUpdate = contact {
            // If a current contact was fetched, check to see if any of the fields have changed

            var contactHasBeenUpdated = false

            // Since OCKPatient was updated earlier, we should compare against this name
            if let patientName = patient?.name,
                contact?.name != patient?.name {
                contactHasBeenUpdated = true
                contactToUpdate.name = patientName
            }

            // Create a mutable temp address to compare
            let potentialAddress = OCKPostalAddress(
                street: street,
                city: city,
                state: state,
                postalCode: zipcode,
                country: country
            )
            if contact?.address != potentialAddress {
                contactHasBeenUpdated = true
                contactToUpdate.address = potentialAddress
            }

            if contactHasBeenUpdated {
                _ = try await AppDelegateKey.defaultValue?.store.updateAnyContact(contactToUpdate)
                Logger.profile.info("Successfully updated contact")
            }

        } else {

            guard let remoteUUID = (try? await Utility.getRemoteClockUUID())?.uuidString else {
                Logger.profile.error("The user currently is not logged in")
                return
            }

            guard let patientName = self.patient?.name else {
                Logger.profile.info("The patient did not have a name.")
                return
            }

            // Added code to create a contact for the respective signed up user
            var newContact = OCKContact(
                id: remoteUUID,
                name: patientName,
                carePlanUUID: nil
            )
            newContact.address = OCKPostalAddress(
                street: street,
                city: city,
                state: state,
                postalCode: zipcode,
                country: country
            )

            _ = try await AppDelegateKey.defaultValue?.store.addAnyContact(newContact)
            Logger.profile.info("Succesffully saved new contact")
        }
    }

    static func queryPatient() -> OCKPatientQuery {
        OCKPatientQuery(for: Date())
    }

    static func queryContacts() -> OCKContactQuery {
        OCKContactQuery(for: Date())
    }

}

@MainActor
class AddHealthKitTaskViewModel: ObservableObject {
    // OCKHealthKitTask
    func saveTask(
        title: String,
        instructions: String,
        schedule: TaskScheduleConfiguration,
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
            schedule: schedule,
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
        schedule: TaskScheduleConfiguration,
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
            schedule: schedule,
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
        schedule: TaskScheduleConfiguration,
        cardType: CareKitCard,
        payload: HealthKitTaskPayload
    ) -> OCKHealthKitTask {
        let linkage: OCKHealthKitLinkage
        let targetValues: [OCKOutcomeValue]

        switch cardType {
        case .labeledValue:
            let heartRateUnit = HKUnit.count().unitDivided(by: HKUnit.minute())
            linkage = OCKHealthKitLinkage(
                quantityIdentifier: .restingHeartRate,
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

        let taskSchedule = OCKSchedule(
            composing: [
                OCKScheduleElement(
                    start: schedule.normalizedStartDate,
                    end: nil,
                    interval: DateComponents(day: schedule.repeatEveryDays),
                    text: schedule.recurrenceDescription,
                    targetValues: targetValues,
                    duration: .allDay
                )
            ]
        )

        var task = OCKHealthKitTask(
            id: "custom-healthkit-\(UUID().uuidString)",
            title: title,
            carePlanUUID: nil,
            schedule: taskSchedule,
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
        schedule: TaskScheduleConfiguration,
        cardType: CareKitCard,
        payload: RegularTaskPayload
    ) -> OCKTask {
        let scheduleText: String
        if cardType == .checklist {
            scheduleText = payload.checklistItem ?? "Daily"
        } else {
            scheduleText = schedule.recurrenceDescription
        }

        let taskSchedule = OCKSchedule(
            composing: [
                OCKScheduleElement(
                    start: schedule.normalizedStartDate,
                    end: nil,
                    interval: DateComponents(day: schedule.repeatEveryDays),
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
            schedule: taskSchedule
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
