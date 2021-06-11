import CoreAudioKit
public class AUv3IntensifierController: NSObject {
    public var audioUnitCreated: AUv3Intensifier? {
        didSet {
            //audioUnitCreated?.viewController = self
        }
    }
    public func beginRequest(with context: NSExtensionContext) {
    }
}

public class AUv3IntensifierViewController: AUViewController {

    let compact = AUAudioUnitViewConfiguration(width: 400, height: 100, hostHasController: false)
    let expanded = AUAudioUnitViewConfiguration(width: 800, height: 500, hostHasController: false)
    private var viewConfig: AUAudioUnitViewConfiguration!

    @IBOutlet var intensifierView: IntensifierView!

    @IBOutlet var expandedView: NSView! {
        didSet {
            expandedView.setBorder(color: .black, width: 1)
        }
    }

    @IBOutlet var compactView: NSView! {
        didSet {
            compactView.setBorder(color: .black, width: 1)
        }
    }
    public var viewConfigurations: [AUAudioUnitViewConfiguration] {
        // width: 0 height:0  is always supported, should be the default, largest view.
        return [expanded, compact]
    }
    public var audioUnitCreated: AUv3Intensifier? {
        didSet {
            audioUnitCreated?.viewController = self
            performOnMain {
                if self.isViewLoaded {
                    //self.connectViewToAU()
                }
            }
        }
    }
    public override init(nibName: NSNib.Name?, bundle: Bundle?) {
        // Pass a reference to the owning framework bundle
        super.init(nibName: nibName, bundle: Bundle(for: type(of: self)))
    }
    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }
    public override func viewDidLoad() {
        super.viewDidLoad()

        preferredContentSize = CGSize(width: 800, height: 500)

        view.addSubview(expandedView)
        expandedView.pinToSuperviewEdges()

        // Set the default view configuration.
        viewConfig = expanded

        // Respond to changes in the filterView (frequency and/or response changes).
        //filterView.delegate = self

        #if os(iOS)
        //frequencyTextField.delegate = self
        //resonanceTextField.delegate = self
        #endif

        guard audioUnitCreated != nil else { return }

        // Connect the user interface to the AU parameters, if needed.
        //connectViewToAU()
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
