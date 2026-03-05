//
//  AppearanceStyler.swift
//  OCKSample
//
//  Created by Yulin Xu on 2/25/26.
//  Copyright © 2026 Network Reconnaissance Lab. All rights reserved.
//

import CareKitUI
import UIKit

struct AppearanceStyler: OCKAppearanceStyler {
    // Custom appearance changes for cream-tone style
    var shadowOpacity1: Float {
        0.10
    }
    var cornerRadius1: CGFloat {
        20
    }
    var borderWidth1: CGFloat {
        2
    }
}
