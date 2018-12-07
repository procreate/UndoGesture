/*

BSD 2-Clause License

Copyright (c) 2018, Savage Interactive Pty Ltd
All rights reserved.

Redistribution and use in source and binary forms, with or without
modification, are permitted provided that the following conditions are met:

* Redistributions of source code must retain the above copyright notice, this
list of conditions and the following disclaimer.

* Redistributions in binary form must reproduce the above copyright notice,
this list of conditions and the following disclaimer in the documentation
and/or other materials provided with the distribution.

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE
FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER
CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY,
OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.


*/

import UIKit

private let DefaultCircleCount: Int = 5

final class UndoGestureViewController: UIViewController {
	@IBOutlet private var circles: [UIView]!
	@IBOutlet private var rings: [UIView]!
	@IBOutlet private var transformView: UIView!

	private var simultaneousGestures: [UIGestureRecognizer] = []

	private var circleCount: Int = DefaultCircleCount
}

extension UndoGestureViewController {
	override func viewDidLoad() {
		super.viewDidLoad()

		let undoGesture = UITapGestureRecognizer(target: self, action: #selector(UndoGestureViewController.undoAction(_:)))
		undoGesture.numberOfTouchesRequired = 2

		let redoGesture = UITapGestureRecognizer(target: self, action: #selector(UndoGestureViewController.redoAction(_:)))
		redoGesture.numberOfTouchesRequired = 3

		let tapGestures: [UIGestureRecognizer] = [undoGesture, redoGesture]
		for tap in tapGestures {
			view.addGestureRecognizer(tap)
		}
		
		let pinchGesture = UIPinchGestureRecognizer(target: self, action: #selector(UndoGestureViewController.pinchAction(_:)))
		let rotationGesture = UIRotationGestureRecognizer(target: self, action: #selector(UndoGestureViewController.rotationAction(_:)))
		let panGesture = UIPanGestureRecognizer(target: self, action: #selector(UndoGestureViewController.panAction(_:)))

		let manipulationGestures = [pinchGesture, rotationGesture, panGesture]
		for manipulation in manipulationGestures {
			manipulation.delegate = self
			view.addGestureRecognizer(manipulation)

			// Require all taps to wait for these gestures
			for tap in tapGestures {
				tap.require(toFail: manipulation)
			}
		}

		// We will allow pinch, rotate and pan to recognise simultaneously.
		simultaneousGestures.append(contentsOf: manipulationGestures)
		
		addCircleLayers()
		addRingLayers()
	}

	override func viewWillAppear(_ animated: Bool) {
		super.viewWillAppear(animated)
		
		resetTransform(with: view.bounds.size)
	}
	
	override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
		resetTransform(with: size)
	}
	
	private func resetTransform(with size: CGSize) {
		let ratio = size.width/1024
		let transform = CGAffineTransform(scaleX: ratio, y: ratio)
		transformView.transform = transform.concatenating(CGAffineTransform(translationX: size.width/2, y: size.height/2))
	}
	
	override var preferredStatusBarStyle: UIStatusBarStyle {
		return .lightContent
	}

	func addCircleLayers() {
		for circle in circles {
			let shape = CAShapeLayer()
			shape.fillColor = #colorLiteral(red: 0, green: 0.462745098, blue: 1, alpha: 1)
			shape.path = UIBezierPath(ovalIn: CGRect(x: 0, y: 0, width: 90, height: 90)).cgPath
			circle.layer.addSublayer(shape)
		}
	}
	func addRingLayers() {
		for ring in rings {
			let shape = CAShapeLayer()
			shape.strokeColor = #colorLiteral(red: 0, green: 0.462745098, blue: 1, alpha: 1)
			shape.fillColor = nil
			shape.lineWidth = 4
			shape.path = UIBezierPath(ovalIn: CGRect(x: 0, y: 0, width: 90, height: 90)).cgPath
			ring.layer.addSublayer(shape)
		}
	}
}

extension UndoGestureViewController {
	@objc func undoAction(_ gesture: UIGestureRecognizer) {
		if gesture.state == .ended {
			if circleCount > 0 {
				circleCount -= 1
				circles.first(where: { $0.tag == circleCount })?.alpha = 0
			}
		}
	}
	@objc func redoAction(_ gesture: UIGestureRecognizer) {
		if gesture.state == .ended {
			if circleCount < DefaultCircleCount {
				circles.first(where: { $0.tag == circleCount })?.alpha = 1
				circleCount += 1
			}
		}
	}


	// Handle the zoom and pan gestures, anchoring by the average location of the touches.
	// This anchor point feels natural, like you're manipulating a piece of paper.

	@objc func pinchAction(_ gesture: UIPinchGestureRecognizer) {
		let anchor = gesture.location(in: view)

		let initialScale = transformView.transform.scale
		let totalScale = min(max(gesture.scale*initialScale, 0.125), 8)
		let scaling = totalScale/initialScale

		var transform = CGAffineTransform(translationX: anchor.x, y: anchor.y)
		transform = transform.scaledBy(x: scaling, y: scaling)
		transform = transform.translatedBy(x: -anchor.x, y: -anchor.y)

		transformView.transform = transformView.transform.concatenating(transform)

		gesture.scale = 1
	}
	@objc func rotationAction(_ gesture: UIRotationGestureRecognizer) {
		let anchor = gesture.location(in: view)

		var transform = CGAffineTransform(translationX: anchor.x, y: anchor.y)
		transform = transform.rotated(by: gesture.rotation)
		transform = transform.translatedBy(x: -anchor.x, y: -anchor.y)

		transformView.transform = transformView.transform.concatenating(transform)

		gesture.rotation = 0
	}
	@objc func panAction(_ gesture: UIPanGestureRecognizer) {
		let translation = gesture.translation(in: view)

		let transform = CGAffineTransform(translationX: translation.x, y: translation.y)
		transformView.transform = transformView.transform.concatenating(transform)

		gesture.setTranslation(.zero, in: view)
	}
}

extension UndoGestureViewController: UIGestureRecognizerDelegate {
	func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
		return simultaneousGestures.contains(gestureRecognizer) && simultaneousGestures.contains(otherGestureRecognizer)
	}
}
