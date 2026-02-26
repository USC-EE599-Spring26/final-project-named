//
//  OCKStore.swift
//  OCKSample
//
//  Created by Corey Baker on 1/5/22.
//  Copyright © 2022 Network Reconnaissance Lab. All rights reserved.
//

import Foundation
import CareKitEssentials
import CareKitStore
import Contacts
import os.log
import ParseSwift
import ParseCareKit

extension OCKStore {

    func addContactsIfNotPresent(_ contacts: [OCKContact]) async throws -> [OCKContact] {
        let contactIdsToAdd = contacts.compactMap { $0.id }

        // Prepare query to see if contacts are already added
        var query = OCKContactQuery(for: Date())
        query.ids = contactIdsToAdd

        let foundContacts = try await fetchContacts(query: query)

        // Find all missing tasks.
        let contactsNotInStore = contacts.filter { potentialContact -> Bool in
            guard foundContacts.first(where: { $0.id == potentialContact.id }) == nil else {
                return false
            }
            return true
        }

        // Only add if there's a new task
        guard contactsNotInStore.count > 0 else {
            return []
        }

        let addedContacts = try await addContacts(contactsNotInStore)
        return addedContacts
    }

    // Adds tasks and contacts into the store
    func populateDefaultCarePlansTasksContacts(
        startDate: Date = Date()
    ) async throws {

        let calendar = Calendar.current
        let thisMorning = calendar.startOfDay(for: startDate)
        let medicationStart = calendar.date(
            bySettingHour: 6,
            minute: 30,
            second: 0,
            of: thisMorning
        ) ?? thisMorning
        let noonStart = calendar.date(
            bySettingHour: 12,
            minute: 0,
            second: 0,
            of: thisMorning
        ) ?? thisMorning
        let eveningStart = calendar.date(
            bySettingHour: 19,
            minute: 30,
            second: 0,
            of: thisMorning
        ) ?? thisMorning
        let weeklyStart = calendar.date(
            bySettingHour: 10,
            minute: 0,
            second: 0,
            of: thisMorning
        ) ?? thisMorning
        let twoWeeksLater = calendar.date(
            byAdding: .day,
            value: 14,
            to: thisMorning
        )

        let levothyroxineSchedule = OCKSchedule(
            composing: [
                OCKScheduleElement(
                    start: medicationStart,
                    end: nil,
                    interval: DateComponents(day: 1)
                )
            ]
        )
        var levothyroxineMedication = OCKTask(
            id: TaskID.levothyroxineMedication,
            title: String(localized: "TASK_LEVOTHYROXINE_TITLE"),
            carePlanUUID: nil,
            schedule: levothyroxineSchedule
        )
        levothyroxineMedication.instructions = String(
            localized: "TASK_LEVOTHYROXINE_INSTRUCTIONS"
        )
        levothyroxineMedication.asset = "pills.fill"
        levothyroxineMedication.userInfo = [
            Constants.taskCardStyleKey: "instructions",
            Constants.taskDomainKey: Constants.thyroidDomainValue
        ]

        let calciumSchedule = OCKSchedule(
            composing: [
                OCKScheduleElement(
                    start: noonStart,
                    end: nil,
                    interval: DateComponents(day: 1)
                )
            ]
        )
        var calciumSupplement = OCKTask(
            id: TaskID.calciumSupplement,
            title: String(localized: "TASK_CALCIUM_TITLE"),
            carePlanUUID: nil,
            schedule: calciumSchedule
        )
        calciumSupplement.instructions = String(
            localized: "TASK_CALCIUM_INSTRUCTIONS"
        )
        calciumSupplement.asset = "pills.circle.fill"
        calciumSupplement.userInfo = [
            Constants.taskCardStyleKey: "instructions",
            Constants.taskDomainKey: Constants.thyroidDomainValue
        ]

        let incisionSchedule = OCKSchedule(
            composing: [
                OCKScheduleElement(
                    start: eveningStart,
                    end: twoWeeksLater,
                    interval: DateComponents(day: 1)
                )
            ]
        )
        var incisionCareCheck = OCKTask(
            id: TaskID.incisionCareCheck,
            title: String(localized: "TASK_INCISION_TITLE"),
            carePlanUUID: nil,
            schedule: incisionSchedule
        )
        incisionCareCheck.instructions = String(
            localized: "TASK_INCISION_INSTRUCTIONS"
        )
        incisionCareCheck.asset = "cross.case.fill"
        incisionCareCheck.userInfo = [
            Constants.taskCardStyleKey: "simple",
            Constants.taskDomainKey: Constants.thyroidDomainValue
        ]

        let symptomSchedule = OCKSchedule(
            composing: [
                OCKScheduleElement(
                    start: eveningStart,
                    end: nil,
                    interval: DateComponents(day: 1),
                    text: String(localized: "ANYTIME_DURING_DAY"),
                    targetValues: [],
                    duration: .allDay
                )
            ]
        )
        var symptomScore = OCKTask(
            id: TaskID.symptomScore,
            title: String(localized: "TASK_SYMPTOM_SCORE_TITLE"),
            carePlanUUID: nil,
            schedule: symptomSchedule
        )
        symptomScore.instructions = String(
            localized: "TASK_SYMPTOM_SCORE_INSTRUCTIONS"
        )
        symptomScore.impactsAdherence = false
        symptomScore.asset = "waveform.path.ecg"
        symptomScore.userInfo = [
            Constants.taskCardStyleKey: "buttonLog",
            Constants.taskDomainKey: Constants.thyroidDomainValue
        ]

        let voiceRestSchedule = OCKSchedule(
            composing: [
                OCKScheduleElement(
                    start: medicationStart,
                    end: nil,
                    interval: DateComponents(day: 2)
                )
            ]
        )
        var voiceRestExercise = OCKTask(
            id: TaskID.voiceRestExercise,
            title: String(localized: "TASK_VOICE_REST_TITLE"),
            carePlanUUID: nil,
            schedule: voiceRestSchedule
        )
        voiceRestExercise.instructions = String(
            localized: "TASK_VOICE_REST_INSTRUCTIONS"
        )
        voiceRestExercise.asset = "mouth.fill"
        voiceRestExercise.userInfo = [
            Constants.taskCardStyleKey: "instructions",
            Constants.taskDomainKey: Constants.thyroidDomainValue
        ]

        let followUpSchedule = OCKSchedule(
            composing: [
                OCKScheduleElement(
                    start: weeklyStart,
                    end: nil,
                    interval: DateComponents(day: 7)
                )
            ]
        )
        var followUpReminder = OCKTask(
            id: TaskID.followUpReminder,
            title: String(localized: "TASK_FOLLOW_UP_TITLE"),
            carePlanUUID: nil,
            schedule: followUpSchedule
        )
        followUpReminder.instructions = String(
            localized: "TASK_FOLLOW_UP_INSTRUCTIONS"
        )
        followUpReminder.asset = "calendar.badge.clock"
        followUpReminder.userInfo = [
            Constants.taskCardStyleKey: "checklist",
            Constants.taskDomainKey: Constants.thyroidDomainValue
        ]

        _ = try await addTasksIfNotPresent([
            levothyroxineMedication,
            calciumSupplement,
            incisionCareCheck,
            symptomScore,
            voiceRestExercise,
            followUpReminder
        ])

        var contact1 = OCKContact(
            id: "endocrine_surgeon",
            givenName: "Alex",
            familyName: "Chen",
            carePlanUUID: nil
        )
        contact1.title = String(localized: "CONTACT_ENDOCRINE_SURGEON_TITLE")
        contact1.role = String(localized: "CONTACT_ENDOCRINE_SURGEON_ROLE")
        contact1.emailAddresses = [
            OCKLabeledValue(
                label: CNLabelWork,
                value: "endo.surgery@uscmed.org"
            )
        ]
        contact1.phoneNumbers = [
            OCKLabeledValue(label: CNLabelWork, value: "(800) 257-2000")
        ]
        contact1.messagingNumbers = [
            OCKLabeledValue(label: CNLabelWork, value: "(800) 357-2040")
        ]
        contact1.address = {
            let address = OCKPostalAddress(
                street: "1500 San Pablo St",
                city: "Los Angeles",
                state: "CA",
                postalCode: "90033",
                country: "US"
            )
            return address
        }()

        var contact2 = OCKContact(
            id: "thyroid_nurse",
            givenName: "Mia",
            familyName: "Lopez",
            carePlanUUID: nil
        )
        contact2.title = String(localized: "CONTACT_THYROID_NURSE_TITLE")
        contact2.role = String(localized: "CONTACT_THYROID_NURSE_ROLE")
        contact2.emailAddresses = [
            OCKLabeledValue(
                label: CNLabelWork,
                value: "thyroid.nurse@uscmed.org"
            )
        ]
        contact2.phoneNumbers = [
            OCKLabeledValue(label: CNLabelWork, value: "(800) 257-1000")
        ]
        contact2.messagingNumbers = [
            OCKLabeledValue(label: CNLabelWork, value: "(800) 257-1234")
        ]
        contact2.address = {
            let address = OCKPostalAddress(
                street: "1500 San Pablo St",
                city: "Los Angeles",
                state: "CA",
                postalCode: "90033",
                country: "US"
            )
            return address
        }()

        _ = try await addContactsIfNotPresent(
            [
                contact1,
                contact2
            ]
        )
    }
}
