//
//  MyContactView.swift
//  OCKSample
//
//  Created by Corey Baker on 4/2/26.
//  Copyright © 2026 Network Reconnaissance Lab. All rights reserved.
//

import SwiftUI
import UIKit
import CareKit
import CareKitStore
import os.log

#if os(visionOS)
struct MyContactView: View {
    var body: some View {
        NavigationStack {
            Text("My Contact is unavailable on visionOS.")
                .foregroundStyle(.secondary)
                .navigationTitle("My Contact")
        }
    }
}
#else
struct MyContactView: UIViewControllerRepresentable {
    @Environment(\.careStore) var careStore

    func makeUIViewController(context: Context) -> some UIViewController {
        let viewController = createViewController()
        let navigationController = UINavigationController(
            rootViewController: viewController
        )
        return navigationController

    }

    func updateUIViewController(
        _ uiViewController: UIViewControllerType,
        context: Context
    ) {}

    func createViewController() -> UIViewController {
        let viewController = MyContactViewController(store: careStore)
        return viewController
    }
}

struct MyContactView_Previews: PreviewProvider {

    static var previews: some View {
        MyContactView()
            .environment(\.careStore, Utility.createPreviewStore())
            .accentColor(Color.accentColor)
    }
}
#endif
