//
//  CustomFeaturedContentViewController.swift
//  OCKSample
//
//  Created by Corey Baker on 4/21/26.
//  Copyright © 2026 Network Reconnaissance Lab. All rights reserved.
//

#if os(iOS)
import UIKit
import CareKit
import CareKitUI

class CustomFeaturedContentViewController: OCKFeaturedContentView {
    var url: URL?
    private var customImage: UIImage?
    private var customText: String?
    private var customTextColor: UIColor?

    // Need to override so we can become delegate when the user taps on card
    override init(
        imageOverlayStyle: UIUserInterfaceStyle = .unspecified
    ) {
        // See that this always calls the super
        super.init(imageOverlayStyle: imageOverlayStyle)

        // DONE: 1 - Need to become a "delegate" so we know when view is tapped.
        self.delegate = self
    }

    /*
     DONE: 4 - Modify this init to take: UIImage, a text string , and text color.
     The initialize should set all of the respective properties.
     */
    // A convenience initializer to make it easier to use our custom featured content
    convenience init(
        image: UIImage,
        text: String,
        textColor: UIColor,
        imageOverlayStyle: UIUserInterfaceStyle = .unspecified
    ) {
        self.init(imageOverlayStyle: imageOverlayStyle)

        self.customImage = image
        self.customText = text
        self.customTextColor = textColor

        self.imageView.image = image
        self.label.text = text
        self.label.textColor = textColor
    }

    convenience init(
        url: String,
        imageOverlayStyle: UIUserInterfaceStyle = .unspecified
    ) {
        self.init(imageOverlayStyle: imageOverlayStyle)
        // DONE: 2 - Need to call the designated initializer

        // DONE 3 - Need to turn the url string into a real URL using URL(string: String)
        self.url = URL(string: url)
    }
}

/// Need to conform to delegate in order to be delegated to.
extension CustomFeaturedContentViewController: @MainActor OCKFeaturedContentViewDelegate {

    func didTapView(_ view: OCKFeaturedContentView) {
        // When tapped open a URL.
        guard let url = url else {
            return
        }
        UIApplication.shared.open(url)
    }
}

#endif
