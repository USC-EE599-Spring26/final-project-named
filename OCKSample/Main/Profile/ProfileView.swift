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
#if canImport(PhotosUI)
import PhotosUI
#endif
#if canImport(UIKit)
import UIKit
#endif

struct ProfileView: View {
    private static var query = OCKPatientQuery(for: Date())
    @CareStoreFetchRequest(query: query) private var patients
    @StateObject private var viewModel = ProfileViewModel()
    @ObservedObject var loginViewModel: LoginViewModel
    @State var isPresentingAddTask = false
    @State var isPresentingDeleteTasks = false
    @State private var isPresentingMyContact = false
#if canImport(PhotosUI)
    @State private var selectedPhotoItem: PhotosPickerItem?
#endif

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    avatarSection

                    VStack(spacing: 14) {
                        profileField(title: "Login") {
                            Text(viewModel.loginName.isEmpty ? "Anonymous" : viewModel.loginName)
                                .foregroundStyle(.primary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding()
                                .background(Color.white)
                                .cornerRadius(16)
                        }

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

                    VStack(alignment: .leading, spacing: 14) {
                        Text("Contact")
                            .font(.headline)
                            .foregroundStyle(.secondary)

                        TextField("Phone", text: $viewModel.phoneNumber)
                            .keyboardType(.phonePad)
                            .padding()
                            .background(Color.white)
                            .cornerRadius(16)

                        TextField("Email", text: $viewModel.email)
                            .keyboardType(.emailAddress)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .padding()
                            .background(Color.white)
                            .cornerRadius(16)

                        TextField("Street", text: $viewModel.street)
                            .padding()
                            .background(Color.white)
                            .cornerRadius(16)

                        TextField("City", text: $viewModel.city)
                            .padding()
                            .background(Color.white)
                            .cornerRadius(16)

                        TextField("State", text: $viewModel.state)
                            .padding()
                            .background(Color.white)
                            .cornerRadius(16)

                        TextField("Postal Code", text: $viewModel.postalCode)
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
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("My Contact") {
                        isPresentingMyContact = true
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        isPresentingAddTask = true
                    } label: {
                        Text("Add Task")
                    }
                    .accessibilityLabel("Add Task")
                }
            }
            .sheet(isPresented: $isPresentingAddTask) {
                AddHealthKitTaskView(isPresented: $isPresentingAddTask)
            }
            .sheet(isPresented: $isPresentingMyContact) {
                MyContactView(viewModel: viewModel)
            }
            .onAppear {
                if let patient = patients.first?.result {
                    viewModel.updatePatient(patient)
                }
                Task {
                    await viewModel.loadCurrentUser()
                }
            }
            .onChange(of: patients.count) { _, _ in
                if let patient = patients.first?.result {
                    viewModel.updatePatient(patient)
                }
            }
#if canImport(PhotosUI)
            .onChange(of: selectedPhotoItem) { _, newItem in
                guard let newItem else {
                    return
                }
                Task {
                    if let data = try? await newItem.loadTransferable(type: Data.self) {
                        viewModel.updateAvatar(data: data)
                    }
                }
            }
#endif
        }
    }
}

private extension ProfileView {
    @ViewBuilder
    var avatarSection: some View {
        VStack(spacing: 16) {
#if canImport(PhotosUI)
            PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                avatarContent
            }
            .buttonStyle(.plain)
#else
            avatarContent
#endif
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 8)
    }

    @ViewBuilder
    var avatarContent: some View {
        ZStack {
            Circle()
                .fill(Color.white)
                .frame(width: 104, height: 104)

            Circle()
                .stroke(Color(red: 0.64, green: 0.20, blue: 0.22), lineWidth: 4)
                .frame(width: 104, height: 104)

#if canImport(UIKit)
            if let avatarImage = viewModel.avatarImage {
                Image(uiImage: avatarImage)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 92, height: 92)
                    .clipShape(Circle())
            } else if let avatarURL = viewModel.avatarURL {
                AsyncImage(url: avatarURL) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
                    default:
                        Image(systemName: "person.fill")
                            .resizable()
                            .scaledToFit()
                            .padding(18)
                            .foregroundStyle(.black)
                    }
                }
                .frame(width: 92, height: 92)
                .clipShape(Circle())
            } else {
                Image(systemName: "person.fill")
                    .resizable()
                    .scaledToFit()
                    .padding(18)
                    .frame(width: 92, height: 92)
                    .foregroundStyle(.black)
            }
