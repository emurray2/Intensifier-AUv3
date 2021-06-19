import Foundation
import AudioToolbox
import CoreAudioKit
import AVFoundation

// A simple wrapper type to prevent exposing the Core Audio AUAudioUnitPreset in the UI layer.
public struct Preset {
    fileprivate init(preset: AUAudioUnitPreset) {
        audioUnitPreset = preset
    }
    fileprivate let audioUnitPreset: AUAudioUnitPreset
    public var number: Int { return audioUnitPreset.number }
    public var name: String { return audioUnitPreset.name }
}

// Delegate protocol to be adopted to be notified of parameter value changes.
public protocol AUManagerDelegate: AnyObject {
    func inputAmountValueDidChange(_ value: Float)
    func attackAmountValueDidChange(_ value: Float)
    func releaseAmountValueDidChange(_ value: Float)
    func attackTimeValueDidChange(_ value: Float)
    func releaseTimeValueDidChange(_ value: Float)
    func outputAmountValueDidChange(_ value: Float)
}

// Controller object used to manage the interaction with the audio unit and its user interface.
public class AudioUnitManager {
    /// The user-selected audio unit.
    private var audioUnit: AUv3Intensifier?

    public weak var delegate: AUManagerDelegate? {
        didSet {
            updateInputAmount()
            updateAttackAmount()
            updateReleaseAmount()
            updateAttackTime()
            updateReleaseTime()
            updateOutputAmount()
        }
    }

    public private(set) var viewController: AUv3IntensifierViewController!

    public var inputAmountValue: Float = 0.0 {
        didSet {
            inputAmountParameter.value = inputAmountValue
        }
    }
    public var attackAmountValue: Float = 0.0 {
        didSet {
            attackAmountParameter.value = attackAmountValue
        }
    }

    private var inputAmountParameter: AUParameter!
    private var attackAmountParameter: AUParameter!
    private var releaseAmountParameter: AUParameter!
    private var attackTimeParameter: AUParameter!
    private var releaseTimeParameter: AUParameter!
    private var outputAmountParameter: AUParameter!
    private var parameterObserverToken: AUParameterObserverToken?

    // Callbacks to update controls from parameters.
    func updateInputAmount() {
        guard let param = inputAmountParameter else { return }
        delegate?.inputAmountValueDidChange(param.value)
    }
    func updateAttackAmount() {
        guard let param = attackAmountParameter else { return }
        delegate?.attackAmountValueDidChange(param.value)
    }
    func updateReleaseAmount() {
        guard let param = releaseAmountParameter else { return }
        delegate?.releaseAmountValueDidChange(param.value)
    }
    func updateAttackTime() {
        guard let param = attackTimeParameter else { return }
        delegate?.attackTimeValueDidChange(param.value)
    }
    func updateReleaseTime() {
        guard let param = releaseTimeParameter else { return }
        delegate?.releaseTimeValueDidChange(param.value)
    }
    func updateOutputAmount() {
        guard let param = outputAmountParameter else { return }
        delegate?.outputAmountValueDidChange(param.value)
    }
}
