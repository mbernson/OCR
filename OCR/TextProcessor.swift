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

class TextProcessor: NSObject, DropViewDelegate {
  weak var delegate: TextProcessorDelegate?

  // TODO: Custom dictionary support
  let customWords: [String]? = nil
  let recognitionLanguages: [String] = ["nl-NL", "en-US"]
  let supportedExtensions: Set<String> = ["jpg", "jpeg", "png"]
  let usesLanguageCorrection = false

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

  //  /// validates if a drop can be made
  //  func validateDrop(info: DropInfo) -> Bool {
  //    guard info.hasItemsConforming(to: draggedFileTypes)
  //    else { return false }
  //
  //    let items = info.itemProviders(for: draggedFileTypes)
  //    return !items.isEmpty
  //  }
  //
  //  /// provides custom behavior when an object is dragged over the onDrop view
  //  func dropEntered(info: DropInfo) {
  //    state = .pendingDrop
  //  }
  //
  //  /// provides custom behavior when an object is dragged off of the onDrop view
  //  func dropExited(info: DropInfo) {
  //    state = .idle
  //  }
  //
  //  func performDrop(info: DropInfo) -> Bool {
  //    state = .processing
  //
  //    let items = info.itemProviders(for: draggedFileTypes)
  //    for item in items {
  //      _ = item.loadObject(ofClass: URL.self) { url, _ in
  //        if let url = url, supportedExtensions.contains(url.pathExtension) {
  //          do {
  //            try processFile(at: url)
  //          } catch {
  //            handleError(error: error)
  //          }
  //        }
  //      }
  //    }
  //
  //    return true
  //  }

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
          //          state = .idle
          //          self.results.append(result)
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
    // TODO
    print("Error occurred: \(error.localizedDescription)")
    delegate?.textProcessingDidError(error)
  }

  private func processVisionResults(from request: VNRecognizeTextRequest, url: URL) throws -> TextProcessingResult {
    guard let results = request.results, !results.isEmpty else {
      throw RecognitionError.noResults
    }

    print("Found \(results.count) results in file \(url.absoluteString)!")
    let result = TextProcessingResult(strings: results.compactMap {
      $0.topCandidates(1).first?.string
    })
    return result
  }

  private func writeResultsToFile(result: TextProcessingResult, url: URL) throws {
    let downloadsFolder = try FileManager.default.url(for: .downloadsDirectory, in: .userDomainMask, appropriateFor: nil, create: false)
    let destination = downloadsFolder.appendingPathComponent(url.lastPathComponent)
      .appendingPathExtension("txt")
    print("Writing to: \(destination.absoluteString)")
    let string = result.strings.joined(separator: "\n")
    try string.write(to: destination, atomically: true, encoding: .utf8)
    delegate?.textProcessedSuccessfully(atFileURL: destination)
  }
}

struct RecognitionError: LocalizedError {
  let errorDescription: String?

  static let noResults = RecognitionError(errorDescription: "No text was found.")
  static let imageLoadFailed = RecognitionError(errorDescription: "Failed to load image.")
}
