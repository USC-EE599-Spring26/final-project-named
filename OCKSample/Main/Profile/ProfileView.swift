//
//  ProfileView.swift
//  OCKSample
//
//  Created by Corey Baker on 11/24/20.
//  Copyright © 2020 Network Reconnaissance Lab. All rights reserved.
//

import CareKitUI
import CareKitStore
import CareKit
import os.log
import SwiftUI

struct ProfileView: View {
    private static var query = OCKPatientQuery(for: Date())
    @CareStoreFetchRequest(query: query) private var patients
    @StateObject private var viewModel = ProfileViewModel()
    @ObservedObject var loginViewModel: LoginViewModel
    @State var isPresentingAddTask = false
    @State var isPresentingDeleteTasks = false

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text("Profile")
                        .font(.system(size: 34, weight: .bold))
                        .padding(.top, 8)

                    VStack(spacing: 14) {
                        TextField("First Name",
                                  text: $viewModel.firstName)
                            .padding()
                            .background(Color.white)
                            .cornerRadius(16)

                        TextField("Last Name",
                                  text: $viewModel.lastName)
                            .padding()
                            .background(Color.white)
                            .cornerRadius(16)

                        DatePicker("Birthday",
                                   selection: $viewModel.birthday,
                                   displayedComponents: [DatePickerComponents.date])
                            .padding()
                            .background(Color.white)
                            .cornerRadius(16)
                    }
                    .padding(18)
                    .background(Color(red: 0.97, green: 0.95, blue: 0.90))
                    .cornerRadius(24)

                    Button(action: {
                        Task {
                            do {
                                try await viewModel.saveProfile()
                            } catch {
                                Logger.profile.error("Error saving profile: \(error)")
                            }
                        }
                    }, label: {
                        Text("Save Profile")
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity, minHeight: 52)
                    })
                    .background(Color(red: 0.74, green: 0.58, blue: 0.41))
                    .cornerRadius(18)

                    Button(action: {
                        Task {
                            await loginViewModel.logout()
                        }
                    }, label: {
                        Text("Log Out")
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity, minHeight: 52)
                    })
                    .background(Color(red: 0.82, green: 0.40, blue: 0.34))
                    .cornerRadius(18)

                    Button(action: {
                        isPresentingDeleteTasks = true
                    }, label: {
                        Text("Delete Tasks")
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity, minHeight: 52)
                    })
                    .background(Color(red: 0.62, green: 0.60, blue: 0.62))
                    .cornerRadius(18)
                    .sheet(isPresented: $isPresentingDeleteTasks) {
                        DeleteTasksView(isPresented: $isPresentingDeleteTasks)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 32)
            }
            .background(Color(red: 0.99, green: 0.97, blue: 0.93))
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        isPresentingAddTask = true
                    } label: {
                        Image(systemName: "plus")
                    }
                    .accessibilityLabel("Add Task")
                }
            }
            .sheet(isPresented: $isPresentingAddTask) {
                AddHealthKitTaskView(isPresented: $isPresentingAddTask)
            }
            .onAppear {
                if let patient = patients.first?.result {
                    viewModel.updatePatient(patient)
                }
            }
            .onChange(of: patients.count) { _, _ in
                if let patient = patients.first?.result {
                    viewModel.updatePatient(patient)
                }
            }
        }
    }
}

struct AddHealthKitTaskView: View {
    @Binding var isPresented: Bool
    private let viewModel = AddHealthKitTaskViewModel()
    @State private var title = ""
    @State private var instructions = ""
    @State private var linkURL = ""
    @State private var checkListItem=""
    @State private var scheduleStart = Date()
    @State private var selectedCard: CareKitCard = .numericProgress
    @State private var selectedAsset = "cross.case.fill"
    @State private var errorMessage: String?
    // Choose task type first, then update the allowed card options.
    @State private var selectedTaskType = "OCKHealthKitTask"

