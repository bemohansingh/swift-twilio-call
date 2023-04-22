//
//  Triggers.swift
//  TwilioVoiceCallApp
//
//  Created by bemohansingh on 06/05/2021.
//

import Foundation
import Combine

final public class Trigger {
    public static let handle = PassthroughSubject<TriggerType, Never>()
}

public enum TriggerType {
    case callState(CallState)
}

public enum CallState {
    case none
    case initiate(TwilioInfoIdentifiable)
    case connected
    case ringing
    case disconnected
    case failed(CallError)
    case callAnswered(UUID)
    case callDeclined(UUID)
    case muteCall(Bool)
}
