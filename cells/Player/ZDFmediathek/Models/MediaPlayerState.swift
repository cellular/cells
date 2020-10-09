//
//  MediaPlayerState.swift
//  ZDF
//
//  Created by Helge Carstensen on 03.07.17.
//  Copyright © 2017 CELLULAR GmbH. All rights reserved.
//

import Foundation

enum MediaPlayerState: Equatable {
    case idle
    case paused
    case playing
    case reversed
    case seeking
    case buffering
    case error

    static var genericErrorMessage: String {
		return NSLocalizedString("Es ist ein Fehler beim Abspielen des Videos aufgetreten.", comment: "")
    }
}
