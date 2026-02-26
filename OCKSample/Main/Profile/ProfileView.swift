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
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(16)
        .shadow(radius: 5, x: 0, y: 1)
    }

}

struct ProfileView_Previews: PreviewProvider {
    static var previews: some View {
        ProfileView(loginViewModel: .init())
            .environment(\.careStore, Utility.createPreviewStore())
    }
}
