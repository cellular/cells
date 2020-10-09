//
//  AVPlayerItem+MediaSelection.swift
//  ZDF
//
//  Created by Jonas Wippermann on 09.07.20.
//  Copyright © 2020 CELLULAR GmbH. All rights reserved.
//

import Foundation
import AVFoundation

/// Provides convenience methods to access 'audible' and 'legible' media selection options, so
/// subtitles or different audio tracks for a playing item
extension AVPlayerItem {

    /// group ('collection') of media options for the 'audible' characteristic
    public var audibleSelectionGroup: AVMediaSelectionGroup? {
        return asset.mediaSelectionGroup(forMediaCharacteristic: AVMediaCharacteristic.audible)
    }

    /// list of media options for the 'audible' characteristic which are "usable" (can be played and have a 'title')
    public var audibleSelectionOptions: [AVMediaSelectionOption] {
        return audibleSelectionGroup?.options.filter({ $0.isPlayable && $0.title != nil }) ?? []
    }

    public var selectedAudibleOption: AVMediaSelectionOption? {
        guard let audibleGroup = audibleSelectionGroup else { return nil }
        return currentMediaSelection.selectedMediaOption(in: audibleGroup)
    }

    /// group ('collection') of media options for the 'legible' characteristic
    public var legibleSelectionGroup: AVMediaSelectionGroup? {
        return asset.mediaSelectionGroup(forMediaCharacteristic: AVMediaCharacteristic.legible)
    }

    /// list of media options for the 'legible' characteristic which are "usable" (can be played and have a 'title')
    public var legibleSelectionOptions: [AVMediaSelectionOption] {
        return legibleSelectionGroup?.options.filter({ $0.isPlayable && $0.title != nil }) ?? []
    }

    public var selectedLegibleOption: AVMediaSelectionOption? {
        guard let legibleGroup = legibleSelectionGroup else { return nil }
        return currentMediaSelection.selectedMediaOption(in: legibleGroup)
    }

    /// Tries to return the most likely known selection option for "audio description"
    var probablyAudioDescriptionOption: (AVMediaSelectionOption, AVMediaSelectionGroup)? {
        guard let audibleGroup = audibleSelectionGroup else { return nil }
        guard let option = audibleSelectionOptions.first(where: {
            let name = $0.displayName(with: Locale(identifier: "de")).lowercased()
            return name.contains("audiodeskr") || name.contains("audio-deskr")
        }) else { return nil }
        return (option, audibleGroup)
    }

    /// Tries to return the most likely known selection option for "subtitles"
    var probablySubtitleOption: (AVMediaSelectionOption, AVMediaSelectionGroup)? {
        guard let legibleGroup = legibleSelectionGroup else { return nil }
        // return first option which is not the default
        guard let option = legibleSelectionOptions.first(where: { $0 != legibleGroup.defaultOption }) else { return nil }
        return (option, legibleGroup)
    }
}

extension AVMediaSelectionOption {

    /// The title of the AVMediaSelectionOption as defined by the item's MetaData.
    /// If no title is defined, this property is nil.
    var title: String? {
        return AVMetadataItem.metadataItems(from: commonMetadata, withKey: AVMetadataKey.commonKeyTitle,
            keySpace: AVMetadataKeySpace.common).first?.stringValue
    }
}
