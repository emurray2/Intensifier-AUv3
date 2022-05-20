import AudioKit
import AudioKitEX
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
        #if os(iOS)
            return Settings.headPhonesPlugged
        #endif
        #if !os(iOS)
            return false
        #endif
    }
    public var intensifier: Intensifier!
    init(_ componentDescription: AudioComponentDescription) {
        mic = engine.input!
        intensifier = Intensifier(mic, componentDescription)
        engine.output = intensifier
        do {
            #if os(iOS)
                try Settings.session.setCategory(.playAndRecord, options: [.defaultToSpeaker, .allowBluetooth, .allowBluetoothA2DP])
                try Settings.session.setActive(true)
            #endif
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
