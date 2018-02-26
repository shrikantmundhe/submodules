//
//  Plaid.swift
//  NoWrapJustCache
//
//  Created by Kishyr Ramdial on 2015/04/14.
//  Copyright (c) 2015 MGS. All rights reserved.
//

import UIKit

open class Plaid
{
  public enum LogType: String {
    case Hit = "Hit"
    case Miss = "Miss"
    case MustCache = "MustCache"
    case Saved = "Saved"
    case Xman = "Xman"
    case Skipped = "Skipped"
  }
  
  open var includedTypes: [LogType]?
  open var enabled = true
  
  init() {
    // intentionally blank
  }
  
  open func log(_ logType: LogType, _ message: String) {
    if enabled {
      if let includedTypes = includedTypes {
        if includedTypes.contains(logType) {
          Plaid.logMessage(logType, message)
        }
      }
      else {
        Plaid.logMessage(logType, message)
      }
    }
  }
  
  class open func logMessage(_ logType: LogType, _ message: String) {
    print("[\(logType.rawValue.uppercased())] \(message)")
  }
}
