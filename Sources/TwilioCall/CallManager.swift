//
//  CallManager.swift
//  TwilioVoiceCallApp
//
//  Created by bemohansingh on 06/05/2021.
//

import Foundation
import TwilioVoice
import Combine
import PushKit

final public class CallManager: NSObject {
    
    /// The key for caching the registration of twilio
    private let registrationRequiredCacheKey = "TwilioRegistrationRequired"
    
    /// The key for caching the voip token data
    private let pushVoipToken = "PushVOIPToken"
    
    /// The shared instance of this class
    public static let `default` = CallManager()
    private override init() {
        TwilioVoiceSDK.setLogLevel(.all, module: .platform);
        super.init()
        self.listenForTrigger()
    }
    
    /// The collection bag for subscription
    private var bag = Set<AnyCancellable>()
    
    /// The class to generate access tokens for calls
    private var tokenGenerator = TokenGenerator.default
    
    /// The class to manage callkit
    private var callKitProvider = CallKitProvider.shared
    
    /// The class to manage permissions required
    private var permissionManager = PermissionManager.shared
    
    /// The class to manage audio
    public private(set) var audioManager = AudioManager.shared
    
    /// The call that is active
    private(set) var activeCall: Call?
    
    /// The call started datetime
    public var callStartedDatetime: Date?
    
    /// The current call invites
    private var activeCallInvite: CallInvite?
    
    /// The custom parameters for active call
    public private(set) var activeCallParameters = [String: String]()
    
    /// The voip registry
    private let voipRegistry = PKPushRegistry.init(queue: DispatchQueue.main)
    
    /// call state trigger
    public let callTrigger = CurrentValueSubject<CallState, Never>(.none)
    
    /// The generated token
    private var token: VoiceToken?
    
    /// Flag to indicate if the call is incoming or outgoing
    public private(set) var isIncoming = true
    
    /// The flag to indicate if the call is outgoing or not
    private(set) var isOutgoing = false
    
    
    /// Method to configure the class with endpoint for token generator
    /// - Parameter endpoint: the token endpoint
    func configure(endpoint: String) {
        tokenGenerator.setEndpoint(endpoint: endpoint)
    }
    
    /// The current call exposer method
    public func currentCall() -> Call? {
        return activeCall
    }
    
    /// The current active invite
    public func activeInvite() -> CallInvite? {
        return activeCallInvite
    }
    
    /// Method to register the current user to twilio
    /// - Parameter info: the twilio info
    public func login(_ info: TwilioInfoIdentifiable) {
        
        // configure callkit
        callKitProvider.configure(audioDevice: audioManager.defaultAudioDevice)
        
        // Set the audio device
        TwilioVoiceSDK.audioDevice = audioManager.defaultAudioDevice
        
        // get accesstoken for registration
        tokenGenerator.generateAccessToken(info: info) { [unowned self] (result) in
            if let error = result.error {
                log(error.localizedDescription)
            } else {
                self.token = result.token
                self.configureVoip()
            }
        }
    }
    
    /// Listen for all the triggers
    private func listenForTrigger() {
        Trigger.handle.receive(on: RunLoop.main).sink { [unowned self] (type) in
            log(type)
            switch type {
            case .callState( let state):
                self.callTrigger.send(state)
                switch state {
                case .callAnswered(let uuid):
                    self.answerCall(uuid: uuid)
                case .callDeclined(let uuid):
                    self.declineCall(uuid: uuid)
                case .muteCall(let isMuted):
                    self.muteCall(isMuted: isMuted)
                default:break
                }
            }
        }.store(in: &bag)
    }
    
    /// Method to perform logout of the provided user
    /// - Parameter info: the user info to logout
    public func logout(_ info: TwilioInfoIdentifiable) {
        tokenGenerator.generateAccessToken(info: info) { [unowned self] (result) in
            if let error = result.error {
                log(error.localizedDescription)
            } else {
                self.token = result.token
                self.unregisterTwilio()
            }
        }
    }
}

// MARK: Voip Trigger Handle
extension CallManager: NotificationDelegate, PKPushRegistryDelegate {
    
    private func configureVoip() {
        voipRegistry.delegate = self
        voipRegistry.desiredPushTypes = [.voIP]
        
        if let voipToken = UserDefaults.standard.data(forKey: self.pushVoipToken) {
            self.handle(voipToken: voipToken)
        }
    }
    
    public func pushRegistry(_ registry: PKPushRegistry, didUpdate pushCredentials: PKPushCredentials, for type: PKPushType) {
        handle(voipToken: pushCredentials.token)
    }
    
    public func pushRegistry(_ registry: PKPushRegistry, didInvalidatePushTokenFor type: PKPushType) {
        UserDefaults.standard.removeObject(forKey: self.pushVoipToken)
        unregisterTwilio()
    }
    
    public func pushRegistry(_ registry: PKPushRegistry, didReceiveIncomingPushWith payload: PKPushPayload, for type: PKPushType, completion: @escaping () -> Void) {
        self.incomingCall(payload: payload.dictionaryPayload)
        completion()
    }
    
    private func handle(voipToken: Data) {
        if let dateInterval = UserDefaults.standard.value(forKey: registrationRequiredCacheKey) as? Double {
            let storedDate = Date(timeIntervalSince1970: dateInterval)
            let daysPassed = Date().timeIntervalSince(storedDate) / 86400.0
            if daysPassed >= 200 {
                registerTwilio(with: voipToken)
            }
        } else {
            registerTwilio(with: voipToken)
        }
    }
    
