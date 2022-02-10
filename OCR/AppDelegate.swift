//
//  AppDelegate.swift
//  OCR
//
//  Created by Mathijs Bernson on 09/02/2022.
//

import Cocoa

@main
class AppDelegate: NSObject, NSApplicationDelegate {

  func applicationDidFinishLaunching(_ aNotification: Notification) {
    // Insert code here to initialize your application

    UserDefaults.standard.register(defaults: [
      UserDefaultsKey.isLanguageCorrectionEnabled.rawValue: true,
      UserDefaultsKey.languagesForCorrection.rawValue: [String](),
      UserDefaultsKey.userDictionary.rawValue: [String](),
    ])
  }

  func applicationWillTerminate(_ aNotification: Notification) {
    // Insert code here to tear down your application
  }

  func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
    return true
  }
}

