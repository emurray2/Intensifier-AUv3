//
//  ViewController.swift
//  Intensifier iOS
//
//  Created by Evan Murray on 6/14/21.
//

import UIKit
import IntensifierAUv3Framework

class ViewController: UIViewController {

    let audioUnitManager = AudioUnitManager()
    @IBOutlet var containerView: UIView!
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

    private func embedPlugInView() {
        guard let controller = audioUnitManager.viewController else {
            fatalError("Could not load audio unit's view controller.")
        }

        // Present the view controller's view.
        if let view = controller.view {
            addChild(controller)
            view.frame = containerView.bounds
            containerView.addSubview(view)
            view.pinToSuperviewEdges()
            controller.didMove(toParent: self)
        }
    }

}

extension UIView {
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

