//
//  Double+Convenience.swift
//  ZDF
//
//  Created by Jonas Wippermann on 06.08.20.
//  Copyright © 2020 CELLULAR GmbH. All rights reserved.
//

import Foundation

extension Double {

    /// Combination of all sanity checks: isFinite, isNan, etc
    /// if this is true, the value should be valid and safely usable
    var canBeUsed: Bool {
        guard !isNaN else { return false }
        guard isFinite else { return false }
        return true
    }
}
