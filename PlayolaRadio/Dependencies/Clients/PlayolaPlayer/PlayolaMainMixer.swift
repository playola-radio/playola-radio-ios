//
//  PlayolaMainMixer.swift
//  PlayolaRadio
//
//  Created by Brian D Keane on 12/20/24.
//

import AVFoundation
import Foundation
import os.log

public protocol PlayolaMainMixerDelegate {
    func player(_ mainMixer: PlayolaMainMixer, didPlayBuffer: AVAudioPCMBuffer)
}

/// Default properties for the tap
enum TapProperties {
    case `default`

    /// The amount of samples in each buffer of audio
    var bufferSize: AVAudioFrameCount {
        return 512
    }

    /// The format of the audio in the tap (desired is float 32, non-interleaved)
    var format: AVAudioFormat {
        return AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: 44100, channels: 2, interleaved: false)!
    }
}

open class PlayolaMainMixer: NSObject {
    open var mixerNode: AVAudioMixerNode!
    open var engine: AVAudioEngine!
    open var delegate: PlayolaMainMixerDelegate?

    override init() {
        super.init()
        self.mixerNode = AVAudioMixerNode()
        self.engine = AVAudioEngine()
        self.engine.attach(self.mixerNode)
        self.engine.connect(self.mixerNode, to: self.engine.mainMixerNode, format: TapProperties.default.format)
        self.engine.prepare()

        self.mixerNode.installTap(onBus: 0, bufferSize: TapProperties.default.bufferSize, format: TapProperties.default.format, block: self.onTap(_:_:))
    }

    deinit {
        self.mixerNode.removeTap(onBus: 0)
    }

    /// Handles the audio tap
    private func onTap(_ buffer: AVAudioPCMBuffer, _ time: AVAudioTime) {
        self.delegate?.player(self, didPlayBuffer: buffer)
    }
    open class func sharedInstance() -> PlayolaMainMixer {
        if self._instance == nil {
            self._instance = PlayolaMainMixer()
        }
        return self._instance!
    }

    /// internally shared singleton instance
    fileprivate static var _instance: PlayolaMainMixer?

    class func replaceSharedInstance(_ mixer: PlayolaMainMixer) {
        self._instance = mixer
    }
}
