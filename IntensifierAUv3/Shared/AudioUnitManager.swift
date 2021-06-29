import Foundation
import AudioToolbox
import CoreAudioKit
import AVFoundation

protocol ToggleDelegate: AnyObject {
    func toggleValueDidChange(value: Bool)
}

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

    /// The microphone engine used to record audio.
    private var micEngine: MicrophoneEngine?

    private var inputAmountParameter: AUParameter!
    private var attackAmountParameter: AUParameter!
    private var releaseAmountParameter: AUParameter!
    private var attackTimeParameter: AUParameter!
    private var releaseTimeParameter: AUParameter!
    private var outputAmountParameter: AUParameter!
    private var parameterObserverToken: AUParameterObserverToken!

    // The AudioComponentDescription matching the AUv3IntensifierExtension Info.plist
    private var componentDescription: AudioComponentDescription = {
        // Ensure that AudioUnit type, subtype, and manufacturer match the extension's Info.plist values
        var componentDescription = AudioComponentDescription()
        componentDescription.componentType = kAudioUnitType_Effect
        componentDescription.componentSubType = 0x696e7465 /*'inte'*/
        componentDescription.componentManufacturer = 0x45766d75 /*'Evmu'*/
        componentDescription.componentFlags = 0x0000001e
        componentDescription.componentFlagsMask = 0
        return componentDescription
    }()
    private let componentName = "Evan Murray: Intensifier AUv3"

    public init() {

        viewController = loadViewController()

        /*
         Register our `AUAudioUnit` subclass, `AUv3Intensifier`, to make it able
         to be instantiated via its component description.

         Note that this registration is local to this process.
         */
        AUAudioUnit.registerSubclass(AUv3Intensifier.self,
                                     as: componentDescription,
                                     name: componentName,
                                     version: UInt32.max)
        self.micEngine = MicrophoneEngine(componentDescription)
        self.audioUnit = self.micEngine?.intensifier.avAudioNode.auAudioUnit as? AUv3Intensifier
        self.connectParametersToControls()
        self.viewController.delegate = self
        self.viewController.standaloneApp = true
    }
    // Loads the audio unit's view controller from the extension bundle.
    private func loadViewController() -> AUv3IntensifierViewController {
        let controller = AUv3IntensifierViewController()
        return controller
    }
    /**
     Called after instantiating our audio unit, to find the AU's parameters and
     connect them to our controls.
     */
    private func connectParametersToControls() {

        guard let audioUnit = audioUnit else {
            fatalError("Couldn't locate AUv3Intensifier")
        }

        viewController.audioUnitCreated = audioUnit

        // Find our parameters by their identifiers.
        guard let parameterTree = audioUnit.parameterTree else {
            fatalError("AUv3Intensifier does not define any parameters.")
        }

        inputAmountParameter = parameterTree.value(forKey: "inputAmount") as? AUParameter
        attackAmountParameter = parameterTree.value(forKey: "attackAmount") as? AUParameter
        releaseAmountParameter = parameterTree.value(forKey: "releaseAmount") as? AUParameter
        attackTimeParameter = parameterTree.value(forKey: "attackTime") as? AUParameter
        releaseTimeParameter = parameterTree.value(forKey: "releaseTime") as? AUParameter
        outputAmountParameter = parameterTree.value(forKey: "outputAmount") as? AUParameter

        parameterObserverToken = parameterTree.token(byAddingParameterObserver: { [weak self] address, _ in
            guard let self = self else { return }
            /*
             This is called when one of the parameter values changes.
             We can only update UI from the main queue.
             */
            DispatchQueue.main.async {
                if address == self.inputAmountParameter.address {
                    self.updateInputAmount()
                } else if address == self.attackAmountParameter.address {
                    self.updateAttackAmount()
                } else if address == self.releaseAmountParameter.address {
                    self.updateReleaseAmount()
                } else if address == self.attackTimeParameter.address {
                    self.updateAttackTime()
                } else if address == self.releaseTimeParameter.address {
                    self.updateReleaseTime()
                } else if address == self.outputAmountParameter.address {
                    self.updateOutputAmount()
                }
            }
        })
    }

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
    public func cleanup() {
        micEngine?.stop()
        guard let parameterTree = audioUnit?.parameterTree else { return }
        parameterTree.removeParameterObserver(parameterObserverToken)
    }
}