    private func registerTwilio(with voipToken: Data) {
        guard let token = self.token else { assertionFailure(); return }
        TwilioVoiceSDK.register(accessToken: token.accessToken, deviceToken: voipToken) { [unowned self] (error) in
            if let error = error {
                log("Failed to register device \(error.localizedDescription)")
            } else {
                UserDefaults.standard.setValue(Date().timeIntervalSince1970, forKey: self.registrationRequiredCacheKey)
                UserDefaults.standard.setValue(voipToken, forKey: self.pushVoipToken)
                log("User registered")
            }
        }
    }
    
    private func unregisterTwilio() {
        guard let token = self.token else {
            assertionFailure();
            UserDefaults.standard.removeObject(forKey: self.registrationRequiredCacheKey)
            return
        }
        guard let voipData = UserDefaults.standard.data(forKey: pushVoipToken) else { return }
        TwilioVoiceSDK.unregister(accessToken: token.accessToken, deviceToken: voipData) { [unowned self] (error) in
            if let error = error {
                log("Failed to un-register device \(error.localizedDescription)")
            } else {
                UserDefaults.standard.removeObject(forKey: self.registrationRequiredCacheKey)
                log("User unregistered")
            }
        }
    }
    
    public func callInviteReceived(callInvite: CallInvite) {
        var from = (callInvite.from ?? "").replacingOccurrences(of: "client:", with: "")
        if let customParams = callInvite.customParameters {
            if let callerName = customParams["caller"] {
                from = callerName
            }
        }
        callKitProvider.reportIncomingCall(from: from, uuid: callInvite.uuid)
        activeCallInvite = nil
        activeCallInvite = callInvite
        activeCallParameters = callInvite.customParameters ?? [:]
        log(activeCallParameters)
    }
    
    public func cancelledCallInviteReceived(cancelledCallInvite: CancelledCallInvite, error: Error) {
        guard let callInvite = activeCallInvite else { return }
        guard callInvite.callSid == cancelledCallInvite.callSid else { assertionFailure(); return }
        requestEndCallAction(uuid: callInvite.uuid)
    }
    
    func incomingCall(payload: [AnyHashable: Any]) {
        log("VOIP Received \(payload)")
        TwilioVoiceSDK.handleNotification(payload, delegate: self, delegateQueue: nil)
    }
    
    private func requestEndCallAction(uuid: UUID?) {
        guard let uuid = uuid else { assertionFailure(); return }
        callKitProvider.performEndCallAction(uuid: uuid)
    }
}

// MARK: Call Delegates and handles
extension CallManager: CallDelegate {
    
    /// Start the call to given user
    /// - Parameter info: the information for call
    public func initiateCall(info: TwilioInfoIdentifiable) {
        if let activeCall = activeCall {
            callTrigger.send(.callAnswered(activeCall.uuid ?? UUID()))
        } else {
            Trigger.handle.send(.callState(.initiate(info)))
            permissionManager.checkPermissions { [unowned self](granted) in
                if granted {
                    self.tokenGenerator.generateAccessToken(info: info) { [unowned self] (result) in
                        if let error = result.error {
                            log(error.localizedDescription)
                        } else {
                            self.token = result.token
                            self.startCall(info: info)
                        }
                    }
                } else {
                    Trigger.handle.send(.callState(.failed(.micPermissionDenied)))
                }
            }
        }
    }
    
    /// Starts the call after new call token is generated
    /// - Parameter callee: the callee to call to
    private func startCall(info: TwilioInfoIdentifiable) {
        guard let token = token else { assertionFailure(); return }
        let connectOptions = ConnectOptions(accessToken: token.accessToken) { builder in
            builder.params = info.parameters
            builder.uuid = UUID()
        }
        activeCall = TwilioVoiceSDK.connect(options: connectOptions, delegate: self)
        guard let callId = activeCall?.uuid else { return }
        callKitProvider.performStartCallAction(uuid: callId, handle: info.callKitDisplayName)
        isIncoming = false
    }
    
    private func answerCall(uuid: UUID) {
        guard let callInvite = activeCallInvite else {
            assertionFailure()
            return
        }
        
        let acceptOptions = AcceptOptions(callInvite: callInvite) { builder in
            builder.uuid = callInvite.uuid
        }
        
        let call = callInvite.accept(options: acceptOptions, delegate: self)
        activeCall = call
        
        activeCallInvite = nil
        callStartedDatetime = Date()
        isIncoming = true
    }
    
    private func declineCall(uuid: UUID) {
        if let call = activeCall {
            call.disconnect()
            activeCall = nil
        } else if let callInvite = activeCallInvite {
            callInvite.reject()
        }
    }
    
    public func muteCall(isMuted: Bool) {
        guard let call = activeCall else { return }
        call.isMuted = isMuted
    }
    
    public func toggleSpeaker(isOn: Bool) {
        audioManager.toggleAudioRoute(toSpeaker: isOn)
    }
    
    public func endCall() {
        guard let call = activeCall else { return }
        call.disconnect()
        requestEndCallAction(uuid: call.uuid)
        activeCall = nil
        callStartedDatetime = nil
    }
    
    public func callDidStartRinging(call: Call) {
        log("Call Ringing")
        Trigger.handle.send(.callState(.ringing))
    }
    
    public func callDidConnect(call: Call) {
        log("Call Connected")
        Trigger.handle.send(.callState(.connected))
    }
    
    public func callDidFailToConnect(call: Call, error: Error) {
        log("Call fail to connect \(error.localizedDescription)")
        requestEndCallAction(uuid: call.uuid)
        Trigger.handle.send(.callState(.failed(.error(error))))
    }
    
    public func callDidDisconnect(call: Call, error: Error?) {
        log("Call did re-connect")
        requestEndCallAction(uuid: call.uuid)
        Trigger.handle.send(.callState(.disconnected))
    }
}
