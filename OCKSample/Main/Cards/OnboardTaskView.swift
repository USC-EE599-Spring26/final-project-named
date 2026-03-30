//
//  OnboardTaskView.swift
//  OCKSample
//
//  Created by Yulin on 3/22/26.
//

import CareKit
import CareKitEssentials
import CareKitStore
import CareKitUI
import os.log
import SwiftUI

#if canImport(ResearchKit)
import ResearchKit
#endif

#if canImport(ResearchKitUI)
import ResearchKitUI
#endif

#if canImport(HealthKit)
import HealthKit
#endif

struct OnboardTaskView: CareKitEssentialView {
    @Environment(\.careStore) var store
    @Environment(\.customStyler) var style
    @Environment(\.isCardEnabled) private var isCardEnabled

    let event: OCKAnyEvent
    @State private var isPresentingTask = false

    var body: some View {
        CardView {
            VStack(alignment: .leading) {
                InformationHeaderView(
                    title: Text(event.title),
                    information: event.detailText,
                    event: event
                )

                event.instructionsText
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.vertical)

                Button(action: {
                    guard !event.isComplete else {
                        return
                    }
                    isPresentingTask = true
                }) {
                    RectangularCompletionView(isComplete: event.isComplete) {
                        HStack {
                            Spacer()
                            Text(event.isComplete ? "Completed" : "Begin")
                                .foregroundColor(event.isComplete ? .accentColor : .white)
                                .frame(maxWidth: .infinity)
                            Spacer()
                        }
                        .padding()
                    }
                }
                .buttonStyle(NoHighlightStyle())
            }
            .padding(isCardEnabled ? .all : [])
        }
        .careKitStyle(style)
        .frame(maxWidth: .infinity)
        .padding(.vertical)
        .sheet(isPresented: $isPresentingTask) {
            OnboardSheetView(
                event: event,
                isPresented: $isPresentingTask
            )
        }
    }
}

#if !os(watchOS)
extension OnboardTaskView: EventViewable {
    public init?(event: OCKAnyEvent, store: any OCKAnyStoreProtocol) {
        self.init(event: event)
    }
}
#endif

#if canImport(ResearchKit) && canImport(ResearchKitUI)
private struct OnboardSheetView: CareKitEssentialView {
    @Environment(\.careStore) var store
    @Environment(\.dismiss) private var dismiss

    let event: OCKAnyEvent
    @Binding var isPresented: Bool

    var body: some View {
        OnboardTaskController(
            onCompleted: handleCompleted,
            onCancelled: handleCancelled
        )
    }

    @MainActor
    private func handleCompleted() {
        Task {
            do {
                guard !event.isComplete else {
                    dismissSheet()
                    return
                }

                _ = try await saveOutcomeValues(
                    [OCKOutcomeValue(true)],
                    event: event
                )
                NotificationCenter.default.post(
                    name: .init(rawValue: Constants.shouldRefreshView),
                    object: nil
                )
                dismissSheet()
            } catch {
                Logger.feed.error("Could not save onboard outcome: \(error)")
                dismissSheet()
            }
        }
    }

    @MainActor
    private func handleCancelled() {
        dismissSheet()
    }

    private func dismissSheet() {
        isPresented = false
        dismiss()
    }
}

