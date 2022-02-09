//
//  ViewController.swift
//  OCR
//
//  Created by Mathijs Bernson on 09/02/2022.
//

import Cocoa
import Foundation
import Vision

enum OCRState {
  case idle
  case pendingDrop
  case processing
  case finished
}

class ViewController: NSViewController {

  @IBOutlet weak var dropView: DropView!

  let textProcessor = TextProcessor()

  // MARK: View lifecycle

  override func viewDidLoad() {
    super.viewDidLoad()

    dropView.delegate = textProcessor

    view.registerForDraggedTypes([NSPasteboard.PasteboardType.fileURL])

    if let languages = supportedLanguages(recognitionLevel: .accurate) {
      print("Languages:")
      print(languages)
      // TODO: Create menu
    }
  }

  // MARK: Utilities

  private func supportedLanguages(recognitionLevel: VNRequestTextRecognitionLevel) -> [String]? {
    do {
      if #available(macOS 12.0, *) {
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = recognitionLevel
        let languages = try request.supportedRecognitionLanguages()
        return languages
      } else {
        let languages = try VNRecognizeTextRequest.supportedRecognitionLanguages(for: .accurate, revision: 1)
        return languages
      }
    } catch {
      NSLog("Unable to get supported languages")
      return nil
    }
  }
}
