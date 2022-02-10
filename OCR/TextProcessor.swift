//
//  DropDelegate.swift
//  OCR
//
//  Created by Mathijs Bernson on 08/02/2022.
//  Copyright © 2022 Bernson. All rights reserved.
//

import Foundation
import AppKit
import Vision
import UniformTypeIdentifiers

struct TextProcessingResult: Identifiable {
  let id: UUID
  let strings: [String]

  init(strings: [String]) {
    self.id = UUID()
    self.strings = strings
  }
}

protocol TextProcessorDelegate: AnyObject {
  func textProcessedSuccessfully(atFileURL url: URL)
  func textProcessingDidError(_ error: Error)
}

class TextProcessor: NSObject, DropViewDelegate, PreferencesDelegate {

  // MARK: Public properties

  static let shared = TextProcessor()

  weak var delegate: TextProcessorDelegate?

  // MARK: Private properties

  private let supportedExtensions: Set<String> = ["jpg", "jpeg", "png"]

  private var customWords: [String]? = nil
  private var recognitionLanguages: [String] = []
  private var usesLanguageCorrection = false

  private override init() {
    // Private because this is a singleton
  }

  // MARK: DropViewDelegate

  func draggingEntered(forDropView dropView: DropView, sender: NSDraggingInfo) -> NSDragOperation {
    return sender.draggingSourceOperationMask.intersection([.copy])
  }

  func performDragOperation(forDropView dropView: DropView, sender: NSDraggingInfo) -> Bool {
    let supportedClasses = [NSURL.self]

    let searchOptions: [NSPasteboard.ReadingOptionKey: Any] = [
      .urlReadingFileURLsOnly: true,
      .urlReadingContentsConformToTypes: [ kUTTypeImage ]
    ]

    sender.enumerateDraggingItems(options: [], for: nil, classes: supportedClasses, searchOptions: searchOptions) { (draggingItem, _, _) in
      if let fileURL = draggingItem.item as? URL {
        do {
          try self.processFile(at: fileURL)
        } catch {
          self.handleError(error)
        }
      } else {
        print("Warning: Unrecognized dragging item received")
      }
    }

    return true
  }

  /// Note: gets called from a background thread
  private func processFile(at url: URL) throws {
    print("Image received: \(url.absoluteString)")

    guard let image = NSImage(contentsOf: url)?.cgImage(forProposedRect: nil, context: nil, hints: nil)
    else {
      throw RecognitionError.imageLoadFailed
    }

    let requestHandler = VNImageRequestHandler(cgImage: image)

    // Create a new request to recognize text.
    let request = VNRecognizeTextRequest(completionHandler: { request, error in
      if let error = error {
        self.handleError(error)
      } else if let request = request as? VNRecognizeTextRequest {
        do {
          let result = try self.processVisionResults(from: request, url: url)
          try self.writeResultsToFile(result: result, url: url)
        } catch {
          self.handleError(error)
        }
      }
    })
    request.recognitionLevel = .accurate
    request.recognitionLanguages = recognitionLanguages
    request.usesLanguageCorrection = usesLanguageCorrection
    if let customWords = customWords {
      request.customWords = customWords
    }

    try requestHandler.perform([request])
  }

  private func handleError(_ error: Error) {
    print("Error occurred: \(error.localizedDescription)")
    DispatchQueue.main.async {
      self.delegate?.textProcessingDidError(error)
    }
  }

  private func processVisionResults(from request: VNRecognizeTextRequest, url: URL) throws -> TextProcessingResult {
    guard let results = request.results, !results.isEmpty else {
      throw RecognitionError.noResults
    }

    print("Found \(results.count) results in file \(url.absoluteString)!")

    let strings: [String] = results.compactMap {
      $0.topCandidates(1).first?.string
    }
    let result = TextProcessingResult(strings: strings)

    return result
  }

  private func writeResultsToFile(result: TextProcessingResult, url: URL) throws {
    let downloadsFolder = try FileManager.default.url(for: .downloadsDirectory, in: .userDomainMask, appropriateFor: nil, create: false)
    let destination = downloadsFolder.appendingPathComponent(url.lastPathComponent)
      .appendingPathExtension("txt")
    print("Writing to: \(destination.absoluteString)")
    let string = result.strings.joined(separator: "\n")
    try string.write(to: destination, atomically: true, encoding: .utf8)
    DispatchQueue.main.async {
      self.delegate?.textProcessedSuccessfully(atFileURL: destination)
    }
  }

  // MARK: Utilities

  static func supportedLanguages(recognitionLevel: VNRequestTextRecognitionLevel) -> [String]? {
    do {
      if #available(macOS 12.0, *) {
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = recognitionLevel
        return try request.supportedRecognitionLanguages()
      } else if #available(macOS 11.0, *) {
        return try VNRecognizeTextRequest.supportedRecognitionLanguages(for: .accurate, revision: VNRecognizeTextRequestRevision2)
      } else {
        return try VNRecognizeTextRequest.supportedRecognitionLanguages(for: .accurate, revision: VNRecognizeTextRequestRevision1)
      }
    } catch {
      print("Unable to get supported languages")
      return nil
    }
  }

  // MARK: Preferences and options

  func setLanguagesForCorrection(_ languages: [String]) {
    recognitionLanguages = languages
    print("Languages for recognition set to: \(languages.joined(separator: ", "))")
  }

  func setUserDictionary(_ dictionary: [String]) {
    if dictionary.isEmpty {
      customWords = nil
      print("Custom dictionary saved: (empty)")
    } else {
      customWords = dictionary
      print("Custom dictionary saved: \(dictionary.joined(separator: ", "))")
    }
  }

  func setLanguageCorrectionEnabled(_ isLanguageCorrectionEnabled: Bool) {
    usesLanguageCorrection = isLanguageCorrectionEnabled

    if isLanguageCorrectionEnabled {
      print("Language correction enabled")
    } else {
      print("Language correction disabled")
    }
  }
}

struct RecognitionError: LocalizedError {
  let errorDescription: String?

  static let noResults = RecognitionError(errorDescription: NSLocalizedString("error.no.text.in.image", comment: "error"))
  static let imageLoadFailed = RecognitionError(errorDescription: NSLocalizedString("image.load.failed", comment: "error"))
}