private struct OnboardTaskController: UIViewControllerRepresentable {
    let onCompleted: @MainActor @Sendable () -> Void
    let onCancelled: @MainActor @Sendable () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(
            onCompleted: onCompleted,
            onCancelled: onCancelled
        )
    }

    func makeUIViewController(context: Context) -> ORKTaskViewController {
        let taskViewController = ORKTaskViewController(
            task: makeTask(),
            taskRun: nil
        )
        taskViewController.delegate = context.coordinator
        return taskViewController
    }

    func updateUIViewController(_ uiViewController: ORKTaskViewController, context: Context) {}

    private func makeTask() -> ORKOrderedTask {
        let welcomeStep = ORKInstructionStep(identifier: "onboard.welcome")
        welcomeStep.iconImage = UIImage(systemName: "hand.wave.fill")
        welcomeStep.title = "Welcome!"
        welcomeStep.detailText = "Thank you for joining our study. Tap Next to learn more before signing up."

        let beforeYouJoinStep = ORKInstructionStep(identifier: "onboard.beforeYouJoin")
        beforeYouJoinStep.iconImage = UIImage(systemName: "checkmark.seal.fill")
        beforeYouJoinStep.title = "Before You Join"
        beforeYouJoinStep.bodyItems = [
            ORKBodyItem(
                text: "The study will ask you to share some of your health data.",
                detailText: nil,
                image: UIImage(systemName: "heart.fill"),
                learnMoreItem: nil,
                bodyItemStyle: .image,
                useCardStyle: false,
                alignImageToTop: true
            ),
            ORKBodyItem(
                text: "You will be asked to complete various tasks over the duration of the study.",
                detailText: nil,
                image: UIImage(systemName: "checkmark.circle.fill"),
                learnMoreItem: nil,
                bodyItemStyle: .image,
                useCardStyle: false,
                alignImageToTop: true
            ),
            ORKBodyItem(
                text: "Before joining, we will ask you to sign an informed consent document.",
                detailText: nil,
                image: UIImage(systemName: "signature"),
                learnMoreItem: nil,
                bodyItemStyle: .image,
                useCardStyle: false,
                alignImageToTop: true
            ),
            ORKBodyItem(
                text: "Your data is kept private and secure.",
                detailText: nil,
                image: UIImage(systemName: "lock.fill"),
                learnMoreItem: nil,
                bodyItemStyle: .image,
                useCardStyle: false,
                alignImageToTop: true
            )
        ]

        let informedConsentStep = ORKInstructionStep(identifier: "onboard.informedConsent")
        informedConsentStep.iconImage = UIImage(systemName: "doc.text.fill")
        informedConsentStep.title = "Informed Consent"
        informedConsentStep.detailText = """
        Study Expectations

        • You will be asked to complete surveys and recovery tasks.
        • The study may send reminders to help you stay on track.
        • Your information will be kept private and secure.
        • You may withdraw from the study at any time.

        Eligibility Requirements

        • Must be 18 years or older.
        • Must be able to read and understand English.
        • Must be the only user of this device.
        """

        let requestPermissionsStep = ORKRequestPermissionsStep(
            identifier: "onboard.permissions",
            permissionTypes: makePermissionTypes()
        )
        requestPermissionsStep.title = "Health Data Request"
        requestPermissionsStep.text = "Please review the permissions below before continuing."
        requestPermissionsStep.useExtendedPadding = false

        let completionStep = ORKCompletionStep(identifier: "onboard.completion")
        completionStep.iconImage = UIImage(systemName: "checkmark.circle.fill")
        completionStep.title = "Enrollment Complete"
        completionStep.text =
            "Thank you for enrolling in this study. " +
            "Your participation will contribute to meaningful research!"

        return ORKOrderedTask(
            identifier: TaskID.onboard,
            steps: [
                welcomeStep,
                beforeYouJoinStep,
                informedConsentStep,
                requestPermissionsStep,
                completionStep
            ]
        )
    }

    private func makePermissionTypes() -> [ORKPermissionType] {
        var permissionTypes: [ORKPermissionType] = [
            ORKNotificationPermissionType(authorizationOptions: [.alert, .badge, .sound])
        ]

#if canImport(HealthKit)
        let healthKitTypesToRead: Set<HKObjectType> = [
            HKObjectType.quantityType(forIdentifier: .stepCount)!,
            HKObjectType.quantityType(forIdentifier: .restingHeartRate)!
        ]
        let healthKitPermissionType = ORKHealthKitPermissionType(
            sampleTypesToWrite: nil,
            objectTypesToRead: healthKitTypesToRead
        )
        permissionTypes.append(healthKitPermissionType)
#endif

        return permissionTypes
    }

    final class Coordinator: NSObject, ORKTaskViewControllerDelegate {
        let onCompleted: @MainActor @Sendable () -> Void
        let onCancelled: @MainActor @Sendable () -> Void

        init(
            onCompleted: @escaping @MainActor @Sendable () -> Void,
            onCancelled: @escaping @MainActor @Sendable () -> Void
        ) {
            self.onCompleted = onCompleted
            self.onCancelled = onCancelled
        }

        func taskViewController(
            _ taskViewController: ORKTaskViewController,
            didFinishWith reason: ORKTaskFinishReason,
            error: Error?
        ) {
            let onCompleted = self.onCompleted
            let onCancelled = self.onCancelled
            MainActor.assumeIsolated {
                if reason == .completed {
                    onCompleted()
                } else {
                    onCancelled()
                }
            }
        }

        func taskViewController(
            _ taskViewController: ORKTaskViewController,
            stepViewControllerWillAppear stepViewController: ORKStepViewController
        ) {
            MainActor.assumeIsolated {
                guard let stepIdentifier = stepViewController.step?.identifier else {
                    return
                }

                if stepIdentifier == "onboard.welcome" {
                    stepViewController.continueButtonTitle = "Next"
                } else if stepIdentifier == "onboard.beforeYouJoin" {
                    stepViewController.continueButtonTitle = "Get Started"
                } else if stepIdentifier == "onboard.informedConsent" {
                    stepViewController.continueButtonTitle = "Next"
                } else if stepIdentifier == "onboard.completion" {
                    stepViewController.continueButtonTitle = "Done"
                }
            }
        }
    }
}
#else
private struct OnboardSheetView: View {
    let event: OCKAnyEvent
    @Binding var isPresented: Bool

    var body: some View {
        VStack(spacing: 24) {
            Text(event.title)
                .font(.title2.bold())

            Text("ResearchKit is not available for this target.")
                .multilineTextAlignment(.center)

            Button("Close") {
                isPresented = false
            }
        }
        .padding()
    }
}
#endif
