//
//  MyCustomCardView.swift
//  OCKSample
//
//  Created by Richard Zhou on 3/16/26.
//  Copyright © 2026 Network Reconnaissance Lab. All rights reserved.
//
import CareKit
import CareKitEssentials
import CareKitStore
import CareKitUI
import os.log
import SwiftUI

struct MyCustomCardView: CareKitEssentialView {
    @Environment(\.careStore) var store
    @Environment(\.customStyler) var style
    @Environment(\.isCardEnabled) private var isCardEnabled

    let event: OCKAnyEvent
    @StateObject private var viewModel = MyCustomCardViewModel()

    var body: some View {
        CardView {
            VStack(alignment: .leading, spacing: 16) {
                header
                notePreview
                editButton
            }
            .padding(isCardEnabled ? .all : [])
        }
        .careKitStyle(style)
        .frame(maxWidth: .infinity)
        .padding(.vertical)
        .sheet(isPresented: $viewModel.isPresentingEditor) {
            noteEditor
        }
    }

    private var header: some View {
        HStack(alignment: .top, spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color.accentColor.opacity(0.16))
                    .frame(width: 52, height: 52)
                Image(systemName: "text.bubble.fill")
                    .font(.title2.weight(.semibold))
                    .foregroundColor(.accentColor)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text(event.title)
                    .font(.headline)
                event.instructionsText
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    @ViewBuilder
    private var notePreview: some View {
        if let savedNote {
            VStack(alignment: .leading, spacing: 8) {
                Label("Today's note", systemImage: "quote.bubble.fill")
                    .font(.caption.weight(.semibold))
                    .foregroundColor(.accentColor)
                Text(savedNote)
                    .font(.body)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(14)
            .background(Color.accentColor.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        } else {
            HStack(spacing: 10) {
                Image(systemName: "square.and.pencil")
                    .foregroundColor(.accentColor)
                Text("No note yet. Add a short recovery update for today.")
                    .foregroundColor(.secondary)
            }
            .font(.subheadline)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(14)
            .background(Color.secondary.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
    }

    private var editButton: some View {
        Button {
            viewModel.startEditing(currentNote: savedNote)
        } label: {
            RectangularCompletionView(isComplete: savedNote != nil) {
                HStack {
                    Spacer()
                    Image(systemName: savedNote == nil ? "plus.bubble.fill" : "pencil")
                    Text(savedNote == nil ? "Add Recovery Note" : "Edit Recovery Note")
                        .fontWeight(.semibold)
                    Spacer()
                }
                .foregroundColor(savedNote == nil ? .white : .accentColor)
                .padding()
            }
        }
        .buttonStyle(NoHighlightStyle())
        .disabled(!isCardEnabled)
        .opacity(isCardEnabled ? 1 : 0.55)
    }

    private var noteEditor: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Recovery Note")
                .font(.title2.bold())

            Text("Write one short sentence about your voice, swallowing, or energy today.")
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            TextField("Example: Voice feels stronger today.", text: $viewModel.draftNote)
                .padding(12)
                .background(Color.secondary.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

            if let errorMessage = viewModel.errorMessage {
                Text(errorMessage)
                    .font(.footnote)
                    .foregroundColor(.red)
            }

            HStack(spacing: 12) {
                Button("Cancel") {
                    viewModel.isPresentingEditor = false
                }
                .frame(maxWidth: .infinity)

                Button("Save") {
                    saveNote()
                }
                .padding(.vertical, 10)
                .frame(maxWidth: .infinity)
                .background(Color.accentColor)
                .foregroundColor(.white)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            }
        }
        .padding(24)
    }

    private var savedNote: String? {
        viewModel.savedNote(from: event)
    }

    private func saveNote() {
        guard let note = viewModel.validatedNote() else {
            return
        }

        Task { @MainActor in
            do {
                let updatedOutcome = try await saveOutcomeValues(
                    [OCKOutcomeValue(note)],
                    event: event
                )
                Logger.myCustomCardView.info("Saved recovery note: \(updatedOutcome.values)")
                viewModel.isPresentingEditor = false
            } catch {
                Logger.myCustomCardView.info("Error saving recovery note: \(error)")
                viewModel.errorMessage = "Could not save this note. Please try again."
            }
        }
    }
}

private final class MyCustomCardViewModel: ObservableObject {
    @Published var draftNote = ""
    @Published var errorMessage: String?
    @Published var isPresentingEditor = false

    func startEditing(currentNote: String?) {
        draftNote = currentNote ?? ""
        errorMessage = nil
        isPresentingEditor = true
    }

    func savedNote(from event: OCKAnyEvent) -> String? {
        let note = event.outcome?.values.compactMap { value in
            (value.value as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        .last

        guard let note, !note.isEmpty else {
            return nil
        }
        return note
    }

    func validatedNote() -> String? {
        let note = draftNote.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !note.isEmpty else {
            errorMessage = "Please enter a note before saving."
            return nil
        }
        return note
    }
}

struct ComfortScoreCardView: CareKitEssentialView {
    @Environment(\.careStore) var store
    @Environment(\.customStyler) var style
    @Environment(\.isCardEnabled) private var isCardEnabled

    let event: OCKAnyEvent
    @StateObject private var viewModel = ComfortScoreCardViewModel()

    var body: some View {
        CardView {
            VStack(alignment: .leading, spacing: 16) {
                scoreHeader
                scoreSummary
                scoreControl
                saveScoreButton
            }
            .padding(isCardEnabled ? .all : [])
        }
        .careKitStyle(style)
        .frame(maxWidth: .infinity)
        .padding(.vertical)
        .onAppear {
            viewModel.loadSavedScore(from: event)
        }
    }

    private var scoreHeader: some View {
        HStack(alignment: .top, spacing: 14) {
            ZStack {
                Circle()
                    .fill(scoreColor.opacity(0.16))
                    .frame(width: 56, height: 56)
                Image(systemName: "gauge")
                    .font(.title2.weight(.semibold))
                    .foregroundColor(scoreColor)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text(event.title)
                    .font(.headline)
                event.instructionsText
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var scoreSummary: some View {
        HStack(alignment: .center, spacing: 14) {
            Text("\(viewModel.score)")
                .font(.system(size: 44, weight: .bold, design: .rounded))
                .foregroundColor(scoreColor)
                .frame(width: 64)

            VStack(alignment: .leading, spacing: 4) {
                Text(scoreLabel)
                    .font(.headline)
                Text(savedScoreText)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            Spacer()
        }
        .padding(14)
        .background(scoreColor.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private var scoreControl: some View {
        Stepper(value: $viewModel.score, in: 0...10) {
            Text("Adjust comfort score")
                .font(.subheadline.weight(.semibold))
        }
        .disabled(!isCardEnabled)
    }

    private var saveScoreButton: some View {
        Button {
            saveScore()
        } label: {
            RectangularCompletionView(isComplete: viewModel.savedScore != nil) {
                HStack {
                    Spacer()
                    Image(systemName: "checkmark.circle.fill")
                    Text(viewModel.savedScore == nil ? "Save Comfort Score" : "Update Comfort Score")
                        .fontWeight(.semibold)
                    Spacer()
                }
                .foregroundColor(viewModel.savedScore == nil ? .white : .accentColor)
                .padding()
            }
        }
        .buttonStyle(NoHighlightStyle())
        .disabled(!isCardEnabled)
        .opacity(isCardEnabled ? 1 : 0.55)
    }

    private var savedScoreText: String {
        guard let savedScore = viewModel.savedScore else {
            return "No score saved for today."
        }
        return "Saved score: \(savedScore) out of 10."
    }

    private var scoreLabel: String {
        switch viewModel.score {
        case 0...3:
            return "Needs attention"
        case 4...7:
            return "Manageable"
        default:
            return "Comfortable"
        }
    }

    private var scoreColor: Color {
        switch viewModel.score {
        case 0...3:
            return .red
        case 4...7:
            return .orange
        default:
            return .green
        }
    }

    private func saveScore() {
        Task { @MainActor in
            do {
                let updatedOutcome = try await saveOutcomeValues(
                    [OCKOutcomeValue(viewModel.score)],
                    event: event
                )
                viewModel.savedScore = viewModel.score
                Logger.myCustomCardView.info("Saved comfort score: \(updatedOutcome.values)")
            } catch {
                Logger.myCustomCardView.info("Error saving comfort score: \(error)")
            }
        }
    }
}

private final class ComfortScoreCardViewModel: ObservableObject {
    @Published var score = 5
    @Published var savedScore: Int?

    func loadSavedScore(from event: OCKAnyEvent) {
        guard let score = event.outcome?.values.compactMap(\.integerValue).last else {
            savedScore = nil
            return
        }
        self.score = score
        self.savedScore = score
    }
}

#if !os(watchOS)
extension MyCustomCardView: EventViewable {
    public init?(event: OCKAnyEvent, store: any OCKAnyStoreProtocol) {
        self.init(event: event)
    }
}

extension ComfortScoreCardView: EventViewable {
    public init?(event: OCKAnyEvent, store: any OCKAnyStoreProtocol) {
        self.init(event: event)
    }
}
#endif

struct MyCustomCardView_Previews: PreviewProvider {
    static var store = Utility.createPreviewStore()

    static var query: OCKEventQuery {
        var query = OCKEventQuery(for: Date())
        query.taskIDs = [TaskID.recoveryNote]
        return query
    }

    static var previews: some View {
        VStack {
            @CareStoreFetchRequest(query: query) var events
            if let event = events.latest.first {
                MyCustomCardView(event: event.result)
            }
        }
        .environment(\.careStore, store)
        .padding()
    }
}
