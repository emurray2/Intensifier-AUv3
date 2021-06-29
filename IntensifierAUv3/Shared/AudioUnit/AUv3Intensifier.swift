import Foundation
import AudioToolbox
import AVFoundation
import CoreAudioKit

fileprivate extension AUAudioUnitPreset {
    convenience init(number: Int, name: String) {
        self.init()
        self.number = number
        self.name = name
    }
}

public class AUv3Intensifier: AUAudioUnit {
    private let parameters: AUv3IntensifierParameters
    private let kernelAdapter: IntensifierDSPKernelAdapter
    lazy private var inputBusArray: AUAudioUnitBusArray = {
        AUAudioUnitBusArray(audioUnit: self,
                            busType: .input,
                            busses: [kernelAdapter.inputBus])
    }()
    lazy private var outputBusArray: AUAudioUnitBusArray = {
        AUAudioUnitBusArray(audioUnit: self,
                            busType: .output,
                            busses: [kernelAdapter.outputBus])
    }()
    // The owning view controller
    weak var viewController: AUv3IntensifierViewController?

    public override var inputBusses: AUAudioUnitBusArray {
        return inputBusArray
    }
    public override var outputBusses: AUAudioUnitBusArray {
        return outputBusArray
    }
    public override var parameterTree: AUParameterTree? {
        get { return parameters.parameterTree }
        set { /* not modifiable*/ }
    }

    public override var factoryPresets: [AUAudioUnitPreset] {
        return [
            AUAudioUnitPreset(number: 0, name: "Subtle"),
            AUAudioUnitPreset(number: 1, name: "W I D E"),
            AUAudioUnitPreset(number: 2, name: "CrOnchy")
        ]
    }

    private let factoryPresetValues:[(
        inputAmount: AUValue,
        attackAmount: AUValue,
        releaseAmount: AUValue,
        attackTime: AUValue,
        releaseTime: AUValue,
        outputAmount: AUValue
    )] = [
        (0.0, -29.0, 5.0, 149.0, 1.0, 0.0), // "Subtle"
        (15.0, -17.68, 1.59, 158.36, 0.31, 2.03), // "W I D E"
        (2.86, 5.68, -32.48, 272.9, 0.82, -9.02) // "CrOnchy"
    ]

    private var _currentPreset: AUAudioUnitPreset?
    public override var currentPreset: AUAudioUnitPreset? {
        get { return _currentPreset }
        set {
            // If the newValue is nil, return.
            guard let preset = newValue else {
                print("bad")
                _currentPreset = nil
                return
            }

            // Factory presets need to always have a number >= 0.
            if preset.number >= 0 {
                let values = factoryPresetValues[preset.number]
                parameters.setParameterValues(
                    inputAmount: values.inputAmount,
                    attackAmount: values.attackAmount,
                    releaseAmount: values.releaseAmount,
                    attackTime: values.attackTime,
                    releaseTime: values.releaseTime,
                    outputAmount: values.outputAmount
                )
                _currentPreset = preset
            }
        }
    }

    public override var supportsUserPresets: Bool {
        return true
    }

    public func setPreset(number: Int) {
        currentPreset = factoryPresets[number]
    }

    public override init(componentDescription: AudioComponentDescription,
                         options: AudioComponentInstantiationOptions = []) throws {

        // Create adapter to communicate to underlying C++ DSP code
        kernelAdapter = IntensifierDSPKernelAdapter()

        // Create parameters object to control cutoff frequency and resonance
        parameters = AUv3IntensifierParameters(kernelAdapter: kernelAdapter)

        // Init super class
        try super.init(componentDescription: componentDescription, options: options)

        // Log component description values
        //log(componentDescription)

        // Set the default preset
        _currentPreset = factoryPresets.first
    }

    private func log(_ acd: AudioComponentDescription) {

        let info = ProcessInfo.processInfo
        print("\nProcess Name: \(info.processName) PID: \(info.processIdentifier)\n")

        let message = """
        AUv3Intensifier (
                  type: \(acd.componentType.stringValue)
               subtype: \(acd.componentSubType.stringValue)
          manufacturer: \(acd.componentManufacturer.stringValue)
                 flags: \(String(format: "%#010x", acd.componentFlags)),
                 mask: \(String(format: "%#010x", acd.componentFlagsMask))
        )
        """
        print(message)
    }

    public override var maximumFramesToRender: AUAudioFrameCount {
        get {
            return kernelAdapter.maximumFramesToRender
        }
        set {
            if !renderResourcesAllocated {
                kernelAdapter.maximumFramesToRender = newValue
            }
        }
    }

    public override func allocateRenderResources() throws {
        if kernelAdapter.outputBus.format.channelCount != kernelAdapter.inputBus.format.channelCount {
            throw NSError(domain: NSOSStatusErrorDomain, code: Int(kAudioUnitErr_FailedInitialization), userInfo: nil)
        }
        try super.allocateRenderResources()
        kernelAdapter.allocateRenderResources()
    }

    public override var channelCapabilities: [NSNumber]? {
        return [1, 1, 2, 2];
    }

    

    public override func deallocateRenderResources() {
        super.deallocateRenderResources()
        kernelAdapter.deallocateRenderResources()
    }

    public override var internalRenderBlock: AUInternalRenderBlock {
        return kernelAdapter.internalRenderBlock()
    }

    // Boolean indicating that this AU can process the input audio in-place
    // in the input buffer, without requiring a separate output buffer.
    public override var canProcessInPlace: Bool {
        return true
    }

    // MARK: View Configurations
    public override func supportedViewConfigurations(_ availableViewConfigurations: [AUAudioUnitViewConfiguration]) -> IndexSet {
        var indexSet = IndexSet()

        let config = AUAudioUnitViewConfiguration(width: 0.0, height: 0.0, hostHasController: false)
        for (_, _) in [config].enumerated() {
            indexSet.insert(0)
        }
        select(config)
        return indexSet
    }
}

extension FourCharCode {
    var stringValue: String {
        let value = CFSwapInt32BigToHost(self)
        let bytes = [0, 8, 16, 24].map { UInt8(value >> $0 & 0x000000FF) }
        guard let result = String(bytes: bytes, encoding: .utf8) else {
            return "fail"
        }
        return result
    }
}
