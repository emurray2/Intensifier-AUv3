import CoreAudioKit
import WebKit

public class AUv3IntensifierViewController: AUViewController, WKUIDelegate, WKNavigationDelegate, WKScriptMessageHandler, NSWindowDelegate {
    private var viewConfig: AUAudioUnitViewConfiguration!

    private var inputAmountParameter: AUParameter!
    private var attackAmountParameter: AUParameter!
    private var releaseAmountParameter: AUParameter!
    private var attackTimeParameter: AUParameter!
    private var releaseTimeParameter: AUParameter!
    private var outputAmountParameter: AUParameter!
    private var parameterObserverToken: AUParameterObserverToken?

    // Variables for the Javascript Messages
    var type = ""
    var value: Float = 0

    var observer: NSKeyValueObservation?

    var needsConnection = true
    public var audioUnitCreated: AUv3Intensifier? {
        didSet {
            audioUnitCreated?.viewController = self
            performOnMain {
                if self.isViewLoaded {
                    self.connectViewToAU()
                }
            }
        }
    }
    public override init(nibName: NSNib.Name?, bundle: Bundle?) {
        // Pass a reference to the owning framework bundle
        super.init(nibName: nil, bundle: Bundle(for: Swift.type(of: self)))
    }
    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }
    public override func loadView() {
        view = NSView(frame: CGRect(x:0, y: 0, width: 800.0, height: 500.0))
        view.setBoundsSize(NSSize(width: 800.0, height: 500.0))
    }
    public override func viewWillAppear() {
    }
    public override func viewDidAppear() {
        super.viewDidAppear()
        self.view.window!.styleMask.remove(.resizable)
        view.window!.maxSize = NSSize(width: 800.0, height: 500.0)
        view.window!.minSize = NSSize(width: 800.0, height: 500.0)
        view.window!.maxFullScreenContentSize = NSSize(width: 800.0, height: 500.0)
        view.window!.minFullScreenContentSize = NSSize(width: 800.0, height: 500.0)
    }
    public override func viewDidLoad() {
        super.viewDidLoad()
        guard audioUnitCreated != nil else { return }
        let resURL = Bundle(for: Swift.type(of: self)).resourceURL?.absoluteURL
        let myURL = Bundle(for: Swift.type(of: self)).url(forResource: "index", withExtension: "html")
        let webViewConfiguration = WKWebViewConfiguration()
        webViewConfiguration.userContentController.add(self, name: "typeListener")
        webViewConfiguration.userContentController.add(self, name: "valueListener")
        let webView = WKWebView(frame: CGRect(x: 0, y: 0, width: 800.0, height: 500.0), configuration: webViewConfiguration)
        webView.loadFileURL(myURL!, allowingReadAccessTo: resURL!)
        if #available(macOSApplicationExtension 11.0, *) {
            webView.pageZoom = 0.75
        } else {
            // Fallback on earlier versions
        }
        view.addSubview(webView)
        connectViewToAU()
    }
    private func connectViewToAU() {
        guard needsConnection, let paramTree = audioUnitCreated?.parameterTree else { return }

        // Find the cutoff and resonance parameters in the parameter tree.
        guard let inputAmount = paramTree.value(forKey: "inputAmount") as? AUParameter,
            let attackAmount = paramTree.value(forKey: "attackAmount") as? AUParameter,
            let releaseAmount = paramTree.value(forKey: "releaseAmount") as? AUParameter,
            let attackTime = paramTree.value(forKey: "attackTime") as? AUParameter,
            let releaseTime = paramTree.value(forKey: "releaseTime") as? AUParameter,
            let outputAmount = paramTree.value(forKey: "outputAmount") as? AUParameter else {
                fatalError("Required AU parameters not found.")
        }

        // Set the instance variables.
        inputAmountParameter = inputAmount
        attackAmountParameter = attackAmount
        releaseAmountParameter = releaseAmount
        attackTimeParameter = attackTime
        releaseTimeParameter = releaseTime
        outputAmountParameter = outputAmount

        // Indicate the view and AU are connected
        needsConnection = false
    }
    func performOnMain(_ operation: @escaping () -> Void) {
        if Thread.isMainThread {
            operation()
        } else {
            DispatchQueue.main.async {
                operation()
            }
        }
    }
    public func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        if message.name == "typeListener" {
            let stringToGet = message.body as? NSString
            type = stringToGet?.substring(from: 0) ?? ""
        }
        if message.name == "valueListener" {
            let valueToGet = message.body as? NSNumber
            value = valueToGet?.floatValue ?? 0
            if type != "" {
                switch type {
                case "Input Amount":
                inputAmountParameter.setValue(value, originator: nil, atHostTime: 0, eventType: .touch)
                case "Attack Amount":
                attackAmountParameter.setValue(value, originator: nil, atHostTime: 0, eventType: .touch)
                case "Release Amount":
                releaseAmountParameter.setValue(value, originator: nil, atHostTime: 0, eventType: .touch)
                case "Attack Time":
                attackTimeParameter.setValue(value, originator: nil, atHostTime: 0, eventType: .touch)
                case "Release Time":
                releaseTimeParameter.setValue(value, originator: nil, atHostTime: 0, eventType: .touch)
                case "Output Amount":
                outputAmountParameter.setValue(value, originator: nil, atHostTime: 0, eventType: .touch)
                default:
                    break
                }
            }
        }
    }
}

public extension NSView {
    func pinToSuperviewEdges() {
        guard let superview = superview else { return }
        translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            topAnchor.constraint(equalTo: superview.topAnchor),
            leadingAnchor.constraint(equalTo: superview.leadingAnchor),
            bottomAnchor.constraint(equalTo: superview.bottomAnchor),
            trailingAnchor.constraint(equalTo: superview.trailingAnchor)
        ])
    }

    func setBorder(color: NSColor, width: CGFloat) {
        #if os(iOS)
        layer.borderColor = color.cgColor
        layer.borderWidth = CGFloat(width)
        #elseif os(macOS)
        layer?.borderColor = color.cgColor
        layer?.borderWidth = CGFloat(width)
        #endif
    }
}
