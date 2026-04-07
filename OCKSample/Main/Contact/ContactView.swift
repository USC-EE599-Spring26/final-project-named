//
//  ContactView.swift
//  OCKSample
//
//  Created by Corey Baker on 11/25/20.
//  Copyright © 2020 Network Reconnaissance Lab. All rights reserved.
//

import CareKit
import CareKitStore
import Contacts
import SwiftUI

struct ContactView: View {
    private static var query = OCKContactQuery(for: Date())
    @CareStoreFetchRequest(query: query) private var contacts
    @State private var searchText = ""
    @State private var isPresentingAddContact = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                HStack {
                    Button {
                        isPresentingAddContact = true
                    } label: {
                        Image(systemName: "plus")
                            .font(.system(size: 22, weight: .medium))
                            .foregroundStyle(.primary)
                            .frame(width: 28, height: 28)
                    }
                    .buttonStyle(.plain)

                    Spacer()
                }

                searchBar

                if filteredContacts.isEmpty {
                    emptyState
                } else {
                    ScrollView {
                        LazyVStack(spacing: 14) {
                            ForEach(filteredContacts, id: \.id) { contact in
                                NavigationLink {
                                    ContactDetailView(contact: contact)
                                } label: {
                                    ContactRowView(contact: contact)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.bottom, 24)
                    }
                    .scrollIndicators(.hidden)
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 14)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .background(Color(red: 0.99, green: 0.97, blue: 0.93))
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $isPresentingAddContact) {
                AddContactView(isPresented: $isPresentingAddContact)
            }
        }
    }

    private var sortedContacts: [OCKContact] {
        contacts
            .compactMap { fetchedContact in
                fetchedContact.result as? OCKContact
            }
            .sorted { lhs, rhs in
                lhs.displayName.localizedCaseInsensitiveCompare(rhs.displayName) == .orderedAscending
            }
    }

    private var filteredContacts: [OCKContact] {
        let trimmedQuery = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedQuery.isEmpty else {
            return sortedContacts
        }

        return sortedContacts.filter { contact in
            contact.displayName.localizedCaseInsensitiveContains(trimmedQuery)
        }
    }

    private var searchBar: some View {
        HStack(spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)

                TextField("Search Contacts", text: $searchText)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()

                if !searchText.isEmpty {
                    Button {
                        searchText = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(Color.white.opacity(0.82))
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))

            Button {
                searchText = ""
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .frame(width: 24, height: 24)
            }
            .buttonStyle(.plain)
        }
    }

    private var emptyState: some View {
        VStack(spacing: 14) {
            Image(systemName: searchText.isEmpty ? "person.2.slash" : "magnifyingglass")
                .font(.system(size: 28, weight: .semibold))
                .foregroundStyle(.secondary)

            Text(searchText.isEmpty ? "No contacts available." : "No matching contacts found.")
                .font(.headline)
                .foregroundStyle(.primary)

            Text(searchText.isEmpty ?
                 "Contacts added to the care plan will appear here." :
                 "Try searching by contact name.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, 28)
    }
}

private struct AddContactView: View {
    @Binding var isPresented: Bool

    @State private var firstName = ""
    @State private var lastName = ""
    @State private var title = ""
    @State private var role = ""
    @State private var phone = ""
    @State private var email = ""
    @State private var errorMessage: String?
    @State private var isSaving = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Contact") {
                    TextField("First Name", text: $firstName)
                    TextField("Last Name", text: $lastName)
                    TextField("Title", text: $title)
                    TextField("Role", text: $role)
                    TextField("Phone", text: $phone)
                        .keyboardType(.phonePad)
                    TextField("Email", text: $email)
                        .textInputAutocapitalization(.never)
                        .keyboardType(.emailAddress)
                        .autocorrectionDisabled()
                }

                if let errorMessage {
                    Section {
                        Text(errorMessage)
                            .foregroundStyle(.red)
                    }
                }

                Section {
                    Button(isSaving ? "Saving..." : "Save Contact") {
                        saveContact()
                    }
                    .disabled(isSaving)
                }
            }
            .navigationTitle("Add Contact")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") {
                        isPresented = false
                    }
                }
            }
        }
    }

    private func saveContact() {
        let cleanFirstName = firstName.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanLastName = lastName.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanRole = role.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanPhone = phone.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !cleanFirstName.isEmpty || !cleanLastName.isEmpty || !cleanTitle.isEmpty else {
            errorMessage = "Please enter a name or title."
            return
        }

        guard cleanEmail.isEmpty || cleanEmail.contains("@") else {
            errorMessage = "Please enter a valid email address."
            return
        }

        errorMessage = nil
        isSaving = true

        Task {
            do {
                guard let appDelegate = AppDelegateKey.defaultValue else {
                    await MainActor.run {
                        errorMessage = "Unable to access the app store."
                        isSaving = false
                    }
                    return
                }

                var contact = OCKContact(
                    id: UUID().uuidString,
                    givenName: cleanFirstName,
                    familyName: cleanLastName,
                    carePlanUUID: nil
                )
                contact.title = cleanTitle
                contact.role = cleanRole

                if !cleanPhone.isEmpty {
                    contact.phoneNumbers = [
                        OCKLabeledValue(label: CNLabelWork, value: cleanPhone)
                    ]
                }

                if !cleanEmail.isEmpty {
                    contact.emailAddresses = [
                        OCKLabeledValue(label: CNLabelEmailiCloud, value: cleanEmail)
                    ]
                }

                _ = try await appDelegate.store.addContacts([contact])

                await MainActor.run {
                    isSaving = false
                    isPresented = false
                }
            } catch {
                await MainActor.run {
                    errorMessage = "Could not save contact."
                    isSaving = false
                }
            }
        }
    }
}

