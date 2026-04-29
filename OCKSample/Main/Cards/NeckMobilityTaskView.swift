//
//  NeckMobilityTaskView.swift
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

#if canImport(ResearchKitActiveTask)
import ResearchKitActiveTask
#endif

struct NeckMobilityTaskView: CareKitEssentialView {
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
            NeckMobilitySheetView(
                event: event,
                isPresented: $isPresentingTask
            )
        }
    }
}

#if !os(watchOS)
extension NeckMobilityTaskView: EventViewable {
    public init?(event: OCKAnyEvent, store: any OCKAnyStoreProtocol) {
        self.init(event: event)
    }
}
#endif

#if canImport(ResearchKit) && canImport(ResearchKitUI)
private struct NeckMobilitySheetView: CareKitEssentialView {
    @Environment(\.careStore) var store
    @Environment(\.dismiss) private var dismiss

    let event: OCKAnyEvent
    @Binding var isPresented: Bool

    var body: some View {
        NeckMobilityTaskController(
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
                dismissSheet()
            } catch {
                Logger.feed.error("Could not save neck mobility outcome: \(error)")
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

private struct NeckMobilityTaskController: UIViewControllerRepresentable {
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
        taskViewController.outputDirectory = FileManager.default.temporaryDirectory
        return taskViewController
    }

    func updateUIViewController(_ uiViewController: ORKTaskViewController, context: Context) {}

    private func makeTask() -> ORKOrderedTask {
        let introductionStep = ORKInstructionStep(identifier: "neckMobility.introduction")
        introductionStep.iconImage = UIImage(systemName: "heart.fill")
        introductionStep.title = "Neck Mobility Check"
        introductionStep.text = "This activity guides a gentle neck mobility check during recovery."
        introductionStep.detailText = """
        1. Sit upright with your shoulders relaxed.
        2. Keep every movement slow and pain-free.
        3. Stop if you feel sharp pain, dizziness, or breathing discomfort.
        4. Tap Get Started when you are ready.
        """

        let preparationStep = ORKInstructionStep(identifier: "neckMobility.preparation")
        preparationStep.iconImage = UIImage(systemName: "arrow.left.and.right.circle")
        preparationStep.title = "Neck Mobility Check"
        preparationStep.text = "Get ready to move gently through a comfortable range."
        preparationStep.detailText = """
        Slowly turn your head left, return to center, then turn right.
        Then gently tilt each ear toward your shoulder.
        When you tap Begin, the app will record motion for a few seconds.
        """

        let measurementStep = ORKActiveStep(identifier: "neckMobility.measurement")
        measurementStep.iconImage = UIImage(systemName: "arrow.up.and.down.circle")
        measurementStep.title = "Neck Mobility Check"
        measurementStep.text = "Move slowly through a comfortable range until the timer ends."
        measurementStep.stepDuration = 10
        measurementStep.shouldShowDefaultTimer = true
        measurementStep.shouldStartTimerAutomatically = true
        measurementStep.shouldContinueOnFinish = true
        measurementStep.recorderConfigurations = [
            ORKDeviceMotionRecorderConfiguration(
                identifier: "neckMobility.motion",
                frequency: 100
            )
        ]

        let completionStep = ORKCompletionStep(identifier: "neckMobility.completion")
        completionStep.iconImage = UIImage(systemName: "checkmark.circle.fill")
        completionStep.title = "All done!"
        completionStep.text = "You completed today's neck mobility check."

        return ORKOrderedTask(
            identifier: TaskID.neckMobility,
            steps: [
                introductionStep,
                preparationStep,
                measurementStep,
                completionStep
            ]
        )
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

                if stepIdentifier == "neckMobility.introduction" {
                    stepViewController.continueButtonTitle = "Get Started"
                } else if stepIdentifier == "neckMobility.preparation" {
                    stepViewController.continueButtonTitle = "Begin"
                } else if stepIdentifier == "neckMobility.completion" {
                    stepViewController.continueButtonTitle = "Done"
                }
            }
        }
    }
}
#else
private struct NeckMobilitySheetView: View {
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
