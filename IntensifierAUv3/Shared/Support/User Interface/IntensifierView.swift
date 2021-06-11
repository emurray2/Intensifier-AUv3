class IntensifierView: NSView {

    // MARK: Properties
    let leftMargin: CGFloat = 54.0
    let rightMargin: CGFloat = 10.0
    let bottomMargin: CGFloat = 40.0

    var graphLayer = CALayer()
    var containerLayer = CALayer()

    var editPoint = CGPoint.zero
    var touchDown = false

    var rootLayer: CALayer {
        #if os(iOS)
        return layer
        #elseif os(macOS)
        return layer!
        #endif
    }

    var screenScale: CGFloat {
        #if os(iOS)
        return UIScreen.main.scale
        #elseif os(macOS)
        return NSScreen.main?.backingScaleFactor ?? 1.0
        #endif
    }
    func stringForValue(_ value: Float) -> String {
        var temp = value

        if value >= 1000 {
            temp /= 1000
        }

        temp = floor((temp * 100.0) / 100.0)

        if floor(temp) == temp {
            return String(format: "%.0f", temp)
        } else {
            return String(format: "%.1f", temp)
        }
    }

    #if os(macOS)
    override var isFlipped: Bool { return true }
    #endif

    private func newLayer(of size: CGSize) -> CALayer {
        let layer = CALayer()
        layer.anchorPoint = .zero
        layer.frame = CGRect(origin: .zero, size: size)
        layer.contentsScale = screenScale
        return layer
    }

    override func awakeFromNib() {
        super.awakeFromNib()

        // Create all of the CALayers for the graph, lines, and labels.

        containerLayer.name = "container"
        containerLayer.anchorPoint = .zero
        containerLayer.frame = CGRect(origin: .zero, size: rootLayer.bounds.size)
        containerLayer.bounds = containerLayer.frame
        containerLayer.contentsScale = screenScale
        rootLayer.addSublayer(containerLayer)
        rootLayer.masksToBounds = false

        graphLayer.name = "graph background"
        graphLayer.borderColor = NSColor.darkGray.cgColor
        graphLayer.borderWidth = 1.0
        graphLayer.backgroundColor = NSColor(white: 0.88, alpha: 1.0).cgColor
        graphLayer.bounds = CGRect(x: 0, y: 0,
                                   width: rootLayer.frame.width - leftMargin,
                                   height: rootLayer.frame.height - bottomMargin)
        graphLayer.position = CGPoint(x: leftMargin, y: 0)
        graphLayer.anchorPoint = CGPoint.zero
        graphLayer.contentsScale = screenScale

        containerLayer.addSublayer(graphLayer)

        rootLayer.contentsScale = screenScale
    }

    class ColorLayer: CALayer {

        init(white: CGFloat) {
            super.init()
            backgroundColor = NSColor(white: white, alpha: 1.0).cgColor
        }

        init(color: NSColor) {
            super.init()
            backgroundColor = color.cgColor
        }

        required init?(coder aDecoder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
    }
}

