import CoreAudioKit
import WebKit
public class AUv3IntensifierController: NSObject {
    public var audioUnitCreated: AUv3Intensifier? {
        didSet {
            //audioUnitCreated?.viewController = self
        }
    }
    public func beginRequest(with context: NSExtensionContext) {
    }
}

public class AUv3IntensifierViewController: AUViewController, WKUIDelegate, WKNavigationDelegate, WKScriptMessageHandler, NSWindowDelegate {
    public func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
    }
    private var viewConfig: AUAudioUnitViewConfiguration!

    private var inputAmountParameter: AUParameter!
    private var attackAmountParameter: AUParameter!
    private var releaseAmountParameter: AUParameter!
    private var attackTimeParameter: AUParameter!
    private var releaseTimeParameter: AUParameter!
    private var outputAmountParameter: AUParameter!
    private var parameterObserverToken: AUParameterObserverToken?

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
        super.init(nibName: nil, bundle: Bundle(for: type(of: self)))
    }
    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }
    public override func loadView() {
        view = NSView(frame: CGRect(x:0, y: 0, width: 1040.0, height: 650.0))
        view.setBoundsSize(NSSize(width: 1040.0, height: 650.0))
    }
    public override func viewWillAppear() {
        view.window!.maxSize = NSSize(width: 1040.0, height: 650.0)
        view.window!.minSize = NSSize(width: 1040.0, height: 650.0)
        view.window!.maxFullScreenContentSize = NSSize(width: 1040.0, height: 650.0)
        view.window!.minFullScreenContentSize = NSSize(width: 1040.0, height: 650.0)
    }
    public override func viewDidAppear() {
        super.viewDidAppear()
        self.view.window!.styleMask.remove(.resizable)
    }
    public override func viewDidLoad() {
        super.viewDidLoad()
        guard audioUnitCreated != nil else { return }
        let resURL = Bundle(for: type(of: self)).resourceURL?.absoluteURL
        let myURL = Bundle(for: type(of: self)).url(forResource: "index", withExtension: "html")
        let webViewConfiguration = WKWebViewConfiguration()
        let webView = WKWebView(frame: CGRect(x: 0, y: 0, width: 1040.0, height: 650.0), configuration: webViewConfiguration)
        webView.loadFileURL(myURL!, allowingReadAccessTo: resURL!)
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

        // Observe major state changes like a user selecting a user preset.
        observer = audioUnitCreated?.observe(\.allParameterValues) { object, change in
            DispatchQueue.main.async {
                //self.updateUI()
            }
        }

        // Observe value changes made to the cutoff and resonance parameters.
        parameterObserverToken =
            paramTree.token(byAddingParameterObserver: { [weak self] address, value in
                guard self != nil else { return }

                // This closure is being called by an arbitrary queue. Ensure
                // all UI updates are dispatched back to the main thread.
                if [inputAmount.address,
                    attackAmount.address,
                    releaseAmount.address,
                    attackTime.address,
                    releaseTime.address,
                    outputAmount.address].contains(address) {
                    DispatchQueue.main.async {
                        //self.updateUI()
                    }
                }
            })

        // Indicate the view and AU are connected
        needsConnection = false

        // Sync UI with parameter state
        //updateUI()
    }
    // MARK: View Configuration Selection

    public func toggleViewConfiguration() {
        // Let the audio unit call selectViewConfiguration instead of calling
        // it directly to ensure validate the audio unit's behavior.
        //audioUnitCreated?.select(viewConfig == expanded ? compact : expanded)
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
