//
//  DropView.swift
//  OCR
//
//  Created by Mathijs Bernson on 09/02/2022.
//  Copyright © 2022 Bernson. All rights reserved.
//

import Foundation
import Cocoa
import AudioToolbox

@objc protocol DropViewDelegate: AnyObject {
  func draggingEntered(forDropView dropView: DropView, sender: NSDraggingInfo) -> NSDragOperation
  func performDragOperation(forDropView dropView: DropView, sender: NSDraggingInfo) -> Bool
}

class DropView: NSView {
  weak var delegate: DropViewDelegate?

  @IBOutlet weak var progressIndicator: NSProgressIndicator!
  @IBOutlet weak var placeholderLabel: NSTextField!

  let successSound = NSSound(named: "Hero")

  var isHighlighted: Bool = false {
    didSet {
      needsDisplay = true
    }
  }

  var isLoading: Bool = false {
    didSet {
      progressIndicator.isHidden = !isLoading
      if isLoading {
        progressIndicator.startAnimation(nil)
      } else {
        progressIndicator.stopAnimation(nil)
      }
    }
  }

  override var acceptsFirstResponder: Bool {
    return true
  }

  override func awakeFromNib() {
    super.awakeFromNib()

    progressIndicator.isHidden = true

    TextProcessor.shared.delegate = self
  }

  override func draw(_ dirtyRect: NSRect) {
    super.draw(dirtyRect)

    if isHighlighted {
      NSGraphicsContext.saveGraphicsState()
      NSFocusRingPlacement.only.set()
      bounds.insetBy(dx: 2, dy: 2).fill()
      NSGraphicsContext.restoreGraphicsState()
    }
  }

  // MARK: - NSDraggingDestination

  override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
    var result: NSDragOperation = []
    if let delegate = delegate {
      result = delegate.draggingEntered(forDropView: self, sender: sender)
      isHighlighted = (result != [])
    }
    return result
  }

  override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
    isLoading = true
    placeholderLabel.isHidden = true

    return delegate?.performDragOperation(forDropView: self, sender: sender) ?? true
  }

  override func draggingExited(_ sender: NSDraggingInfo?) {
    isHighlighted = false
  }

  override func draggingEnded(_ sender: NSDraggingInfo) {
    isHighlighted = false
  }
}

extension DropView: TextProcessorDelegate {
  func textProcessedSuccessfully(atFileURL url: URL) {
    isLoading = false
    placeholderLabel.isHidden = false

    // Play sound
    successSound?.play()
  }

  func textProcessingDidError(_ error: Error) {
    isLoading = false
    placeholderLabel.isHidden = false

    // Show alert
    let alert = NSAlert(error: error)
    alert.runModal()
  }
}
