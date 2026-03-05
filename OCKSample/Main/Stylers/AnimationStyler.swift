//
//  AnimationStyler.swift
//  OCKSample
//
//  Created by Yulin Xu on 2/25/26.
//  Copyright © 2026 Network Reconnaissance Lab. All rights reserved.
//

import CareKitUI

struct AnimationStyler: OCKAnimationStyler {
    // Custom animation duration for smoother transitions
    var stateChangeDuration: Double {
        0.35
    }
}
