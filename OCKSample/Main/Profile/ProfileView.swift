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

    @CareStoreFetchRequest(query: query()) private var patients
    @StateObject private var viewModel = ProfileViewModel()
    @StateObject private var taskViewModel = TaskManagementViewModel()
    @ObservedObject var loginViewModel: LoginViewModel
    private let suggestedSymbols = [
        "checkmark.circle",
        "pills.fill",
        "pills.circle.fill",
        "cross.case.fill",
        "waveform.path.ecg",
        "heart.circle.fill",
        "figure.walk",
        "calendar.badge.clock",
        "mouth.fill",
        "bell.fill"
    ]

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                VStack(alignment: .leading) {
                    TextField(
                        "GIVEN_NAME",
                        text: $viewModel.firstName
                    )
                    .padding()
                    .cornerRadius(20.0)
                    .shadow(radius: 10.0, x: 20, y: 10)

                    TextField(
                        "FAMILY_NAME",
                        text: $viewModel.lastName
                    )
                    .padding()
                    .cornerRadius(20.0)
                    .shadow(radius: 10.0, x: 20, y: 10)

                    DatePicker(
                        "BIRTHDAY",
                        selection: $viewModel.birthday,
                        displayedComponents: [DatePickerComponents.date]
                    )
                    .padding()
                    .cornerRadius(20.0)
                    .shadow(radius: 10.0, x: 20, y: 10)
                }

                Button(action: {
                    Task {
                        do {
                            try await viewModel.saveProfile()
                        } catch {
                            Logger.profile.error("Error saving profile: \(error)")
                        }
                    }
                }, label: {
                    Text(
                        "SAVE_PROFILE"
                    )
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding()
                    .frame(width: 300, height: 50)
                })
                .background(Color(.green))
                .cornerRadius(15)

                taskManagementSection

                // Notice that "action" is a closure (which is essentially
                // a function as argument like we discussed in class)
                Button(action: {
                    Task {
                        await loginViewModel.logout()
                    }
                }, label: {
                    Text(
                        "LOG_OUT"
                    )
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding()
                    .frame(width: 300, height: 50)
                })
                .background(Color(.red))
                .cornerRadius(15)
            }
            .padding(.vertical, 12)
        }
        .onReceive(patients.publisher) { publishedPatient in
            viewModel.updatePatient(publishedPatient.result)
        }
        .task {
            await taskViewModel.refreshTasks()
        }
    }

    static func query() -> OCKPatientQuery {
        OCKPatientQuery(for: Date())
    }

    private var taskManagementSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Task Management")
                .font(.headline)

            TextField("Task title", text: $taskViewModel.title)
                .textFieldStyle(.roundedBorder)

            TextField("Instructions (optional)", text: $taskViewModel.instructions, axis: .vertical)
                .lineLimit(2...4)
                .textFieldStyle(.roundedBorder)

            VStack(alignment: .leading, spacing: 8) {
                Text("Task icon (SF Symbol)")
                    .font(.caption)
                    .foregroundColor(.secondary)

                HStack(spacing: 10) {
                    Image(systemName: safeSymbolName(taskViewModel.assetSymbol))
                        .font(.title3)
                        .frame(width: 26, height: 26)
                        .foregroundColor(.accentColor)

                    TextField("SF Symbol name (e.g. pills.fill)", text: $taskViewModel.assetSymbol)
                        .textFieldStyle(.roundedBorder)
                }

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(suggestedSymbols, id: \.self) { symbol in
                            Button {
                                taskViewModel.assetSymbol = symbol
                            } label: {
                                Image(systemName: symbol)
                                    .frame(width: 24, height: 24)
                                    .padding(6)
                            }
                            .buttonStyle(.bordered)
                        }
                    }
                }
            }

            DatePicker(
                "Reminder time",
                selection: $taskViewModel.scheduleTime,
                displayedComponents: .hourAndMinute
            )

            Button {
                Task {
                    await taskViewModel.createTask()
                }
            } label: {
                Text("Add Task")
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding()
                    .frame(maxWidth: .infinity)
            }
            .background(Color(.systemBlue))
            .cornerRadius(10)
            .disabled(taskViewModel.isProcessing)

            if !taskViewModel.statusMessage.isEmpty {
                Text(taskViewModel.statusMessage)
                    .font(.footnote)
                    .foregroundColor(taskViewModel.hasError ? .red : .green)
            }

            if taskViewModel.tasks.isEmpty {
                Text("No tasks yet.")
                    .font(.footnote)
                    .foregroundColor(.secondary)
            } else {
                ForEach(taskViewModel.tasks) { task in
                    HStack(alignment: .top) {
                        Image(systemName: safeSymbolName(task.assetSymbol))
                            .font(.body)
                            .frame(width: 24, height: 24)
                            .foregroundColor(.accentColor)

                        VStack(alignment: .leading, spacing: 4) {
                            Text(task.title)
                                .font(.body)
                            Text(task.id)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        Button(role: .destructive) {
                            Task {
                                await taskViewModel.deleteTask(id: task.id)
                            }
                        } label: {
                            Text("Delete")
                        }
                        .buttonStyle(.bordered)
                        .disabled(taskViewModel.isProcessing)
                    }
                    .padding(10)
                    .background(Color(.systemBackground))
                    .cornerRadius(10)
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(16)
        .shadow(radius: 5, x: 0, y: 1)
    }

    private func safeSymbolName(_ rawSymbol: String) -> String {
        let trimmed = rawSymbol.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "checkmark.circle" : trimmed
    }

}

struct ProfileView_Previews: PreviewProvider {
    static var previews: some View {
        ProfileView(loginViewModel: .init())
            .environment(\.careStore, Utility.createPreviewStore())
    }
}
