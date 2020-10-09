//
//  CMTime+Convenience.swift
//  ZDF
//
//  Created by Jonas Wippermann on 15.10.18.
//  Copyright © 2018 CELLULAR GmbH. All rights reserved.
//

import Foundation
import CoreMedia

extension CMTime {
    var seconds: Double {
        return Double(CMTimeGetSeconds(self))
    }

    /// Combination of all sanity checks: isValid, !isIndefinite, !isNegativeInfinity, etc..
    /// if this is true, the value should be valid and safely usable
    var canBeUsed: Bool {
        guard isValid else { return false }
        guard !isIndefinite else { return false }
        guard !isNegativeInfinity else { return false }
        guard !isPositiveInfinity else { return false }
        return true
    }
}