// Notify the AudioUnitManager if the toggle inside the AU View is pressed
extension AudioUnitManager: ToggleDelegate {
    #if os(macOS)
        func showWarning(warning: String, text: String) -> Bool {
            let alert: NSAlert = NSAlert()
            alert.messageText = warning
            alert.showsSuppressionButton = true
            alert.informativeText = text
            alert.alertStyle = NSAlert.Style.warning
            alert.addButton(withTitle: "Proceed")
            alert.addButton(withTitle: "Cancel")
            let res = alert.runModal()
            if res == NSApplication.ModalResponse.alertFirstButtonReturn {
                if alert.suppressionButton!.state.rawValue == 1 {
                    UserDefaults.standard.setValue(1, forKey: "hidewarning")
                } else {
                    UserDefaults.standard.setValue(0, forKey: "hidewarning")
                }
                return true
            } else {
                if alert.suppressionButton!.state.rawValue == 1 {
                    UserDefaults.standard.setValue(1, forKey: "hidewarning")
                } else {
                    UserDefaults.standard.setValue(0, forKey: "hidewarning")
                }
                return false
            }
        }
    #endif
    #if os(iOS)
    func showWarningMobile(warning: String, text: String) {
        let alert = UIAlertController(title: warning, message: text, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: NSLocalizedString("Proceed", comment: "Default action"), style: .default, handler: { _ in
            if let micEngine = self.micEngine {
                micEngine.start()
            }
        }))
        alert.addAction(UIAlertAction(title: NSLocalizedString("Cancel", comment: "Cancel action"), style: .cancel, handler: { _ in
            let script =
            """
            angular.element(document.getElementsByClassName('app-container')).scope().$$childTail.property = false;
            angular.element(document.getElementsByClassName('app-container')).scope().$apply();
            "ok"
            """
            self.viewController.webView.evaluateJavaScript(script) { (result, error) in
            }
        }))
        self.viewController.present(alert, animated: true, completion: nil)
    }
    #endif

    public func toggleValueDidChange(value: Bool) {
        #if os(macOS)
            let hideWarning = UserDefaults.standard.integer(forKey: "hidewarning")
            if hideWarning == 1 {
                if value == true {
                    if let micEngine = micEngine {
                        micEngine.start()
                    }
                } else {
                    if let micEngine = micEngine {
                        micEngine.stop()
                    }
                }
            } else {
                if value == true {
                    let result = showWarning(warning: "Feedback Warning", text: "This may turn on audio input from the microphone. Headphones are recommended.")
                    if result == true {
                        if let micEngine = micEngine {
                            micEngine.start()
                        }
                    } else {
                        let script =
                        """
                        angular.element(document.getElementsByClassName('app-container')).scope().$$childTail.property = false;
                        angular.element(document.getElementsByClassName('app-container')).scope().$apply();
                        "ok"
                        """
                        self.viewController.webView.evaluateJavaScript(script) { (result, error) in
                        }
                    }
                } else {
                    if let micEngine = micEngine {
                        micEngine.stop()
                    }
                }
            }
        #endif
        #if os(iOS)
            if value == true {
                if let micEngine = micEngine {
                    if micEngine.headphonesAreIn {
                        micEngine.start()
                    } else {
                        showWarningMobile(warning: "Feedback Warning", text: "This may turn on audio input from the microphone. Headphones are recommended.")
                    }
                }
            } else {
                if let micEngine = micEngine {
                    micEngine.stop()
                }
            }
        #endif
    }
}
