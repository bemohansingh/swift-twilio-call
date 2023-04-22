//
//  CallKitProvider.swift
//  TwilioVoiceCallApp
//
//  Created by bemohansingh on 06/05/2021.
//

import Foundation
import CallKit
import TwilioVoice

final class CallKitProvider: NSObject, CXProviderDelegate {
    
    /// the shared instance
    static let shared = CallKitProvider()
    private override init() {}
    
    /// The audio device for call
    private(set) var audioDevice: DefaultAudioDevice!
    
    /// Flag to check that callkit was configured
    private var configured = false
    
    /// The provider
    private var provider: CXProvider!
    
    /// The call transaction controller
    private let callKitCallController = CXCallController()
    
    /// Configure the calkit with audio device
    /// - Parameter audioDevice: the audio device for calls
    func configure(audioDevice: DefaultAudioDevice) {
        
        guard !configured else { return }
        
        self.configured = true
        
        self.audioDevice = audioDevice
        
        var configuration = CXProviderConfiguration(localizedName: "")
        if #available(iOS 14.0, *) {
            configuration = CXProviderConfiguration()
        }
        configuration.maximumCallGroups = 1
        configuration.maximumCallsPerCallGroup = 1
        if let tonePath = Bundle.module.path(forResource: "incoming", ofType: "wav") {
            log("\(tonePath)")
            configuration.ringtoneSound = tonePath
        }
        provider = CXProvider(configuration: configuration)
        provider.setDelegate(self, queue: nil)
    }
    
    func performStartCallAction(uuid: UUID, handle: String) {
        let callHandle = CXHandle(type: .generic, value: handle)
        let startCallAction = CXStartCallAction(call: uuid, handle: callHandle)
        let transaction = CXTransaction(action: startCallAction)

        callKitCallController.request(transaction) { error in
            if let error = error {
                assertionFailure(error.localizedDescription)
                return
            }
            
            let callUpdate = CXCallUpdate()
            callUpdate.remoteHandle = callHandle
            callUpdate.supportsDTMF = false
            callUpdate.supportsHolding = false
            callUpdate.supportsGrouping = false
            callUpdate.supportsUngrouping = false
            callUpdate.hasVideo = false

            self.provider.reportCall(with: uuid, updated: callUpdate)
        }
    }

    func reportIncomingCall(from: String, uuid: UUID) {

        let callHandle = CXHandle(type: .generic, value: from)
        let callUpdate = CXCallUpdate()
        
        callUpdate.remoteHandle = callHandle
        callUpdate.supportsDTMF = true
        callUpdate.supportsHolding = true
        callUpdate.supportsGrouping = false
        callUpdate.supportsUngrouping = false
        callUpdate.hasVideo = false
        
        log("UUID_INCOMING \(uuid)")

        provider.reportNewIncomingCall(with: uuid, update: callUpdate) { error in
            if let error = error {
                log("Failed to report incoming call successfully: \(error.localizedDescription).")
            } else {
                log("Incoming call successfully reported.")
            }
        }
    }

    func performEndCallAction(uuid: UUID) {

        let endCallAction = CXEndCallAction(call: uuid)
        let transaction = CXTransaction(action: endCallAction)
        
        log("UUID_ENDING \(uuid)")

        callKitCallController.request(transaction) { error in
            if let error = error {
                log("EndCallAction transaction request failed: \(error.localizedDescription).")
                Trigger.handle.send(.callState(.failed(.error(error))))
            } else {
                log("EndCallAction transaction request successful")
                Trigger.handle.send(.callState(.callDeclined(uuid)))
            }
        }
    }
}

extension CallKitProvider {
    
    func providerDidReset(_ provider: CXProvider) {
        audioDevice.isEnabled = false
    }
    
    func provider(_ provider: CXProvider, didActivate audioSession: AVAudioSession) {
        audioDevice.isEnabled = true
    }
    
    func provider(_ provider: CXProvider, didDeactivate audioSession: AVAudioSession) {
        audioDevice.isEnabled = false
    }
    
    func provider(_ provider: CXProvider, perform action: CXStartCallAction) {
        provider.reportOutgoingCall(with: action.callUUID, startedConnectingAt: Date())
        action.fulfill()
    }

    func provider(_ provider: CXProvider, perform action: CXAnswerCallAction) {
        log("UUID_ANSWER \(action.callUUID)")
        Trigger.handle.send(.callState(.callAnswered(action.callUUID)))
        action.fulfill()
    }

    func provider(_ provider: CXProvider, perform action: CXEndCallAction) {
        log("UUID_DECLINE \(action.callUUID)")
        Trigger.handle.send(.callState(.callDeclined(action.callUUID)))
        action.fulfill()
    }
    
    func provider(_ provider: CXProvider, perform action: CXSetMutedCallAction) {
        Trigger.handle.send(.callState(.muteCall(action.isMuted)))
        action.fulfill()
    }

}
