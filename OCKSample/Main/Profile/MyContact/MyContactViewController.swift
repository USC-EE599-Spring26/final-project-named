//
//  MyContactViewController.swift
//  OCKSample
//
//  Created by Corey Baker on 4/2/26.
//  Copyright (c) 2026 Network Reconnaissance Lab. All rights reserved.
//

#if os(iOS) || targetEnvironment(macCatalyst)
import CareKit
import CareKitStore
import CareKitUI
import ParseSwift
import os.log
import UIKit

final class MyContactViewController: OCKListViewController {
    private var contacts = [OCKAnyContact]()
    private let store: OCKAnyStoreProtocol
    private let viewSynchronizer = OCKDetailedContactViewSynchronizer()

    init(store: OCKAnyStoreProtocol) {
        self.store = store
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        Task {
            try? await fetchMyContact()
        }
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        Task {
            try? await fetchMyContact()
        }
    }

    override func appendViewController(
        _ viewController: UIViewController,
        animated: Bool
    ) {
        super.appendViewController(viewController, animated: animated)
        if let careKitView = viewController.view as? OCKView {
            careKitView.customStyle = CustomStylerKey.defaultValue
        }
    }

    private func fetchMyContact() async throws {
        guard (try? await User.current()) != nil else {
            Logger.contact.error("User not logged in")
            contacts.removeAll()
            displayContacts()
            return
        }

        let personUUIDString = try await Utility.getRemoteClockUUID().uuidString
        var query = OCKContactQuery(for: Date())
        query.ids = [personUUIDString]
        query.limit = 1

        contacts = try await store.fetchAnyContacts(query: query)
        displayContacts()
    }

    private func displayContacts() {
        clear()

        for contact in contacts {
            var contactQuery = OCKContactQuery(for: Date())
            contactQuery.ids = [contact.id]
            contactQuery.limit = 1
            let contactViewController = OCKDetailedContactViewController(
                query: contactQuery,
                store: store,
                viewSynchronizer: viewSynchronizer
            )
            appendViewController(contactViewController, animated: false)
        }
    }
}
#endif