    var body: some View {
        NavigationView {
            Form {
                Section("Task") {
                    Picker("Task Type", selection: $selectedTaskType) {
                        Text("OCKTask").tag("OCKTask")
                        Text("OCKHealthKitTask").tag("OCKHealthKitTask")
                    } // User can choose which task type to create.
                    .onChange(of: selectedTaskType) { _, newValue in
                        if newValue == "OCKHealthKitTask" {
                            selectedCard = .numericProgress
                        } else {
                            selectedCard = .button
                        }
                    }
                    TextField("Title", text: $title)
                    TextField("Instructions", text: $instructions)
                    if selectedTaskType == "OCKTask" && selectedCard == .link {
                        TextField("Link URL", text: $linkURL)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .keyboardType(.URL)
                    }
                    if selectedTaskType == "OCKTask" && selectedCard == .checklist {
                       TextField("Checklist Item", text: $checkListItem)
                    }
                    DatePicker(
                        "Schedule",
                        selection: $scheduleStart,
                        displayedComponents: [.date, .hourAndMinute]
                    )
                    Picker("Card Type", selection: $selectedCard) {
                        if selectedTaskType == "OCKTask" {
                            Text(CareKitCard.button.rawValue).tag(CareKitCard.button)
                            Text(CareKitCard.checklist.rawValue).tag(CareKitCard.checklist)
                            Text(CareKitCard.featured.rawValue).tag(CareKitCard.featured)
                            Text(CareKitCard.grid.rawValue).tag(CareKitCard.grid)
                            Text(CareKitCard.instruction.rawValue).tag(CareKitCard.instruction)
                            Text(CareKitCard.link.rawValue).tag(CareKitCard.link)
                            Text(CareKitCard.simple.rawValue).tag(CareKitCard.simple)
                        } else {
                            Text(CareKitCard.numericProgress.rawValue).tag(CareKitCard.numericProgress)
                            Text(CareKitCard.labeledValue.rawValue).tag(CareKitCard.labeledValue)
                        }
                    }
                    Picker("Asset", selection: $selectedAsset) {
                        ForEach(
                            [
                                "cross.case.fill",
                                "heart.fill",
                                "pills.fill",
                                "waveform.path.ecg"
                            ],
                            id: \.self
                        ) { asset in
                            Text(asset)
                                .tag(asset)
                        }
                    }
                }
                if let errorMessage = errorMessage {
                    Section {
                        Text(errorMessage)
                            .foregroundStyle(.red)
                    }
                }
                Section {
                    Button("Save") {
                        saveTask()
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(Color(red: 0.99, green: 0.97, blue: 0.93))
            .navigationTitle("Add Task")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        isPresented = false
                    }
                }
            }
        }
    }

    private func normalizedHTTPURL(_ value: String) -> String? {
        guard let parsedURL = URL(string: value),
              let scheme = parsedURL.scheme?.lowercased(),
              scheme == "http" || scheme == "https" else {
            return nil
        }
        return value
    }

    private func saveTask() {
        let cleanTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanInstructions = instructions.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanTitle.isEmpty, !cleanInstructions.isEmpty else {
            errorMessage = "Please fill in Title and Instructions."
            return
        }

        errorMessage = nil
        if selectedTaskType == "OCKTask" {
            var cleanLinkURL: String?
            if selectedCard == .link {
                guard let validatedLinkURL = normalizedHTTPURL(
                    linkURL.trimmingCharacters(in: .whitespacesAndNewlines)
                ) else {
                    errorMessage = "Please enter a valid http(s) URL for Link card."
                    return
                }
                cleanLinkURL = validatedLinkURL
            }
            viewModel.saveRegularTask(
                title: cleanTitle,
                instructions: cleanInstructions,
                scheduleStart: scheduleStart,
                cardType: selectedCard,
                payload: .init(
                    assetName: selectedAsset,
                    linkURL: cleanLinkURL
                ),
                // assetName: selectedAsset
            )
        } else {
            viewModel.saveTask(
                title: cleanTitle,
                instructions: cleanInstructions,
                scheduleStart: scheduleStart,
                cardType: selectedCard,
                assetName: selectedAsset
            )
        }
        isPresented = false
    }
}

struct DeleteTasksView: View {
    @Binding var isPresented: Bool
    @StateObject private var viewModel = DeleteTasksViewModel()

    var body: some View {
        NavigationView {
            List {
                if let errorMessage = viewModel.errorMessage {
                    Text(errorMessage)
                        .foregroundStyle(.red)
                }

                if viewModel.tasks.isEmpty {
                    Text("No tasks to delete.")
                        .foregroundColor(.secondary)
                } else {
                    ForEach(viewModel.tasks, id: \.uuid) { task in
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(task.title ?? task.id)
                                    .font(.headline)
                                Text(task.id)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }

                            Spacer()

                            Button("Delete") {
                                Task {
                                    await viewModel.deleteTask(task)
                                }
                            }
                            .foregroundColor(.red)
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .background(Color(red: 0.99, green: 0.97, blue: 0.93))
            .navigationTitle("Delete Tasks")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        isPresented = false
                    }
                }
            }
            .task {
                await viewModel.loadTasks()
            }
        }
    }
}

struct ProfileView_Previews: PreviewProvider {
    static var previews: some View {
        ProfileView(loginViewModel: .init())
            .environment(\.careStore, Utility.createPreviewStore())
    }
}
