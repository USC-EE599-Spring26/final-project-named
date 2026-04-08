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
import ParseSwift
import SwiftUI
import os.log
#if canImport(UIKit)
import UIKit
#endif

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

    var firstName = ""
    var lastName = ""
    var birthday = Date()
    var loginName = ""
    var email = ""
    var phoneNumber = ""
    var street = ""
    var city = ""
    var state = ""
    var postalCode = ""
#if canImport(UIKit)
    var avatarImage: UIImage?
#endif
    var avatarURL: URL?
    private var pendingAvatarData: Data?
    private var currentUser: User?
    private var contact: OCKContact?

    var displayName: String {
        let trimmedFirst = firstName.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedLast = lastName.trimmingCharacters(in: .whitespacesAndNewlines)
        let combinedName = [trimmedFirst, trimmedLast]
            .filter { !$0.isEmpty }
            .joined(separator: " ")

        if !combinedName.isEmpty {
            return combinedName
        }

        return loginName.isEmpty ? "Anonymous" : loginName
    }

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

    func updatePatient(_ patient: OCKAnyPatient) {
        guard let patient = patient as? OCKPatient else {
            return
        }
        objectWillChange.send()
        self.patient = patient
    }

    func updateContact(_ contact: OCKAnyContact) {
        guard let currentPatient = patient,
              let contact = contact as? OCKContact,
              contact.id == currentPatient.id,
              contact.uuid != self.contact?.uuid else {
            return
        }

        self.contact = contact
    }

    func loadCurrentUser() async {
        do {
            let user = try await User.current()
            objectWillChange.send()
            currentUser = user
            loginName = user.username ?? "Anonymous"
            email = user.email ?? ""
            phoneNumber = user.phoneNumber ?? ""
            street = user.street ?? ""
            city = user.city ?? ""
            state = user.state ?? ""
            postalCode = user.postalCode ?? ""
            avatarURL = user.profileImage?.url
#if canImport(UIKit)
            avatarImage = nil
#endif
            pendingAvatarData = nil
        } catch {
            Logger.profile.error("Could not load current user: \(error)")
        }
    }

#if canImport(UIKit)
    func updateAvatar(data: Data) {
        guard let image = UIImage(data: data) else {
            return
        }
        objectWillChange.send()
        avatarImage = image
        pendingAvatarData = data
    }
#endif

    func saveProfile() async throws {

        guard var patientToUpdate = patient else {
            throw AppError.errorString("The profile is missing the Patient")
        }

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

        try await saveCurrentUserProfile()
        try await saveContact()
    }
}

extension ProfileViewModel {
    func prepareMyContactForPresentation() async {
        do {
            try await saveContact()
        } catch {
            Logger.profile.error("Could not prepare My Contact: \(error)")
        }
    }
}

private extension ProfileViewModel {
    private func saveCurrentUserProfile() async throws {
        var user = try await User.current()
        var userHasBeenUpdated = false

        if user.email != normalizedOptionalValue(email) {
            userHasBeenUpdated = true
            user.email = normalizedOptionalValue(email)
        }

        if user.phoneNumber != normalizedOptionalValue(phoneNumber) {
            userHasBeenUpdated = true
            user.phoneNumber = normalizedOptionalValue(phoneNumber)
        }

        if user.street != normalizedOptionalValue(street) {
            userHasBeenUpdated = true
            user.street = normalizedOptionalValue(street)
        }

        if user.city != normalizedOptionalValue(city) {
            userHasBeenUpdated = true
            user.city = normalizedOptionalValue(city)
        }

        if user.state != normalizedOptionalValue(state) {
            userHasBeenUpdated = true
            user.state = normalizedOptionalValue(state)
        }

        if user.postalCode != normalizedOptionalValue(postalCode) {
            userHasBeenUpdated = true
            user.postalCode = normalizedOptionalValue(postalCode)
        }

        if let pendingAvatarData {
            let avatarFile = ParseFile(
                name: "profile-avatar-\(UUID().uuidString).jpg",
                data: pendingAvatarData,
                mimeType: "image/jpeg"
            )
            let savedFile = try await avatarFile.save()
            user.profileImage = savedFile
            userHasBeenUpdated = true
        }

        guard userHasBeenUpdated else {
            currentUser = user
            return
        }

        let savedUser = try await user.save()
        objectWillChange.send()
        currentUser = savedUser
        loginName = savedUser.username ?? "Anonymous"
        email = savedUser.email ?? ""
        phoneNumber = savedUser.phoneNumber ?? ""
        street = savedUser.street ?? ""
        city = savedUser.city ?? ""
        state = savedUser.state ?? ""
        postalCode = savedUser.postalCode ?? ""
        avatarURL = savedUser.profileImage?.url
        pendingAvatarData = nil
#if canImport(UIKit)
        if savedUser.profileImage != nil {
            avatarImage = nil
        }
#endif
    }

