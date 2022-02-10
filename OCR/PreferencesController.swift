//
//  PreferencesController.swift
//  OCR
//
//  Created by Mathijs Bernson on 10/02/2022.
//  Copyright © 2022 Bernson. All rights reserved.
//

import Foundation
import AppKit
import CoreMedia

enum UserDefaultsKey: String {
  case isLanguageCorrectionEnabled = "isLanguageCorrectionEnabled"
  case userDictionary = "userDictionary"
  case languagesForCorrection = "languagesForCorrection"
}

class PreferencesController: NSViewController, NSTextViewDelegate {

  weak var delegate: PreferencesDelegate?

  let supportedLanguages = TextProcessor.supportedLanguages(recognitionLevel: .accurate)
  var enabledLanguages: Set<String> = []
  var userDictionary: [String] = []

  let userDefaults = UserDefaults.standard
  let locale = NSLocale.current

  @IBOutlet weak var correctionEnabledButton: NSButtonCell!
  @IBOutlet weak var languagesTableView: NSTableView!
  @IBOutlet var dictionaryTextView: NSTextView!

  override func viewDidLoad() {
    super.viewDidLoad()

    self.delegate = TextProcessor.shared

    languagesTableView.dataSource = self
    languagesTableView.delegate = self

    languagesTableView.selectionHighlightStyle = .none

    loadSettings()
  }

  override func viewWillDisappear() {
    super.viewWillDisappear()

    saveUserDictionary()
  }

  func loadSettings() {
    let isLanguageCorrectionEnabled: Bool = userDefaults.bool(forKey: UserDefaultsKey.isLanguageCorrectionEnabled.rawValue)
    correctionEnabledButton.state = isLanguageCorrectionEnabled ? .on : .off
    languagesTableView.isEnabled = isLanguageCorrectionEnabled

    let languagesForCorrection: [String] = userDefaults.array(forKey: UserDefaultsKey.languagesForCorrection.rawValue) as? [String] ?? []
    self.enabledLanguages = Set(languagesForCorrection)

    let userDictionary: [String] = userDefaults.array(forKey: UserDefaultsKey.userDictionary.rawValue) as? [String] ?? []
    dictionaryTextView.string = userDictionary.joined(separator: "\n")
    self.userDictionary = userDictionary
  }

  func saveCorrectionLanguages() {
    let languages = Array(enabledLanguages)
    userDefaults.set(languages, forKey: UserDefaultsKey.languagesForCorrection.rawValue)
    delegate?.setLanguagesForCorrection(languages)
  }

  func saveUserDictionary() {
    let userDictionary = dictionaryTextView.string
      .components(separatedBy: "\n")
      .filter { !$0.isEmpty }

    userDefaults.set(userDictionary, forKey: UserDefaultsKey.userDictionary.rawValue)
    delegate?.setUserDictionary(userDictionary)
  }

  // MARK: NSTextViewDelegate

  func textDidEndEditing(_ notification: Notification) {
    saveUserDictionary()
  }

  // MARK: Actions

  @IBAction func toggleLanguageCorrection(_ sender: NSButton) {
    let isLanguageCorrectionEnabled = (sender.state == .on)
    languagesTableView.isEnabled = isLanguageCorrectionEnabled
    userDefaults.set(isLanguageCorrectionEnabled, forKey: UserDefaultsKey.isLanguageCorrectionEnabled.rawValue)
    delegate?.setLanguageCorrectionEnabled(isLanguageCorrectionEnabled)
  }
}

extension PreferencesController: NSTableViewDataSource, NSTableViewDelegate {
  func numberOfRows(in tableView: NSTableView) -> Int {
    return supportedLanguages?.count ?? 0
  }

  func tableView(_ tableView: NSTableView, objectValueFor tableColumn: NSTableColumn?, row: Int) -> Any? {
    guard let languageCode = supportedLanguages?[row] else { return nil }

    switch tableColumn?.identifier.rawValue {
    case "enabledColumn":
      return enabledLanguages.contains(languageCode)
    case "titleColumn":
      if let localizedString = locale.localizedString(forLanguageCode: languageCode) {
        return "\(localizedString) (\(languageCode))"
      } else {
        return languageCode
      }
    default:
      return nil
    }
  }

  func tableView(_ tableView: NSTableView, setObjectValue object: Any?, for tableColumn: NSTableColumn?, row: Int) {
    switch tableColumn?.identifier.rawValue {
    case "enabledColumn":
      if let isEnabled = object as? Bool, let languageCode = supportedLanguages?[row] {
        if isEnabled {
          enabledLanguages.insert(languageCode)
        } else {
          enabledLanguages.remove(languageCode)
        }
        saveCorrectionLanguages()
      }
    default:
      break
    }
  }
}
