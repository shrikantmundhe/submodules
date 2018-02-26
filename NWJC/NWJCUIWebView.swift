//
//  NWJCuiWebView.swift
//  IOSCasino
//
//  Created by Wouter Huizinga on 2015/07/29.
//  Copyright (c) 2015 Microgaming. All rights reserved.
//

class NWJCUIWebView : NWJCWebView, UIWebViewDelegate {
  
  fileprivate var uiWebView: UIWebView?
  
  // MARK: NWJCWebView overrides

  override func setupWebView() {
    uiWebView = UIWebView()
    uiWebView?.delegate = self
  }
  
  override internal func loadGame() {
    if let uiWebView = uiWebView {
      if let urlRequest = nwjc!.gameUrlRequest() {
        uiWebView.loadRequest(urlRequest)
      }
    }
  }
  
  override func cancelLoad() {
    if let ui = uiWebView {
      ui.stopLoading();
      ui.delegate = nil
    }
    super.cancelLoad()
  }
  
  override func urlLoadingCheck() {
    if let uiWebView = uiWebView
    {
      if uiWebView.request?.url == nil {
        loadGame()
      }else{
        stopUrlLoadCheckingTimer()
      }
    }
    super.urlLoadingCheck()
  }
  
  override internal func webView() -> UIView? {
    if let uiWebView = uiWebView {
      return uiWebView
    }
    return nil
  }
  
  // MARK: UIWebViewDelegate methods

  func webView(_ webView: UIWebView, shouldStartLoadWith request: URLRequest, navigationType: UIWebViewNavigationType) -> Bool {
    // request comes through as lowercase from the javascript
    let internalScheme = "uiwebviewinstruction"

    if let url = request.url {
      // if it is not a request for us, ignore it and let it load as normal
      if (url.scheme != internalScheme) {
        if let nwjc = nwjc {
          return nwjc.launchActionByRequest(request)
        }
        return true
      }

      let action = url.host
      if action == "progressComplete" {
        htmlGameProgressComplete()
      }
      else if action == "progressUpdate" {
        let percentage = url.lastPathComponent
				htmlGameProgressUpdate((percentage as NSString).floatValue)
      }
      else if action == "loadFailure" {
				let errorMessage = url.lastPathComponent
				htmlGameLoadFailure(errorMessage, errorCode: 0)
      }
    }

    return false
  }

}
