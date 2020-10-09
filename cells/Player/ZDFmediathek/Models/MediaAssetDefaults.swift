//
//  MediaAssetDefaults.swift
//  ZDF
//
//  Created by Jonas Wippermann on 20.02.20.
//  Copyright © 2020 CELLULAR GmbH. All rights reserved.
//

import Foundation

/// Describes Defaults to use when starting assets, such as "always show subtitles (if available)"
public struct MediaAssetDefaults {
    let showSubtitles: Bool, useAudioDescription: Bool, useSignLanguage: Bool

    /// Everything set to false, no preferred defaults
    static var none: MediaAssetDefaults {
        return .init(showSubtitles: false, useAudioDescription: false, useSignLanguage: false)
    }
}
