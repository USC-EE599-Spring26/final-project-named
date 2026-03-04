//
//  OCKDimensionStyle.swift
//  OCKSample
//
//  Created by Corey Baker on 2/19/26.
//  Copyright © 2026 Network Reconnaissance Lab. All rights reserved.
//

import CareKitUI
import UIKit

struct DimensionStyler: OCKDimensionStyler {
    #if os(iOS)

    var separatorHeight: CGFloat { 1.0 / UIScreen.main.scale }

    #endif

    var lineWidth1: CGFloat { 20 }
    var stackSpacing1: CGFloat { 8 }

    var imageHeight2: CGFloat { 40 }
    var imageHeight1: CGFloat { 350 }

    var pointSize3: CGFloat { 50 }
    var pointSize2: CGFloat { 14 }
    var pointSize1: CGFloat { 17 }

    var symbolPointSize5: CGFloat { 8 }
    var symbolPointSize4: CGFloat { 12 }
    var symbolPointSize3: CGFloat { 30 }
    var symbolPointSize2: CGFloat { 20 }
    var symbolPointSize1: CGFloat { 30 }
}
