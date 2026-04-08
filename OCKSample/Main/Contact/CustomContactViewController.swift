//
//  CustomContactViewController.swift
//  OCKSample
//
//  Created by Corey Baker on 4/2/26.
//  Copyright (c) 2026 Network Reconnaissance Lab. All rights reserved.
//

#if canImport(UIKit) && canImport(ContactsUI)
import CareKit
import CareKitStore
import CareKitUI
import Contacts
import ContactsUI
import ParseSwift
import UIKit
import os.log

final class CustomContactViewController: OCKListViewController, @unchecked Sendable {
    private var allContacts = [OCKContact]()
    var contacts: [CareStoreFetchedResult<OCKAnyContact>]? {
        didSet {
            reloadView()
        }
    }

    private let store: OCKAnyStoreProtocol
    private let viewSynchronizer: OCKSimpleContactViewSynchronizer

    init(
        store: OCKAnyStoreProtocol,
        contacts: [CareStoreFetchedResult<OCKAnyContact>]? = nil,
        viewSynchronizer: OCKSimpleContactViewSynchronizer
    ) {
        self.store = store
        self.contacts = contacts
        self.viewSynchronizer = viewSynchronizer
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        let searchController = UISearchController(searchResultsController: nil)
        searchController.searchBar.searchBarStyle = .prominent
        searchController.searchBar.placeholder = " Search Contacts"
        searchController.searchBar.showsCancelButton = true
        searchController.searchBar.delegate = self
        navigationItem.searchController = searchController
        definesPresentationContext = true
        navigationItem.leftBarButtonItem = UIBarButtonItem(
            barButtonSystemItem: .add,
            target: self,
            action: #selector(presentContactsListViewController)
        )

        reloadView()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        reloadView()
    }

    @objc
    private func presentContactsListViewController() {
        let contactPicker = CNContactPickerViewController()
        contactPicker.delegate = self
        contactPicker.predicateForEnablingContact = NSPredicate(format: "phoneNumbers.@count > 0")
        present(contactPicker, animated: true)
    }

    private func clearAndKeepSearchBar() {
        clear()
    }

    private func reloadView() {
        Task {
            try? await updateContacts()
        }
    }

    @MainActor
    private func updateContacts() async throws {
        guard (try? await User.current()) != nil else {
            Logger.contact.error("User not logged in")
            clearAndKeepSearchBar()
            allContacts = []
            return
        }

        let personUUIDString = try await Utility.getRemoteClockUUID().uuidString

        guard let contacts else {
            Logger.contact.error("No contacts to display")
            clearAndKeepSearchBar()
            allContacts = []
            return
        }

        let filteredContacts = contacts
            .compactMap { $0.result as? OCKContact }
            .filter { $0.id != personUUIDString }

        clearAndKeepSearchBar()
        allContacts = filteredContacts
        displayContacts(filteredContacts)
    }

    @MainActor
    private func displayContacts(_ contacts: [OCKContact]) {
        for contact in contacts {
            var query = OCKContactQuery(for: Date())
            query.ids = [contact.id]
            query.limit = 1
            let contactViewController = OCKSimpleContactViewController(
                query: query,
                store: store,
                viewSynchronizer: viewSynchronizer
            )
            appendViewController(contactViewController, animated: false)
        }
    }

    private func convertDeviceContact(_ contact: CNContact) -> OCKContact {
        var convertedContact = OCKContact(
            id: contact.identifier,
            givenName: contact.givenName,
            familyName: contact.familyName,
            carePlanUUID: nil
        )
        convertedContact.title = contact.jobTitle
        convertedContact.emailAddresses = contact.emailAddresses.map {
            OCKLabeledValue(label: $0.label ?? "email", value: $0.value as String)
        }

        let phoneNumbers = contact.phoneNumbers.map {
            OCKLabeledValue(label: $0.label ?? "phone", value: $0.value.stringValue)
        }
        convertedContact.phoneNumbers = phoneNumbers
        convertedContact.messagingNumbers = phoneNumbers

        if let address = contact.postalAddresses.first {
            convertedContact.address = OCKPostalAddress(
                street: address.value.street,
                city: address.value.city,
                state: address.value.state,
                postalCode: address.value.postalCode,
                country: address.value.country
            )
        }

        return convertedContact
    }
}

extension CustomContactViewController: UISearchBarDelegate {
    func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
        Logger.contact.debug("Searching text is '\(searchText)'")

        guard !searchText.isEmpty else {
            clearAndKeepSearchBar()
            displayContacts(allContacts)
            return
        }

        clearAndKeepSearchBar()

        let lowercasedSearchText = searchText.lowercased()
        let filteredContacts = allContacts.filter { contact in
            let givenName = contact.name.givenName?.lowercased() ?? ""
            let familyName = contact.name.familyName?.lowercased() ?? ""
            return givenName.contains(lowercasedSearchText) ||
                familyName.contains(lowercasedSearchText)
        }
        displayContacts(filteredContacts)
    }

    func searchBarCancelButtonClicked(_ searchBar: UISearchBar) {
        clearAndKeepSearchBar()
        displayContacts(allContacts)
    }
}

extension CustomContactViewController: @MainActor CNContactPickerDelegate {
    func contactPicker(
        _ picker: CNContactPickerViewController,
        didSelect contact: CNContact
    ) {
        let contactToAdd = convertDeviceContact(contact)
        let existingContacts = allContacts

        Task {
            guard (try? await User.current()) != nil else {
                Logger.contact.error("User not logged in")
                return
            }

            guard !existingContacts.contains(where: { $0.id == contactToAdd.id }) else {
                return
            }

            do {
                _ = try await store.addAnyContact(contactToAdd)
            } catch {
                Logger.contact.error("Could not add contact: \(error.localizedDescription)")
            }
        }
    }

    func contactPicker(
        _ picker: CNContactPickerViewController,
        didSelect contacts: [CNContact]
    ) {
        let newContacts = contacts.map(convertDeviceContact)
        let existingContacts = allContacts

        Task {
            guard (try? await User.current()) != nil else {
                Logger.contact.error("User not logged in")
                return
            }

            let contactsToAdd = newContacts.filter { newContact in
                existingContacts.first(where: { $0.id == newContact.id }) == nil
            }

            guard !contactsToAdd.isEmpty else {
                return
            }

            let immutableContactsToAdd: [OCKAnyContact] = contactsToAdd.map { $0 }

            do {
                _ = try await store.addAnyContacts(immutableContactsToAdd)
            } catch {
                Logger.contact.error("Could not add contacts: \(error.localizedDescription)")
            }
        }
    }
}
#endif
