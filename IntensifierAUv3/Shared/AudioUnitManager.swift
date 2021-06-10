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

public class AudioUnitManager {
    private var audioUnit: AUv3Intensifier?

    public private(set) var viewController: AUv3IntensifierController!

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
    public var releaseAmountValue: Float = 0.0 {
        didSet {
            releaseAmountParameter.value = releaseAmountValue
        }
    }
    public var attackTimeValue: Float = 0.0 {
        didSet {
            attackTimeParameter.value = attackTimeValue
        }
    }
    public var releaseTimeValue: Float = 0.0 {
        didSet {
            releaseTimeParameter.value = releaseTimeValue
        }
    }
    public var outputAmountValue: Float = 0.0 {
        didSet {
            outputAmountParameter.value = outputAmountValue
        }
    }

    // Gets the audio unit's defined presets.
    public var presets: [Preset] {
        guard let audioUnitPresets = audioUnit?.factoryPresets else {
            return []
        }
        return audioUnitPresets.map { preset -> Preset in
            return Preset(preset: preset)
        }
    }
    // Retrieves or sets the audio unit's current preset.
    public var currentPreset: Preset? {
        get {
            guard let preset = audioUnit?.currentPreset else { return nil }
            return Preset(preset: preset)
        }
        set {
            audioUnit?.currentPreset = newValue?.audioUnitPreset
        }
    }

    private var inputAmountParameter: AUParameter!
    private var attackAmountParameter: AUParameter!
    private var releaseAmountParameter: AUParameter!
    private var attackTimeParameter: AUParameter!
    private var releaseTimeParameter: AUParameter!
    private var outputAmountParameter: AUParameter!

    // A token for our registration to observe parameter value changes.
    private var parameterObserverToken: AUParameterObserverToken!

    // The AudioComponentDescription matching the AUv3IntensifierExtension Info.plist
    private var componentDescription: AudioComponentDescription = {

        // Ensure that AudioUnit type, subtype, and manufacturer match the extension's Info.plist values
        var componentDescription = AudioComponentDescription()
        componentDescription.componentType = kAudioUnitType_Effect
        componentDescription.componentSubType = 0x696e7461 /*'inta'*/
        componentDescription.componentManufacturer = 0x4175656d /*'Auem'*/
        componentDescription.componentFlags = 0
        componentDescription.componentFlagsMask = 0
        return componentDescription
    }()

    private let componentName = "Aura Audio LLC: IntensifierAUv3"

    public init() {

        /*
         Register our `AUAudioUnit` subclass, `AUv3Intensifier`, to make it able
         to be instantiated via its component description.

         Note that this registration is local to this process.
         */
        AUAudioUnit.registerSubclass(AUv3Intensifier.self,
                                     as: componentDescription,
                                     name: componentName,
                                     version: UInt32.max)

        AVAudioUnit.instantiate(with: componentDescription) { audioUnit, error in
            guard error == nil, let audioUnit = audioUnit else {
                fatalError("Could not instantiate audio unit: \(String(describing: error))")
            }
            self.audioUnit = audioUnit.auAudioUnit as? AUv3Intensifier
        }
    }
    // TODO: Figure out if the generic view works without this whole class
}
