import CoreAudioKit

extension AUv3IntensifierController: AUAudioUnitFactory {
    public func createAudioUnit(with componentDescription: AudioComponentDescription) throws -> AUAudioUnit {
        audioUnitCreated = try AUv3Intensifier(componentDescription: componentDescription, options: [])
        return audioUnitCreated!
    }
}
