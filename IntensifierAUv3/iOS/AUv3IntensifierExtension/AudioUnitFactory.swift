import CoreAudioKit
import IntensifierAUv3Framework

func placeholder() {
    // This placeholder function ensures the extension correctly loads.
}

extension AUv3IntensifierViewController {
    public func createAudioUnit(with componentDescription: AudioComponentDescription) throws -> AUAudioUnit {
        audioUnitCreated = try AUv3Intensifier(componentDescription: componentDescription, options: [])
        return audioUnitCreated!
    }
}

