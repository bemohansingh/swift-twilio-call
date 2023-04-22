//
//  AudioManager.swift
//  TwilioVoiceCallApp
//
//  Created by bemohansingh on 06/05/2021.
//

import Foundation
import TwilioVoice

final public class AudioManager {
    
    /// The default audio device provided by twilio
    let defaultAudioDevice: DefaultAudioDevice
    
    /// The audioplayer to play audio
    private var ringtonePlayer: AVAudioPlayer? = nil
    
    /// initializer
    static let shared = AudioManager()
    private init() {
        defaultAudioDevice = DefaultAudioDevice()
    }
    
    func toggleAudioRoute(toSpeaker: Bool) {
        defaultAudioDevice.block = {
            DefaultAudioDevice.DefaultAVAudioSessionConfigurationBlock()
            
            do {
                if toSpeaker {
                    try AVAudioSession.sharedInstance().overrideOutputAudioPort(.speaker)
                } else {
                    try AVAudioSession.sharedInstance().overrideOutputAudioPort(.none)
                }
            } catch {
                log(error.localizedDescription)
            }
        }
        
        defaultAudioDevice.block()
    }
    
    func playRingbackTone() {
        guard let toneURL = Bundle.module.url(forResource: "ringback", withExtension: "wav") else { return }
        do {
            ringtonePlayer = try AVAudioPlayer(contentsOf: toneURL)
            ringtonePlayer?.numberOfLoops = -1
            ringtonePlayer?.volume = 1.0
            ringtonePlayer?.play()
        } catch {
            log("Failed to initialize audio player \(error.localizedDescription)")
        }
    }
    
    func stopRingbackTone() {
        guard let ringtonePlayer = ringtonePlayer, ringtonePlayer.isPlaying else { return }
        ringtonePlayer.stop()
    }
}
