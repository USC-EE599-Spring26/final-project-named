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
import ResearchKitSwiftUI

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

        let thisMorning = Calendar.current.startOfDay(for: startDate)
        let onboardingEndDate = thisMorning.endOfDay
        let aFewDaysAgo = Calendar.current.date(byAdding: .day, value: -4, to: thisMorning)!
        let beforeBreakfast = Calendar.current.date(byAdding: .hour, value: 8, to: aFewDaysAgo)!
        let afterLunch = Calendar.current.date(byAdding: .hour, value: 14, to: aFewDaysAgo)!

        let schedule = OCKSchedule(
            composing: [
                OCKScheduleElement(
                    start: beforeBreakfast,
                    end: nil,
                    interval: DateComponents(day: 1)
                ),
                OCKScheduleElement(
                    start: afterLunch,
                    end: nil,
                    interval: DateComponents(day: 2)
                )
            ]
        )

        var doxylamine = OCKTask(
            id: TaskID.doxylamine,
            title: String(localized: "TAKE_DOXYLAMINE"),
            carePlanUUID: nil,
            schedule: schedule
        )
        doxylamine.instructions = String(localized: "DOXYLAMINE_INSTRUCTIONS")
        doxylamine.asset = "drop.fill"
        doxylamine.card = .instruction
        doxylamine.priority = 2
        let nauseaSchedule = OCKSchedule(
            composing: [
                OCKScheduleElement(
                    start: beforeBreakfast,
                    end: nil,
                    interval: DateComponents(day: 1),
                    text: String(localized: "ANYTIME_DURING_DAY"),
                    targetValues: [],
                    duration: .allDay
                )
            ]
        )

        var nausea = OCKTask(
            id: TaskID.nausea,
            title: String(localized: "TRACK_NAUSEA"),
            carePlanUUID: nil,
            schedule: nauseaSchedule
        )
        nausea.impactsAdherence = false
        nausea.instructions = String(localized: "NAUSEA_INSTRUCTIONS")
        nausea.asset = "waveform.path.ecg"
        nausea.card = .button
        nausea.priority = 5

        let stretchElement = OCKScheduleElement(
            start: beforeBreakfast,
            end: nil,
            interval: DateComponents(day: 1)
        )
        let stretchSchedule = OCKSchedule(
            composing: [stretchElement]
        )
        var stretch = OCKTask(
            id: TaskID.stretch,
            title: String(localized: "STRETCH"),
            carePlanUUID: nil,
            schedule: stretchSchedule
        )
        stretch.impactsAdherence = true
        stretch.instructions = "Use gentle voice rest, avoid throat clearing, and speak only as needed."
        stretch.asset = "mic.fill"
        stretch.priority = 4

        let walkingElement = OCKScheduleElement(
            start: beforeBreakfast,
            end: nil,
            interval: DateComponents(day: 1)
        )
        let walkingSchedule = OCKSchedule(
            composing: [walkingElement]
        )
        var walking = OCKTask(
            id: TaskID.walking,
            title: String(localized: "WALKING_CHECK"),
            carePlanUUID: nil,
            schedule: walkingSchedule
        )
        walking.impactsAdherence = true
        walking.instructions = String(localized: "WALKING_INSTRUCTIONS")
        walking.asset = "figure.walk"
        walking.card = .instruction
        walking.priority = 3

        let onboardingSchedule = OCKSchedule(
            composing: [
                OCKScheduleElement(
                    start: thisMorning,
                    end: onboardingEndDate,
                    interval: DateComponents(day: 1),
                    text: "Task Due!",
                    targetValues: [],
                    duration: .allDay
                )
            ]
        )
        var onboard = OCKTask(
            id: TaskID.onboard,
            title: "Onboard",
            carePlanUUID: nil,
            schedule: onboardingSchedule
        )
        onboard.impactsAdherence = true
        onboard.instructions = "You'll need to agree to some terms and conditions before we get started!"
        onboard.asset = "hand.wave.fill"
        onboard.card = .custom
        onboard.priority = -1

        let neckMobilitySchedule = OCKSchedule(
            composing: [
                OCKScheduleElement(
                    start: beforeBreakfast,
                    end: nil,
                    interval: DateComponents(day: 1),
                    text: String(localized: "ANYTIME_DURING_DAY"),
                    targetValues: [],
                    duration: .allDay
                )
            ]
        )
        var neckMobility = OCKTask(
            id: TaskID.neckMobility,
            title: "Neck Mobility Check",
            carePlanUUID: nil,
            schedule: neckMobilitySchedule
        )
        neckMobility.impactsAdherence = true
        neckMobility.instructions = "Tap Begin to follow a gentle guided neck mobility check."
        neckMobility.asset = "heart.fill"
        neckMobility.card = .custom
        neckMobility.priority = 4

        var keckResource = OCKTask(
            id: TaskID.keckResource,
            title: "Open Keck Medicine",
            carePlanUUID: nil,
            schedule: stretchSchedule
        )
        keckResource.impactsAdherence = false
        keckResource.instructions = "Open the Keck Medicine thyroidectomy page for recovery guidance."
        keckResource.asset = "safari"
        keckResource.card = .link
        keckResource.linkURL = Constants.defaultRecoveryResourceURL

        var removedTaskQuery = OCKTaskQuery(for: Date())
        removedTaskQuery.ids = [TaskID.kegels]
        if let removedTask = try await fetchTasks(query: removedTaskQuery).first {
            _ = try await deleteTask(removedTask)
        }

        let symptomTracking = createSymptomTrackingSurveyTask(carePlanUUID: nil)
        let symptomTrackingWeekly = createSymptomTrackingWeeklySurveyTask(carePlanUUID: nil)
        _ = try await addTasksIfNotPresent(
            [
                onboard,
                nausea,
                doxylamine,
                walking,
                neckMobility,
                stretch,
                keckResource,
                symptomTracking,
                symptomTrackingWeekly
            ]
        )

        var contact1 = OCKContact(
            id: "jane",
            givenName: "Jane",
            familyName: "Daniels",
            carePlanUUID: nil
        )
        contact1.title = "Endocrine Surgeon"
        contact1.role = "Dr. Daniels manages post-thyroid-surgery follow-up and recovery planning."
        contact1.emailAddresses = [OCKLabeledValue(label: CNLabelEmailiCloud, value: "janedaniels@uky.edu")]
        contact1.phoneNumbers = [OCKLabeledValue(label: CNLabelWork, value: "(800) 257-2000")]
        contact1.messagingNumbers = [OCKLabeledValue(label: CNLabelWork, value: "(800) 357-2040")]
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
            id: "matthew",
            givenName: "Matthew",
            familyName: "Reiff",
            carePlanUUID: nil
        )
        contact2.title = "Speech-Language Pathologist"
        contact2.role = "Dr. Reiff supports voice and swallowing recovery after thyroid surgery."
        contact2.phoneNumbers = [OCKLabeledValue(label: CNLabelWork, value: "(800) 257-1000")]
        contact2.messagingNumbers = [OCKLabeledValue(label: CNLabelWork, value: "(800) 257-1234")]
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

    func createSymptomTrackingSurveyTask(carePlanUUID: UUID?) -> OCKTask {
            let symptomTrackingTaskId = TaskID.symptomTracking
            let thisMorning = Calendar.current.startOfDay(for: Date())
            let aFewDaysAgo = Calendar.current.date(byAdding: .day, value: -4, to: thisMorning)!
            let beforeBreakfast = Calendar.current.date(byAdding: .hour, value: 8, to: aFewDaysAgo)!
            let symptomTrackingElement = OCKScheduleElement(
                start: beforeBreakfast,
                end: nil,
                interval: DateComponents(day: 1)
            )
            let symptomTrackingSchedule = OCKSchedule(
                composing: [symptomTrackingElement]
            )
            let textChoiceYesText = String(localized: "ANSWER_YES")
            let textChoiceNoText = String(localized: "ANSWER_NO")
            let yesValue = "Yes"
            let noValue = "No"
            let choices: [TextChoice] = [
                .init(
                    id: "\(symptomTrackingTaskId)_0",
                    choiceText: textChoiceYesText,
                    value: yesValue
                ),
                .init(
                    id: "\(symptomTrackingTaskId)_1",
                    choiceText: textChoiceNoText,
                    value: noValue
                )

            ]
            let questionOne = SurveyQuestion(
                id: "\(symptomTrackingTaskId)-neck-pain",
                type: .multipleChoice,
                required: true,
                title: String(localized: "SYMPTOM_TRACKING_NECK_PAIN"),
                textChoices: choices,
                choiceSelectionLimit: .single
            )

            let questionTwo = SurveyQuestion(
                id: "\(symptomTrackingTaskId)-voice",
                type: .slider,
                required: true,
                title: String(localized: "SYMPTOM_TRACKING_VOICE"),
                detail: String(localized: "SYMPTOM_TRACKING_LEVEL"),
                integerRange: 0...10,
                sliderStepValue: 1
            )

            let questionThree = SurveyQuestion(
                id: "\(symptomTrackingTaskId)-fatigue",
                type: .slider,
                required: true,
                title: String(localized: "SYMPTOM_TRACKING_FATIGUE_LEVEL"),
                detail: String(localized: "SYMPTOM_TRACKING_LEVEL"),
                integerRange: 0...10,
                sliderStepValue: 1
            )

            let questionFour = SurveyQuestion(
                id: "\(symptomTrackingTaskId)-swallowing",
                type: .slider,
                required: true,
                title: String(localized: "SYMPTOM_TRACKING_SWALLOWING_DIFFICULTY"),
                detail: String(localized: "SYMPTOM_TRACKING_LEVEL"),
                integerRange: 0...10,
                sliderStepValue: 1
            )

            let questionFive = SurveyQuestion(
                id: "\(symptomTrackingTaskId)-temp",
                type: .text,
                required: false,
                title: String(localized: "SYMPTOM_TRACKING_TEMP"),

            )

            let questionSix = SurveyQuestion(
                id: "\(symptomTrackingTaskId)-meds",
                type: .text,
                required: true,
                title: String(localized: "SYMPTOM_TRACKING_MEDICHINE"),

            )

            let questions = [questionOne, questionTwo, questionThree, questionFour, questionFive, questionSix]
            let stepOne = SurveyStep(
                id: "\(symptomTrackingTaskId)-step-1",
                questions: questions
            )

            var symptomTracking = OCKTask(
                id: "\(symptomTrackingTaskId)-stress",
                title: String(localized: "SYMPTOM_TRACKING"),
                carePlanUUID: carePlanUUID,
                schedule: symptomTrackingSchedule
            )
            symptomTracking.impactsAdherence = true
            symptomTracking.asset = "brain.head.profile"
            symptomTracking.card = .survey
            symptomTracking.surveySteps = [stepOne]
            symptomTracking.priority = 1

            return symptomTracking
        }

    func createSymptomTrackingWeeklySurveyTask(carePlanUUID: UUID?) -> OCKTask {
            let weeklyEvaluationTaskId = TaskID.WeeklyEvaluation
            // let thisMorning = Calendar.current.startOfDay(for: Date())
            // let aFewDaysAgo = Calendar.current.date(byAdding: .day, value: -4, to: thisMorning)!
            // let beforeBreakfast = Calendar.current.date(byAdding: .hour, value: 8, to: aFewDaysAgo)!
            let weeklyEvaluationElement = OCKScheduleElement(
                start: Date(),
                end: nil,
                interval: DateComponents(day: 1)
            )
            let weeklyEvaluationSchedule = OCKSchedule(
                composing: [weeklyEvaluationElement]
            )

            // let textChoiceYesText = String(localized: "ANSWER_YES")
            // let textChoiceNoText = String(localized: "ANSWER_NO")
            let textChoiceOnlineConsultationText = String(localized: "ANSWER_ONLINE_CONSULTATION")
            let textChoiceFollowUpVisitText = String(localized: "ANSWER_FOLLOW_UP_VISIT")
            let textChoicePhoneText = String(localized: "ANSWER_PHONE")
            let textChoiceRecurrenceText = String(localized: "ANSWER_RECURRENCE")
            let textChoiceVoiceChangesText = String(localized: "ANSWER_VOICE_CHANGES")
            let textChoiceSleepText = String(localized: "ANSWER_SLEEP")
            let textChoicePainText = String(localized: "ANSWER_PAIN")
            let textChoiceNoneText = String(localized: "ANSWER_NONE")
            let textChoiceComplicationFeverText = String(localized: "ANSWER_COMPLICATION_FEVER")
            let textChoiceComplicationCoughText = String(localized: "ANSWER_COMPLICATION_COUGH")
            let textChoiceComplicationBreathDiffText = String(localized: "ANSWER_COMPLICATION_BREATH_DIFFICULTY")
            let textChoiceComplicationSeverePainText = String(localized: "ANSWER_COMPLICATION_SEVERE_PAIN")

            // let yesValue = "Yes"
            // let noValue = "No"
            let onlineConsultationValue = "Online Consultation"
            let followUpVisitValue = "Follow-up Visit"
            let phoneValue = "Phone"
            let recurrenceValue = "Recurrence"
            let voiceChangesValue = "Voice Changes"
            let sleepValue = "Sleep"
            let painValue = "Pain"
            let complicationFeverValue = "Fever"
            let complicationCoughValue = "Cough"
            let complicationBreathingDifficultyValue = "Breathing Difficulty"
            let complicationSeverePainValue = "Severe Pain"
            let noneValue = "None of the Above"
            let distressChoices: [TextChoice] = [
                .init(
                    id: "\(weeklyEvaluationTaskId)_0",
                    choiceText: textChoiceRecurrenceText,
                    value: recurrenceValue
                ),

                .init(
                    id: "\(weeklyEvaluationTaskId)_1",
                    choiceText: textChoiceVoiceChangesText,
                    value: voiceChangesValue
                ),

                .init(
                    id: "\(weeklyEvaluationTaskId)_2",
                    choiceText: textChoicePainText,
                    value: painValue
                ),
                .init(
                    id: "\(weeklyEvaluationTaskId)_3",
                    choiceText: textChoiceSleepText,
                    value: sleepValue
                ),
                .init(
                    id: "\(weeklyEvaluationTaskId)_4",
                    choiceText: textChoiceNoneText,
                    value: noneValue
                )

            ]
            let consulationChoices: [TextChoice] = [
                .init(
                    id: "\(weeklyEvaluationTaskId)_5",
                    choiceText: textChoiceOnlineConsultationText,
                    value: onlineConsultationValue
                ),

                .init(
                    id: "\(weeklyEvaluationTaskId)_6",
                    choiceText: textChoicePhoneText,
                    value: phoneValue
                ),

                .init(
                    id: "\(weeklyEvaluationTaskId)_7",
                    choiceText: textChoiceFollowUpVisitText,
                    value: followUpVisitValue
                ),

                .init(
                    id: "\(weeklyEvaluationTaskId)_8",
                    choiceText: textChoiceNoneText,
                    value: noneValue
                )

            ]
            /*
            let choices: [TextChoice] = [
                .init(
                    id: "\(weeklyEvaluationTaskId)_9",
                    choiceText: textChoiceYesText,
                    value: yesValue
                ),
                .init(
                    id: "\(weeklyEvaluationTaskId)_10",
                    choiceText: textChoiceNoText,
                    value: noValue
                )

            ]*/
            let complicationChoices: [TextChoice] = [
                .init(
                    id: "\(weeklyEvaluationTaskId)_11",
                    choiceText: textChoiceComplicationFeverText,
                    value: complicationFeverValue
                ),
                .init(
                    id: "\(weeklyEvaluationTaskId)_12",
                    choiceText: textChoiceComplicationCoughText,
                    value: complicationCoughValue
                ),
                .init(
                    id: "\(weeklyEvaluationTaskId)_13",
                    choiceText: textChoiceComplicationBreathDiffText,
                    value: complicationBreathingDifficultyValue
                ),
                .init(
                    id: "\(weeklyEvaluationTaskId)_14",
                    choiceText: textChoiceComplicationSeverePainText,
                    value: complicationSeverePainValue
                ),
                .init(
                    id: "\(weeklyEvaluationTaskId)_15",
                    choiceText: textChoiceNoneText,
                    value: noneValue
                )
            ]

            let questionOne = SurveyQuestion(
                id: "\(weeklyEvaluationTaskId)-daily-activities",
                type: .slider,
                required: true,
                title: String(localized: "WEEKLY_EVALUATION_DAILY_ACTIVITY"),
                detail: String(localized: "WEEKLY_EVALUATION_LEVEL"),
                integerRange: 0...10,
                sliderStepValue: 1
            )

            let questionTwo = SurveyQuestion(
                id: "\(weeklyEvaluationTaskId)-sleep-quality",
                type: .slider,
                required: true,
                title: String(localized: "WEEKLY_EVALUATION_SLEEP_QUALITY"),
                detail: String(localized: "WEEKLY_EVALUATION_LEVEL"),
                integerRange: 0...10,
                sliderStepValue: 1
            )

            let questionThree = SurveyQuestion(
                id: "\(weeklyEvaluationTaskId)-appetite",
                type: .slider,
                required: true,
                title: String(localized: "WEEKLY_EVALUATION_APPETITE"),
                detail: String(localized: "WEEKLY_EVALUATION_LEVEL"),
                integerRange: 0...10,
                sliderStepValue: 1
            )

            let questionFour = SurveyQuestion(
                id: "\(weeklyEvaluationTaskId)-weight",
                type: .weight,
                required: true,
                title: String(localized: "WEEKLY_EVALUATION_WEIGHT"),
            )
            let questionFive = SurveyQuestion(
                id: "\(weeklyEvaluationTaskId)-distress",
                type: .slider,
                required: true,
                title: String(localized: "WEEKLY_EVALUATION_PSYCHOLOGICAL_DISTRESS"),
                detail: String(localized: "WEEKLY_EVALUATION_PSYCHOLOGICAL_DISTRESS_LEVEL"),
                integerRange: 0...10,
                sliderStepValue: 1
            )
            let questionSix = SurveyQuestion(
                id: "\(weeklyEvaluationTaskId)-distress-factors",
                type: .multipleChoice,
                required: false,
                title: String(localized: "WEEKLY_EVALUATION_PSYCHOLOGICAL_DISTRESS_FACTORS"),
                textChoices: distressChoices,
                choiceSelectionLimit: .multiple
            )
            let questionSeven = SurveyQuestion(
                id: "\(weeklyEvaluationTaskId)-family-communication",
                type: .slider,
                required: true,
                title: String(localized: "WEEKLY_EVALUATION_FAMILY_COMMUNICATION"),
                detail: String(localized: "WEEKLY_EVALUATION_FAMILY_COMMUNICATION_LEVEL"),
                integerRange: 0...5,
                sliderStepValue: 1
            )
            let questionEight = SurveyQuestion(
                id: "\(weeklyEvaluationTaskId)-medical-communication",
                type: .multipleChoice,
                required: true,
                title: String(localized: "WEEKLY_EVALUATION_MEDICAL_COMMUNICATION"),
                textChoices: consulationChoices,
                choiceSelectionLimit: .single
            )

            let questionNine = SurveyQuestion(
                id: "\(weeklyEvaluationTaskId)-complication-symptoms",
                type: .multipleChoice,
                required: true,
                title: String(localized: "WEEKLY_EVALUATION_COMPLICATION_SYMPTOMS"),
                textChoices: complicationChoices,
                choiceSelectionLimit: .multiple
            )

            let questionTen = SurveyQuestion(
                id: "\(weeklyEvaluationTaskId)-complication-dates",
                type: .dateTime,
                required: false,
                title: String(localized: "WEEKLY_EVALUATION_COMPLICATION_DATE"),
                dateRange: getPastWeekRange()
            )

            let questions1 = [questionOne, questionTwo, questionThree, questionFour]
            let stepOne = SurveyStep(
                id: "\(weeklyEvaluationTaskId)-step-1",
                questions: questions1
            )
            let questions2 = [questionFive, questionSix, questionSeven, questionEight, questionNine, questionTen]
            let stepTwo = SurveyStep(
                id: "\(weeklyEvaluationTaskId)-step-2",
                questions: questions2
            )
            var weeklyEvaluation = OCKTask(
                id: "\(weeklyEvaluationTaskId)-weeklyEvaluation",
                title: String(localized: "Weekly Evaluation"),
                carePlanUUID: carePlanUUID,
                schedule: weeklyEvaluationSchedule
            )
            weeklyEvaluation.impactsAdherence = true
            weeklyEvaluation.asset = "brain.head.profile"
            weeklyEvaluation.card = .survey
            weeklyEvaluation.surveySteps = [stepOne, stepTwo]
            weeklyEvaluation.priority = 1

            return weeklyEvaluation
        }
    func getPastWeekRange() -> ClosedRange<Date> {
        let calendar = Calendar.current
        let endDate = Date()  // today as the upper bound
        let startDate = calendar.date(byAdding: .day, value: -6, to: endDate)!  // 6 days ago (total 7 days)

        return startDate...endDate
    }

}
