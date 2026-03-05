//
//  ColorStyler.swift
//  OCKSample
//
//  Created by Corey Baker on 10/16/21.
//  Copyright © 2021 Network Reconnaissance Lab. All rights reserved.
//

import CareKitUI
import SwiftUI
import UIKit

struct ColorStyler: OCKColorStyler {
    #if os(iOS) || os(visionOS)
    var label: UIColor {
        FontColorKey.defaultValue
    }
    var tertiaryLabel: UIColor {
		UIColor(Color.accentColor)
    }
    // Custom cream-tone colors to match login style
    var customFill: UIColor {
        UIColor(red: 1.00, green: 0.97, blue: 0.90, alpha: 1.0)// login
    }
    var secondaryCustomFill: UIColor {
        UIColor(red: 0.99, green: 0.90, blue: 0.76, alpha: 1.0)// bg color
    }
    var customGray: UIColor {
        UIColor(red: 0.78, green: 0.45, blue: 0.24, alpha: 1.0)// login primarycolor
    }
    #endif
}
