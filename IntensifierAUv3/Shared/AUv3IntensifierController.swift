import CoreAudioKit
public class AUv3IntensifierController: NSObject {
    public var audioUnitCreated: AUv3Intensifier? {
        didSet {
            audioUnitCreated?.viewController = self
        }
    }
    public func beginRequest(with context: NSExtensionContext) {
    }
}