private struct ContactRowView: View {
    let contact: OCKContact

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: "person.crop.circle.fill")
                .font(.system(size: 34))
                .foregroundStyle(Color(.systemGray4))

            VStack(alignment: .leading, spacing: 4) {
                Text(contact.displayName)
                    .font(.headline)
                    .foregroundStyle(.primary)
                    .frame(maxWidth: .infinity, alignment: .leading)

                if let subtitle = contact.primarySubtitle {
                    Text(subtitle)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
        .padding(16)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .shadow(color: Color.black.opacity(0.04), radius: 10, y: 4)
    }
}

private struct ContactDetailView: View {
    let contact: OCKContact

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 14) {
                        Image(systemName: "person.crop.circle.fill")
                            .font(.system(size: 52))
                            .foregroundStyle(Color(.systemGray4))

                        VStack(alignment: .leading, spacing: 4) {
                            Text(contact.displayName)
                                .font(.system(size: 28, weight: .bold))

                            if let subtitle = contact.primarySubtitle {
                                Text(subtitle)
                                    .font(.headline)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
                .padding(20)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.white)
                .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))

                if let role = contact.role, !role.isEmpty {
                    ContactDetailSection(
                        title: "About",
                        values: [role]
                    )
                }

                if !(contact.phoneNumbers?.isEmpty ?? true) {
                    ContactDetailSection(
                        title: "Phone",
                        values: (contact.phoneNumbers ?? []).map(\.displayText)
                    )
                }

                if !(contact.messagingNumbers?.isEmpty ?? true) {
                    ContactDetailSection(
                        title: "Message",
                        values: (contact.messagingNumbers ?? []).map(\.displayText)
                    )
                }

                if !(contact.emailAddresses?.isEmpty ?? true) {
                    ContactDetailSection(
                        title: "Email",
                        values: (contact.emailAddresses ?? []).map(\.displayText)
                    )
                }

                if let addressText = contact.addressText {
                    ContactDetailSection(
                        title: "Address",
                        values: [addressText]
                    )
                }
            }
            .padding(20)
        }
        .background(Color(red: 0.99, green: 0.97, blue: 0.93))
        .navigationTitle("Contact")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct ContactDetailSection: View {
    let title: String
    let values: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.headline)

            ForEach(values, id: \.self) { value in
                Text(value)
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    }
}

private extension OCKContact {
    var displayName: String {
        let name = [name.givenName, name.familyName]
            .compactMap {$0}
            .filter { !$0.isEmpty }
            .joined(separator: " ")

        if !name.isEmpty {
            return name
        }

        if let title, !title.isEmpty {
            return title
        }

        return id
    }

    var primarySubtitle: String? {
        if let title, !title.isEmpty {
            return title
        }

        if let role, !role.isEmpty {
            return role
        }

        return nil
    }
    var addressText: String? {
        guard let address else {
            return nil
        }

        let components = [
            address.street,
            address.city,
            address.state,
            address.postalCode,
            address.country
        ]
        .filter { !$0.isEmpty }

        guard !components.isEmpty else {
            return nil
        }

        return components.joined(separator: ", ")
    }
}

private extension OCKLabeledValue {
    var displayText: String {
        value

    }
}

struct ContactView_Previews: PreviewProvider {
    static var previews: some View {
        ContactView()
            .environment(\.careStore, Utility.createPreviewStore())
            .careKitStyle(Styler())
    }
}