#else
            if let avatarURL = viewModel.avatarURL {
                AsyncImage(url: avatarURL) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
                    default:
                        Image(systemName: "person.fill")
                            .resizable()
                            .scaledToFit()
                            .padding(18)
                            .foregroundStyle(.black)
                    }
                }
                .frame(width: 92, height: 92)
                .clipShape(Circle())
            } else {
                Image(systemName: "person.fill")
                    .resizable()
                    .scaledToFit()
                    .padding(18)
                    .frame(width: 92, height: 92)
                    .foregroundStyle(.black)
            }
#endif
        }
    }

    @ViewBuilder
    func profileField<Content: View>(
        title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.headline)
                .foregroundStyle(.secondary)
            content()
        }
    }
}

private struct MyContactView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @ObservedObject var viewModel: ProfileViewModel

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    HStack(spacing: 16) {
                        profileAvatar

                        VStack(alignment: .leading, spacing: 6) {
                            Text(viewModel.displayName)
                                .font(.system(size: 28, weight: .bold))
                            if !viewModel.email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                Text(viewModel.email)
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(.secondary)
                            } else {
                                Text(viewModel.loginName.isEmpty ? "Anonymous" : viewModel.loginName)
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .padding(20)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.white)
                    .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))

                    if hasCommunicationActions {
                        HStack(spacing: 16) {
                            if !cleanPhone.isEmpty {
                                actionButton(
                                    title: "Call",
                                    systemName: "phone",
                                    action: { openURL(URL(string: "tel://\(cleanPhone.filter { !$0.isWhitespace })")!) }
                                )
                                actionButton(
                                    title: "Message",
                                    systemName: "message",
                                    action: { openURL(URL(string: "sms://\(cleanPhone.filter { !$0.isWhitespace })")!) }
                                )
                            }

                            if !cleanEmail.isEmpty {
                                actionButton(
                                    title: "E-mail",
                                    systemName: "envelope",
                                    action: { openURL(URL(string: "mailto:\(cleanEmail)")!) }
                                )
                            }
                        }
                    }

                    if !cleanPhone.isEmpty {
                        myContactSection(title: "Phone", value: cleanPhone)
                    }

                    if !cleanEmail.isEmpty {
                        myContactSection(title: "Email", value: cleanEmail)
                    }

                    if !cleanAddress.isEmpty {
                        myContactSection(title: "Address", value: cleanAddress)
                    }
                }
                .padding(20)
            }
            .background(Color(red: 0.99, green: 0.97, blue: 0.93))
            .navigationTitle("My Contact")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") {
                        dismiss()
                    }
                }
            }
        }
    }

    private var cleanPhone: String {
        viewModel.phoneNumber.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var cleanEmail: String {
        viewModel.email.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var cleanAddress: String {
        [
            viewModel.street,
            viewModel.city,
            viewModel.state,
            viewModel.postalCode
        ]
        .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        .filter { !$0.isEmpty }
        .joined(separator: ", ")
    }

    private var hasCommunicationActions: Bool {
        !cleanPhone.isEmpty || !cleanEmail.isEmpty
    }

    @ViewBuilder
    private var profileAvatar: some View {
#if canImport(UIKit)
        if let avatarImage = viewModel.avatarImage {
            Image(uiImage: avatarImage)
                .resizable()
                .scaledToFill()
                .frame(width: 72, height: 72)
                .clipShape(Circle())
        } else if let avatarURL = viewModel.avatarURL {
            AsyncImage(url: avatarURL) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .scaledToFill()
                default:
                    Image(systemName: "person.crop.circle.fill")
                        .resizable()
                        .scaledToFit()
                        .foregroundStyle(Color(.systemGray4))
                }
            }
            .frame(width: 72, height: 72)
            .clipShape(Circle())
        } else {
            Image(systemName: "person.crop.circle.fill")
                .resizable()
                .scaledToFit()
                .frame(width: 72, height: 72)
                .foregroundStyle(Color(.systemGray4))
        }
#else
        if let avatarURL = viewModel.avatarURL {
            AsyncImage(url: avatarURL) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .scaledToFill()
                default:
                    Image(systemName: "person.crop.circle.fill")
                        .resizable()
                        .scaledToFit()
                        .foregroundStyle(Color(.systemGray4))
                }
            }
            .frame(width: 72, height: 72)
            .clipShape(Circle())
        } else {
            Image(systemName: "person.crop.circle.fill")
                .resizable()
                .scaledToFit()
                .frame(width: 72, height: 72)
                .foregroundStyle(Color(.systemGray4))
        }
