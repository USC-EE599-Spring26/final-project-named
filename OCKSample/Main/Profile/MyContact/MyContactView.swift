//
//  MyContactView.swift
//  OCKSample
//
//  Created by Corey Baker on 4/2/26.
//  Copyright (c) 2026 Network Reconnaissance Lab. All rights reserved.
//

import CareKit
import CareKitStore
import SwiftUI
#if os(iOS) || targetEnvironment(macCatalyst)
import UIKit

struct MyContactView: UIViewControllerRepresentable {
    @Environment(\.careStore) var careStore

    func makeUIViewController(context: Context) -> some UIViewController {
        let viewController = createViewController()
        return UINavigationController(rootViewController: viewController)
    }

    func updateUIViewController(
        _ uiViewController: UIViewControllerType,
        context: Context
    ) {}

    private func createViewController() -> UIViewController {
        MyContactViewController(store: careStore)
    }
}
#else
struct MyContactView: View {
    var body: some View {
        Text("My Contact is unavailable on this platform.")
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
#endif

struct MyContactView_Previews: PreviewProvider {
    static var previews: some View {
        MyContactView()
            .environment(\.careStore, Utility.createPreviewStore())
            .accentColor(Color.accentColor)
    }
}
