//
//  NWJCWebView.swift
//  IOSCasino
//
//  Created by Wouter Huizinga on 2015/07/29.
//  Copyright (c) 2015 Microgaming. All rights reserved.
//

import WebKit
import MobileCasinoSDKFramework

class NWJCWebView: NSObject {
  
  var casinoSDK: CasinoSDK = swiftyAPI.casinoSDK

  var gameTrackingService = swiftyAPI.globalTrackingService.gameTrackingService
  
  fileprivate var package: BEAMPackage?
  
  var view: UIView?
  var nwjc: NWJC?
  var timer: Timer?
  var gameName = ""
  
  internal var completionBlock: (() -> Void)?
  internal var progressBlock: ((_ percent: Float) -> Void)?
  internal var failureBlock: ((String?) -> Void)?
  internal var manifestOnlyBlock: ((BEAMPackage, String, [String]?) -> Void)?
  internal var failed: Bool = false
  internal var complete: Bool = false
  
  init(posGame: POSGame?, failureBlock: ((String?) -> Void)?) {
    super.init()

    self.failureBlock = failureBlock

    nwjc = NWJC(failureBlock: failureBlock)
    
    guard let nwjc = nwjc as NWJC? else {
      return
    }

    nwjc.game = posGame

    if let posGame = posGame {
      gameName = posGame.name
      package = BEAMPackage(name: posGame.name)
    }

    setupWebView()
    startUrlLoadCheckingTimer();
    NotificationCenter.default.addObserver(self, selector: #selector(NWJCWebView.applicationDidBecomeActive), name: NSNotification.Name.UIApplicationDidBecomeActive, object: nil)
    NotificationCenter.default.addObserver(self, selector: #selector(NWJCWebView.applicationDidEnterBackground), name: NSNotification.Name.UIApplicationDidEnterBackground, object: nil)
  }
  
  deinit {
    NotificationCenter.default.removeObserver(self, name: NSNotification.Name.UIApplicationDidBecomeActive, object: nil)
    NotificationCenter.default.removeObserver(self, name: NSNotification.Name.UIApplicationDidEnterBackground, object: nil)
    
    stopUrlLoadCheckingTimer()
  }
  
  func setupWebView() {
    
  }
  
  func urlLoadingCheck() {
  }
  
  func stopUrlLoadCheckingTimer() {
    self.timer?.invalidate()
    self.timer = nil
  }
  
  func startUrlLoadCheckingTimer() {
    self.timer = Timer.scheduledTimer(timeInterval: 0.1, target: self, selector: #selector(NWJCWebView.urlLoadingCheck), userInfo: nil, repeats: true)
  }
  
  func applicationDidBecomeActive() {
    startUrlLoadCheckingTimer();
  }
  
  func applicationDidEnterBackground() {
    stopUrlLoadCheckingTimer()
  }
  
  func htmlGameProgressComplete() {
    if !complete {
      complete = true;
  
      gameTrackingService.gameLoadComplete(forGame: gameName)
      
      if let completionBlock = completionBlock {
        completionBlock()
      }
      
      updatePackageState(BEAMPackageState.complete)
    }
  }
  
  func htmlGameProgressUpdate(_ percentage: Float) {
    stopUrlLoadCheckingTimer()
    if let progressBlock = progressBlock {
      progressBlock(percentage)
    }
    if (percentage >= 100) {
      htmlGameProgressComplete()
    }
  }
  
  func htmlGameLoadFailure(_ errorMessage: String, errorCode: Int) {
    if !failed {
      failed = true
      
      gameTrackingService.gameLoadFailed(forGame: gameName, withErrorCode: errorCode)
        
      if let failureBlock = failureBlock {
        failureBlock(errorMessage)
      }
    }
  }
  
  func updatePackageState(_ state: BEAMPackageState) {
    if let package = package {
      package.state = CInt(state.rawValue)
      package.save()
    }
  }
  
  internal func loadGame() {
    
  }
  
  func cancelLoad() {
    if !complete && !failed {
      gameTrackingService.gameLoadCancelled(forGame: gameName)
    }
    progressBlock = nil
    completionBlock = nil
    failureBlock = nil
    manifestOnlyBlock = nil
    nwjc = nil
    stopUrlLoadCheckingTimer()
  }
  
  internal func webView() -> UIView? {
    if let view = view {
      return view
    }
    return nil
  }
  
}