#endif
    }

    @ViewBuilder
    private func actionButton(
        title: String,
        systemName: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: systemName)
                    .font(.system(size: 20, weight: .semibold))
                Text(title)
                    .font(.subheadline.weight(.semibold))
            }
            .foregroundStyle(Color(red: 0.64, green: 0.20, blue: 0.22))
            .frame(maxWidth: .infinity, minHeight: 72)
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func myContactSection(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
            Text(value)
                .font(.body)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
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
    @State private var repeatEveryDays = 1
    @State private var selectedCard: CareKitCard = .numericProgress
    @State private var selectedAsset = "cross.case.fill"
    @State private var numericGoalText = "1000"
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
                    if selectedTaskType == "OCKHealthKitTask" && selectedCard == .numericProgress {
                        TextField("Goal", text: $numericGoalText)
                            .keyboardType(.decimalPad)
                    }
                    DatePicker(
                        "Start Date",
                        selection: $scheduleStart,
                        displayedComponents: [.date]
                    )
                    Stepper(value: $repeatEveryDays, in: 1...30) {
                        Text(repeatDescription)
                    }
                    Picker("Card Type", selection: $selectedCard) {
                        if selectedTaskType == "OCKTask" {
                            Text(CareKitCard.button.rawValue).tag(CareKitCard.button)
                            Text(CareKitCard.checklist.rawValue).tag(CareKitCard.checklist)
                            Text(CareKitCard.custom.rawValue).tag(CareKitCard.custom)
                            Text(CareKitCard.featured.rawValue).tag(CareKitCard.featured)
                            Text(CareKitCard.grid.rawValue).tag(CareKitCard.grid)
                            Text(CareKitCard.instruction.rawValue).tag(CareKitCard.instruction)
                            Text(CareKitCard.link.rawValue).tag(CareKitCard.link)
                            Text(CareKitCard.simple.rawValue).tag(CareKitCard.simple)
                        } else {
                            Text("Recover Exercise").tag(CareKitCard.numericProgress)
                            Text("restingHeartRate").tag(CareKitCard.labeledValue)
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
        let schedule = TaskScheduleConfiguration(
            startDate: scheduleStart,
            repeatEveryDays: repeatEveryDays
        )
        guard !cleanTitle.isEmpty, !cleanInstructions.isEmpty else {
            errorMessage = "Please fill in Title and Instructions."
            return
        }

        errorMessage = nil
        if selectedTaskType == "OCKTask" {
            var cleanLinkURL: String?
            var cleanChecklistItem: String?
            if selectedCard == .link {
                guard let validatedLinkURL = normalizedHTTPURL(
                    linkURL.trimmingCharacters(in: .whitespacesAndNewlines)
                ) else {
                    errorMessage = "Please enter a valid http(s) URL for Link card."
                    return
                }
                cleanLinkURL = validatedLinkURL
            }
            if selectedCard == .checklist {
                let checklistItem = checkListItem.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !checklistItem.isEmpty else {
                    errorMessage = "Please enter a checklist item for Checklist card."
                    return
                }
                cleanChecklistItem = checklistItem
            }
            viewModel.saveRegularTask(
                title: cleanTitle,
                instructions: cleanInstructions,
                schedule: schedule,
                cardType: selectedCard,
                payload: .init(
                    assetName: selectedAsset,
                    linkURL: cleanLinkURL,
                    checklistItem: cleanChecklistItem
                )
            )
        } else {
            var numericGoalValue: Double?
            if selectedCard == .numericProgress {
                guard let parsedGoal = Double(numericGoalText.trimmingCharacters(in: .whitespacesAndNewlines)),
                      parsedGoal > 0 else {
                    errorMessage = "Please enter a valid goal greater than 0."
                    return
                }
                numericGoalValue = parsedGoal
            }
            viewModel.saveTask(
                title: cleanTitle,
                instructions: cleanInstructions,
                schedule: schedule,
                cardType: selectedCard,
                payload: .init(
                    assetName: selectedAsset,
                    numericGoalValue: numericGoalValue
                )
            )
        }
        isPresented = false
    }

    private var repeatDescription: String {
        repeatEveryDays == 1 ? "Repeat every day" : "Repeat every \(repeatEveryDays) days"
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
