//
//  TwilioUser.swift
//  TwilioVoiceCall
//
//  Created by bemohansingh on 05/05/2021.
//

import Foundation

public protocol TwilioInfoIdentifiable {
    var parameters: [String: String] { get }
    var callKitDisplayName: String { get }
}
