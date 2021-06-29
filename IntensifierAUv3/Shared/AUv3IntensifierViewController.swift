import CoreAudioKit
import WebKit

public class AUv3IntensifierViewController: AUViewController, WKUIDelegate, WKNavigationDelegate, WKScriptMessageHandler {

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

    var webView: WKWebView!

    var webPageLoaded = false

    var delegate: ToggleDelegate?
    var standaloneApp = false

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
    public override func loadView() {
        let resURL = Bundle(for: Swift.type(of: self)).resourceURL?.absoluteURL
        let myURL = Bundle(for: Swift.type(of: self)).url(forResource: "index", withExtension: "html")
        let webViewConfiguration = WKWebViewConfiguration()
        webViewConfiguration.userContentController.add(self, name: "typeListener")
        webViewConfiguration.userContentController.add(self, name: "valueListener")
        webView = WKWebView(frame: CGRect(x: 0, y: 0, width: 800.0, height: 500.0), configuration: webViewConfiguration)
        webView.loadFileURL(myURL!, allowingReadAccessTo: resURL!)
        webView.navigationDelegate = self
        view = webView
    }
    public override func viewDidLoad() {
        super.viewDidLoad()
        guard audioUnitCreated != nil else { return }
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
                if self.webPageLoaded {
                    self.updateUI()
                }
            }
        }

        // Observe value changes made to the parameters.
        parameterObserverToken =
            paramTree.token(byAddingParameterObserver: { [weak self] address, value in
                guard let self = self else { return }

                // This closure is being called by an arbitrary queue. Ensure
                // all UI updates are dispatched back to the main thread.
                if [inputAmount.address,
                    attackAmount.address,
                    releaseAmount.address,
                    attackTime.address,
                    releaseTime.address,
                    outputAmount.address].contains(address) {
                    DispatchQueue.main.async {
                        if self.webPageLoaded {
                            self.updateUI()
                        }
                    }
                }
            })

        // Indicate the view and AU are connected
        needsConnection = false
    }
    private func updateUI() {
        let scripts = [
            """
            angular.element(document.getElementsByClassName('app-container')).scope().initPreset("\(self.audioUnitCreated?.currentPreset?.name ?? "Subtle")");
            angular.element(document.getElementsByClassName('app-container')).scope().inputamount = \(inputAmountParameter.value.truncate(places: 2));
            angular.element(document.getElementsByClassName('app-container')).scope().attackamount = \(attackAmountParameter.value.truncate(places: 2));
            angular.element(document.getElementsByClassName('app-container')).scope().releaseamount = \(releaseAmountParameter.value.truncate(places: 2));
            angular.element(document.getElementsByClassName('app-container')).scope().attacktime = \(attackTimeParameter.value.truncate(places: 2));
            angular.element(document.getElementsByClassName('app-container')).scope().releasetime = \(releaseTimeParameter.value.truncate(places: 2));
            angular.element(document.getElementsByClassName('app-container')).scope().outputamount = \(outputAmountParameter.value.truncate(places: 2));

            var inputamountsliderbar = document.getElementsByClassName('slider')[0].children[1];
            var attackamountsliderbar = document.getElementsByClassName('slider')[1].children[1];
            var releaseamountsliderbar = document.getElementsByClassName('slider')[2].children[1];
            var attacktimesliderbar = document.getElementsByClassName('slider')[3].children[1];
            var releasetimesliderbar = document.getElementsByClassName('slider')[4].children[1];
            var outputamountsliderbar = document.getElementsByClassName('slider')[5].children[1];

            var inputamountsliderstyle = document.getElementsByClassName('slider')[0].children[2].attributes[1];
            var attackamountsliderstyle = document.getElementsByClassName('slider')[1].children[2].attributes[1];
            var releaseamountsliderstyle = document.getElementsByClassName('slider')[2].children[2].attributes[1];
            var attacktimesliderstyle = document.getElementsByClassName('slider')[3].children[2].attributes[1];
            var releasetimesliderstyle = document.getElementsByClassName('slider')[4].children[2].attributes[1];
            var outputamountsliderstyle = document.getElementsByClassName('slider')[5].children[2].attributes[1];

            if (typeof inputamountsliderstyle == 'undefined') {
                document.getElementsByClassName('slider')[0].children[2].setAttribute("style", "");
                inputamountsliderstyle = document.getElementsByClassName('slider')[0].children[2].attributes[1];
            }
            if (typeof attackamountsliderstyle == 'undefined') {
                document.getElementsByClassName('slider')[1].children[2].setAttribute("style", "");
                attackamountsliderstyle = document.getElementsByClassName('slider')[1].children[2].attributes[1];
            }
            if (typeof releaseamountsliderstyle == 'undefined') {
                document.getElementsByClassName('slider')[2].children[2].setAttribute("style", "");
                releaseamountsliderstyle = document.getElementsByClassName('slider')[2].children[2].attributes[1];
            }
            if (typeof attacktimesliderstyle == 'undefined') {
                document.getElementsByClassName('slider')[3].children[2].setAttribute("style", "");
                attacktimesliderstyle = document.getElementsByClassName('slider')[3].children[2].attributes[1];
            }
            if (typeof releasetimesliderstyle == 'undefined') {
                document.getElementsByClassName('slider')[4].children[2].setAttribute("style", "");
                releasetimesliderstyle = document.getElementsByClassName('slider')[4].children[2].attributes[1];
            }
            if (typeof outputamountsliderstyle == 'undefined') {
                document.getElementsByClassName('slider')[5].children[2].setAttribute("style", "");
                outputamountsliderstyle = document.getElementsByClassName('slider')[5].children[2].attributes[1];
            }

            var inputamountcurrvalue = angular.element(document.getElementsByClassName('app-container')).scope().inputamount;
            var attackamountcurrvalue = angular.element(document.getElementsByClassName('app-container')).scope().attackamount;
            var releaseamountcurrvalue = angular.element(document.getElementsByClassName('app-container')).scope().releaseamount;
            var attacktimecurrvalue = angular.element(document.getElementsByClassName('app-container')).scope().attacktime;
            var releasetimecurrvalue = angular.element(document.getElementsByClassName('app-container')).scope().releasetime;
            var outputamountcurrvalue = angular.element(document.getElementsByClassName('app-container')).scope().outputamount;

            var inputamountminvalue = angular.element(document.getElementsByClassName('app-container')).scope().$$childHead.minvalue;
            var attackamountminvalue = angular.element(document.getElementsByClassName('app-container')).scope().$$childHead.$$nextSibling.minvalue;
            var releaseamountminvalue = angular.element(document.getElementsByClassName('app-container')).scope().$$childHead.$$nextSibling.$$nextSibling.minvalue;
            var attacktimeminvalue = angular.element(document.getElementsByClassName('app-container')).scope().$$childHead.$$nextSibling.$$nextSibling.$$nextSibling.minvalue;
            var releasetimeminvalue = angular.element(document.getElementsByClassName('app-container')).scope().$$childHead.$$nextSibling.$$nextSibling.$$nextSibling.$$nextSibling.minvalue;
            var outputamountminvalue = angular.element(document.getElementsByClassName('app-container')).scope().$$childHead.$$nextSibling.$$nextSibling.$$nextSibling.$$nextSibling.$$nextSibling.minvalue;

            var inputamountmaxvalue = angular.element(document.getElementsByClassName('app-container')).scope().$$childHead.maxvalue;
            var attackamountmaxvalue = angular.element(document.getElementsByClassName('app-container')).scope().$$childHead.$$nextSibling.maxvalue;
            var releaseamountmaxvalue = angular.element(document.getElementsByClassName('app-container')).scope().$$childHead.$$nextSibling.$$nextSibling.maxvalue;
            var attacktimemaxvalue = angular.element(document.getElementsByClassName('app-container')).scope().$$childHead.$$nextSibling.$$nextSibling.$$nextSibling.maxvalue;
            var releasetimemaxvalue = angular.element(document.getElementsByClassName('app-container')).scope().$$childHead.$$nextSibling.$$nextSibling.$$nextSibling.$$nextSibling.maxvalue;
            var outputamountmaxvalue = angular.element(document.getElementsByClassName('app-container')).scope().$$childHead.$$nextSibling.$$nextSibling.$$nextSibling.$$nextSibling.$$nextSibling.maxvalue;

            var inputamountpercentoffset = (inputamountcurrvalue - inputamountminvalue) / (inputamountmaxvalue - inputamountminvalue);
            var attackamountpercentoffset = (attackamountcurrvalue - attackamountminvalue) / (attackamountmaxvalue - attackamountminvalue);
            var releaseamountpercentoffset = (releaseamountcurrvalue - releaseamountminvalue) / (releaseamountmaxvalue - releaseamountminvalue);
            var attacktimepercentoffset = (attacktimecurrvalue - attacktimeminvalue) / (attacktimemaxvalue - attacktimeminvalue);
            var releasetimepercentoffset = (releasetimecurrvalue - releasetimeminvalue) / (releasetimemaxvalue - releasetimeminvalue);
            var outputamountpercentoffset = (outputamountcurrvalue - outputamountminvalue) / (outputamountmaxvalue - outputamountminvalue);

            var inputamounthandleoffset = inputamountpercentoffset * inputamountsliderbar.offsetWidth;
            var attackamounthandleoffset = attackamountpercentoffset * attackamountsliderbar.offsetWidth;
            var releaseamounthandleoffset = releaseamountpercentoffset * releaseamountsliderbar.offsetWidth;
            var attacktimehandleoffset = attacktimepercentoffset * attacktimesliderbar.offsetWidth;
            var releasetimehandleoffset = releasetimepercentoffset * releasetimesliderbar.offsetWidth;
            var outputamounthandleoffset = outputamountpercentoffset * outputamountsliderbar.offsetWidth;

            inputamountsliderstyle.value = "left: " + inputamounthandleoffset + "px;";
            attackamountsliderstyle.value = "left: " + attackamounthandleoffset + "px;";
            releaseamountsliderstyle.value = "left: " + releaseamounthandleoffset + "px;";
            attacktimesliderstyle.value = "left: " + attacktimehandleoffset + "px;";
            releasetimesliderstyle.value = "left: " + releasetimehandleoffset + "px;";
            outputamountsliderstyle.value = "left: " + outputamounthandleoffset + "px;";

            document.getElementsByClassName('slider')[0].children[3].innerHTML = "\(inputAmountParameter.value.truncate(places: 2))&nbsp;dB";
            document.getElementsByClassName('slider')[1].children[3].innerHTML = "\(attackAmountParameter.value.truncate(places: 2))&nbsp;dB";
            document.getElementsByClassName('slider')[2].children[3].innerHTML = "\(releaseAmountParameter.value.truncate(places: 2))&nbsp;dB";
            document.getElementsByClassName('slider')[3].children[3].innerHTML = "\(attackTimeParameter.value.truncate(places: 2))&nbsp;ms";
            document.getElementsByClassName('slider')[4].children[3].innerHTML = "\(releaseTimeParameter.value.truncate(places: 2))&nbsp;sec";
            document.getElementsByClassName('slider')[5].children[3].innerHTML = "\(outputAmountParameter.value.truncate(places: 2))&nbsp;dB";
            "ok";
            """
        ]
        for script in scripts {
            webView.evaluateJavaScript(script) { (result, error) in
            }
        }
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
            let boolValue = message.body as? Bool
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
                case "Toggle":
                    delegate?.toggleValueDidChange(value: boolValue ?? false)
                case "Preset":
                    if let au = audioUnitCreated {
                        au.setPreset(number: valueToGet?.intValue ?? 0)
                    }
                default:
                    break
                }
            }
        }
    }
    public func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        webPageLoaded = true
        if standaloneApp == false {
            let script =
            """
            var controls = document.getElementsByClassName('controls-container');
            controls[0].removeChild(controls[0].childNodes[17]);
            controls[0].removeChild(controls[0].childNodes[15]);
            "ok";
            """
            webView.evaluateJavaScript(script) { (result, error) in
            }
        }
        updateUI()
    }
}
