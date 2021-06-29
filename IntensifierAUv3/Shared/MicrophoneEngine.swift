import AudioKit
import AVFoundation

public class Intensifier: Node {
    fileprivate var effectAU: AVAudioUnit!
    let input: Node
    public var connections: [Node] { [input] }
    public var avAudioNode: AVAudioNode { effectAU }
    public init(_ input: Node, _ componentDescription: AudioComponentDescription) {
        self.input = input
        self.effectAU = AVAudioUnitEffect(audioComponentDescription: componentDescription)
    }
}
public class MicrophoneEngine {
    let engine = AudioEngine()
    let mic: AudioEngine.InputNode
    var headphonesAreIn: Bool {
        Settings.headPhonesPlugged
    }
    public var intensifier: Intensifier!
    init(_ componentDescription: AudioComponentDescription) {
        mic = engine.input!
        intensifier = Intensifier(mic, componentDescription)
        engine.output = intensifier
        do {
            try Settings.session.setCategory(.playAndRecord, options: [.defaultToSpeaker, .allowBluetooth, .allowBluetoothA2DP])
            try Settings.session.setActive(true)
        } catch {
            print("failed to set avaudiosession")
        }
    }
    func start() {
        do {
            try engine.start()
        } catch let err {
            print(err.localizedDescription)
        }
    }
    func stop() {
        engine.stop()
    }
    func removeOutput() {
        engine.output = nil
    }
}
