//
//  TintColorFlipKey.swift
//  OCKSample
//
//  Created by Corey Baker on 9/26/22.
//  Copyright © 2022 Network Reconnaissance Lab. All rights reserved.
//

import Foundation
import SwiftUI

struct TintColorFlipKey: EnvironmentKey {
    static var defaultValue: UIColor {
        #if os(iOS) || os(visionOS)
        return UIColor {
                    $0.userInterfaceStyle == .light
                    ? #colorLiteral(red: 0.62, green: 0.44, blue: 0.27, alpha: 1)
                    : #colorLiteral(red: 0.95, green: 0.86, blue: 0.70, alpha: 1)
                }
        #else
        return #colorLiteral(red: 0.62, green: 0.44, blue: 0.27, alpha: 1)
        #endif
    }
}

extension EnvironmentValues {
    var tintColorFlip: UIColor {
        self[TintColorFlipKey.self]
    }
}