    private func saveContact() async throws {
        guard let store = AppDelegateKey.defaultValue?.store else {
            throw AppError.couldntBeUnwrapped
        }

        let remoteUUID = try await Utility.getRemoteClockUUID().uuidString
        var fallbackName = PersonNameComponents()
        fallbackName.givenName = firstName
        fallbackName.familyName = lastName
        let patientName = patient?.name ?? fallbackName
        let emailValue = normalizedOptionalValue(email)
        let phoneValue = normalizedOptionalValue(phoneNumber)

        let address = OCKPostalAddress(
            street: normalizedOptionalValue(street) ?? "",
            city: normalizedOptionalValue(city) ?? "",
            state: normalizedOptionalValue(state) ?? "",
            postalCode: normalizedOptionalValue(postalCode) ?? "",
            country: ""
        )

        let emailAddresses = emailValue.map { [OCKLabeledValue(label: "email", value: $0)] }
        let phoneNumbers = phoneValue.map { [OCKLabeledValue(label: "phone", value: $0)] }

        if var contactToUpdate = contact {
            var contactHasBeenUpdated = false

            if contactToUpdate.name.givenName != patientName.givenName ||
                contactToUpdate.name.familyName != patientName.familyName {
                contactHasBeenUpdated = true
                contactToUpdate.name = patientName
            }

            if contactToUpdate.address?.street != address.street ||
                contactToUpdate.address?.city != address.city ||
                contactToUpdate.address?.state != address.state ||
                contactToUpdate.address?.postalCode != address.postalCode {
                contactHasBeenUpdated = true
                contactToUpdate.address = address
            }

            let currentEmail = contactToUpdate.emailAddresses?.first?.value
            if currentEmail != emailValue {
                contactHasBeenUpdated = true
                contactToUpdate.emailAddresses = emailAddresses
            }

            let currentPhone = contactToUpdate.phoneNumbers?.first?.value
            if currentPhone != phoneValue {
                contactHasBeenUpdated = true
                contactToUpdate.phoneNumbers = phoneNumbers
                contactToUpdate.messagingNumbers = phoneNumbers
            }

            if contactHasBeenUpdated,
               let updatedContact = try await store.updateAnyContact(contactToUpdate) as? OCKContact {
                objectWillChange.send()
                contact = updatedContact
            }
        } else {
            var newContact = OCKContact(id: remoteUUID, name: patientName, carePlanUUID: nil)
            newContact.address = address
            newContact.emailAddresses = emailAddresses
            newContact.phoneNumbers = phoneNumbers
            newContact.messagingNumbers = phoneNumbers

            let savedContact = try await store.addAnyContact(newContact) as? OCKContact
            objectWillChange.send()
            contact = savedContact
        }
    }

    private func normalizedOptionalValue(_ value: String) -> String? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

}

extension ProfileViewModel {
    static func queryContacts() -> OCKContactQuery {
        OCKContactQuery(for: Date())
    }
}

@MainActor
class AddHealthKitTaskViewModel: ObservableObject {
    func saveTask(
        title: String,
        instructions: String,
        schedule: TaskScheduleConfiguration,
        cardType: CareKitCard,
        payload: HealthKitTaskPayload
    ) {
        let taskTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let taskInstructions = instructions.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !taskTitle.isEmpty, !taskInstructions.isEmpty else {
            return
        }

        guard let appDelegate = AppDelegateKey.defaultValue else {
            return
        }

        guard let healthKitStore = appDelegate.healthKitStore else {
            return
        }

        let task = makeHealthKitTask(
            title: taskTitle,
            instructions: taskInstructions,
            schedule: schedule,
            cardType: cardType,
            payload: payload
        )

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
        let taskTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let taskInstructions = instructions.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !taskTitle.isEmpty, !taskInstructions.isEmpty else {
            return
        }

        guard let appDelegate = AppDelegateKey.defaultValue else {
            return
        }

        let task = makeRegularTask(
            title: taskTitle,
            instructions: taskInstructions,
            schedule: schedule,
            cardType: cardType,
            payload: payload
        )

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
