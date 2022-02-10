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

protocol PreferencesDelegate: AnyObject {
  func setLanguagesForCorrection(_ languages: [String])
  func setUserDictionary(_ dictionary: [String])
  func setLanguageCorrectionEnabled(_ isLanguageCorrectionEnabled: Bool)
}

class ViewController: NSViewController {

  @IBOutlet weak var dropView: DropView!

  let userDefaults = UserDefaults.standard
  let textProcessor = TextProcessor.shared

  // MARK: View lifecycle

  override func viewDidLoad() {
    super.viewDidLoad()

    dropView.delegate = textProcessor

    view.registerForDraggedTypes([NSPasteboard.PasteboardType.fileURL])

    let isLanguageCorrectionEnabled: Bool = userDefaults.bool(forKey: UserDefaultsKey.isLanguageCorrectionEnabled.rawValue)
    textProcessor.setLanguageCorrectionEnabled(isLanguageCorrectionEnabled)

    let languagesForCorrection: [String] = userDefaults.array(forKey: UserDefaultsKey.languagesForCorrection.rawValue) as? [String] ?? []
    textProcessor.setLanguagesForCorrection(languagesForCorrection)

    let userDictionary: [String] = userDefaults.array(forKey: UserDefaultsKey.userDictionary.rawValue) as? [String] ?? []
    textProcessor.setUserDictionary(userDictionary)
  }
}
