//
//  ViewController.swift
//  Intensifier macOS
//
//  Created by Evan Murray on 6/9/21.
//

import Cocoa
import IntensifierAUv3Framework

class MainViewController: NSViewController {
    let audioUnitManager = AudioUnitManager()

    @IBOutlet var containerView: NSView!
    override func viewDidLoad() {
        super.viewDidLoad()
        embedPlugInView()
        audioUnitManager.inputAmountValue = 0.0
        audioUnitManager.attackAmountValue = -29.0
        audioUnitManager.releaseAmountValue = 5.0
        audioUnitManager.attackTimeValue = 149.0
        audioUnitManager.releaseTimeValue = 1.0
        audioUnitManager.outputAmountValue = 0.0
    }

    override func viewWillAppear() {
        super.viewWillAppear()
        view.window?.delegate = self
    }

    private func embedPlugInView() {
        guard let controller = audioUnitManager.viewController else {
            fatalError("Could not load audio unit's view controller.")
        }

        // Present the view controller's view.
        view = controller.view
        view.superview?.pinToSuperviewEdges()
    }

}
extension MainViewController: NSWindowDelegate {

    func windowWillClose(_ notification: Notification) {
        audioUnitManager.cleanup()
    }
}
extension NSView {
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
}

