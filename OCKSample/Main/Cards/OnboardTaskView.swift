//
//  OnboardTaskView.swift
//  OCKSample
//
//  Created by Richard Zhou on 3/23/26.
//  Copyright © 2026 Network Reconnaissance Lab. All rights reserved.
//

import CareKit
import CareKitEssentials
import CareKitStore
import CareKitUI
import os.log
import SwiftUI

#if canImport(UIKit)
import UIKit
#endif

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

                Button {
                    isPresentingTask = true
                } label: {
                    RectangularCompletionView(isComplete: false) {
                        HStack {
                            Spacer()
                            Text("Begin")
                                .foregroundColor(.white)
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
private struct OnboardSheetView: View {
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
                guard let appDelegate = AppDelegateKey.defaultValue else {
                    dismissSheet()
                    return
                }

                _ = try await appDelegate.storeCoordinator.deleteAnyTask(event.task)
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
        welcomeStep.detailText =
            "Thank you for joining. " +
            "Tap Next to review the onboarding information before you start."

        let consentSignatureStep = makeConsentSignatureStep()

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
                consentSignatureStep,
                requestPermissionsStep,
                completionStep
            ]
        )
    }

    private func makeConsentSignatureStep() -> ORKWebViewStep {
        let consentHTML = """
        <html>
        <head>
        <meta name="viewport" content="width=device-width, initial-scale=1.0">
        <style>
        body {
            font-family: -apple-system, BlinkMacSystemFont, sans-serif;
            padding: 12px 4px;
            color: #111111;
            line-height: 1.45;
        }
        h1 { font-size: 26px; margin: 0 0 20px 0; }
        h2 { font-size: 18px; margin: 22px 0 12px 0; }
        ul { margin: 0 0 18px 0; padding-left: 22px; }
        li { margin: 0 0 10px 0; }
        p { margin: 0 0 18px 0; }
        </style>
        </head>
        <body>
        <h1>Informed Consent</h1>
        <h2>Study Expectations</h2>
        <ul>
        <li>You will be asked to complete various study tasks such as surveys.</li>
        <li>The study will send you notifications to remind you to complete these study tasks.</li>
        <li>You will be asked to share various health data types to support the study goals.</li>
        <li>The study is expected to last 4 years.</li>
        <li>The study may reach out to you for future research opportunities.</li>
        <li>Your information will be kept private and secure.</li>
        <li>You can withdraw from the study at any time.</li>
        </ul>
        <h2>Eligibility Requirements</h2>
        <ul>
        <li>Must be 18 years or older.</li>
        <li>Must be able to read and understand English.</li>
        <li>Must be the only user of the device on which you are participating in the study.</li>
        <li>Must be able to sign your own consent form.</li>
        </ul>
        <p>
        By signing below, I acknowledge that I have read this consent carefully, that I understand
        all of its terms, and that I enter into this study voluntarily. I understand that my
        information will only be used and disclosed for the purposes described in the consent and I
        can withdraw from the study at any time.
        </p>
        <p>Please sign using your finger below.</p>
        </body>
        </html>
        """

        let consentSignatureStep = ORKWebViewStep(
            identifier: "onboard.signatureCapture",
            html: consentHTML
        )
        consentSignatureStep.title = "Informed Consent"
        consentSignatureStep.text = "Please review and sign the informed consent below."
        consentSignatureStep.showSignatureAfterContent = true
        return consentSignatureStep
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

        permissionTypes.append(ORKPermissionType.deviceMotionPermissionType())

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
