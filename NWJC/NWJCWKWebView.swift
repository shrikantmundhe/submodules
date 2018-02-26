//
//  NWJCwkWebView.swift
//  IOSCasino
//
//  Created by Wouter Huizinga on 2015/07/29.
//  Copyright (c) 2015 Microgaming. All rights reserved.
//

import WebKit

@available(iOS 8.0, *)
class NWJCWKWebView : NWJCWebView, WKScriptMessageHandler, WKNavigationDelegate {
  
  fileprivate var wkWebView : WKWebView?

  // MARK: NWJCWebView overrides
  
  override func setupWebView() {
    wkWebView = WKWebView()
    wkWebView?.navigationDelegate = self
    wkWebView?.configuration.userContentController.add(self, name: "progressComplete")
    wkWebView?.configuration.userContentController.add(self, name: "progressUpdate")
    wkWebView?.configuration.userContentController.add(self, name: "loadFailure")
  }
  
  override internal func loadGame() {
    guard let nwjc = nwjc as NWJC?, let wkWebView = wkWebView, let request = nwjc.gameUrlRequest() else {
      failureBlock?(nil)
      cancelLoad()
      failed = true

      return
    }

    wkWebView.load(request)
  }
  
  override func cancelLoad() {
    if let wkWebView = wkWebView {
      wkWebView.stopLoading()
      wkWebView.navigationDelegate = nil
      wkWebView.configuration.userContentController.removeScriptMessageHandler(forName: "progressComplete")
      wkWebView.configuration.userContentController.removeScriptMessageHandler(forName: "progressUpdate")
      wkWebView.configuration.userContentController.removeScriptMessageHandler(forName: "loadFailure")
      wkWebView.configuration.userContentController.removeAllUserScripts()
    }
    super.cancelLoad()
  }
  
  override func urlLoadingCheck() {
    if let wkWebView = wkWebView
    {
      if wkWebView.url == nil
      {
        loadGame()
      } else {
        stopUrlLoadCheckingTimer()
      }
    }
    super.urlLoadingCheck()
  }
  
  override internal func webView() -> UIView? {
    if let wkWebView = wkWebView {
      return wkWebView
    }
    return nil
  }
  
  // MARK: WK delegate / handler methods
  
  func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
    if message.name == "progressComplete" {
      htmlGameProgressComplete()
    }
    else if message.name == "progressUpdate" {
      if let percentage = message.body as? Float {
        htmlGameProgressUpdate(percentage)
      }
    }
    else if message.name == "loadFailure" {
      var errorCode = 0
      var errorMessage = "Unable to decode error"
      if let error = message.body as? NSDictionary {
        if let code = error["code"] as? Int {
          errorCode = code
        }
        if let msg = error["userMessage"] as? String {
          errorMessage = msg
        }
      }
      htmlGameLoadFailure(errorMessage, errorCode: errorCode)
    }
  }

  // required as a failure point when we are unable to navigate to H5 webserver
  func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
		let e = error as NSError
		if e.code != NSURLErrorCancelled {
			if !failed {
				htmlGameLoadFailure(e.description, errorCode: e.code)
			}
		}
  }
  
  func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
    if let url = navigationAction.request.url, url.lastPathComponent == "undefined" {
      decisionHandler(.cancel)
    }
    if let nwjc = nwjc {
      decisionHandler(nwjc.launchActionByRequest(navigationAction.request) ? .allow : .cancel)
    }
    decisionHandler(.allow)
  }
  
}
