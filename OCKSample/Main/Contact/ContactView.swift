//
//  ContactView.swift
//  OCKSample
//
//  Created by Corey Baker on 11/25/20.
//  Copyright © 2020 Network Reconnaissance Lab. All rights reserved.
//

import CareKit
import CareKitEssentials
import CareKitStore
import CareKitUI
import os.log
import SwiftUI
#if canImport(UIKit) && canImport(ContactsUI)
import UIKit

#if os(visionOS)
struct ContactView: View {
    var body: some View {
        NavigationStack {
            Text("Contacts are unavailable on visionOS.")
                .foregroundStyle(.secondary)
                .navigationTitle("Contacts")
        }
    }
}
#else
struct ContactView: UIViewControllerRepresentable {
    @Environment(\.careStore) var careStore
    @CareStoreFetchRequest(query: query()) private var contacts

    func makeUIViewController(context: Context) -> some UIViewController {
        let viewController = createViewController()
        let navigationController = UINavigationController(rootViewController: viewController)
        return navigationController
    }

    func updateUIViewController(
        _ uiViewController: UIViewControllerType,
        context: Context
    ) {
        guard let navigationController = uiViewController as? UINavigationController else {
            Logger.feed.error("ContactView should have been a UINavigationController")
            return
        }
        navigationController.setViewControllers([createViewController()], animated: false)
    }

    func createViewController() -> UIViewController {
        CustomContactViewController(
            store: careStore,
            contacts: contacts.latest
        )
    }

    static func query() -> OCKContactQuery {
        OCKContactQuery(for: Date())
    }
}
#else
struct ContactView: View {
    var body: some View {
        Text("Contacts are unavailable on this platform.")
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
#endif

struct ContactView_Previews: PreviewProvider {
    static var previews: some View {
        ContactView()
            .environment(\.careStore, Utility.createPreviewStore())
            .careKitStyle(Styler())
    }
}
#endif
