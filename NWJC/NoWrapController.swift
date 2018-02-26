	//
//  ViewController.swift
//  NoWrapJustCache
//
//  Created by Kishyr Ramdial on 2015/02/04.
//  Copyright (c) 2015 MGS. All rights reserved.
//

//TODO: Show progress on splashscreen.

import UIKit
import WebKit
import MobileCasinoSDKFramework
import CommonModule

class NoWrapController: UIViewController, UIViewControllerTransitioningDelegate {
  var game: POSGame!
  var errorWhenLoadingGame: Bool = false
  
  fileprivate var casinoSDK: CasinoSDK = swiftyAPI.casinoSDK
  fileprivate var config: IonConfigHandler = swiftyAPI.sharedConfig
  
  fileprivate var placeholderView: NWJCGameLoaderView? // WKWebView doesnt support black bg colors. so as a fix to stop showing a white flash as the app transitions I am showing a uiview over it to fake it.//duncand
  fileprivate var webView: NWJCWebView?
  
  fileprivate var nwjcConfig: NWJCConfig?
  
  fileprivate var showSplashBackButton: Bool {
    didSet {
      if !showSplashBackButton {
        DispatchQueue.main.async {
          UIView.animate(withDuration: 0.5, delay: 0, options: .curveEaseInOut, animations: {
            self.backButton.alpha = 0
            }, completion: nil)
        }
      } else {
        self.backButton.alpha = 1
      }
    }
  }
  
  fileprivate var showPlaceHolderView: Bool {
    didSet {
      if !showPlaceHolderView {
        DispatchQueue.main.async {
          UIView.animate(withDuration: 0.3, delay: 0.5, options: .curveEaseInOut, animations: {
            self.placeholderView?.alpha = 0
            }, completion: nil)
        }
      }
    }
  }
  
  fileprivate var goingToPresentViewController = false;
  fileprivate var backButton = UIButton(type: UIButtonType.custom)
  fileprivate var placeholderViewTimer: Timer?
  
	convenience init(game: POSGame, nwjcConfig: NWJCConfig) {
		self.init(nibName: nil, bundle: nil)
		NotificationCenter.default.addObserver(self, selector: #selector(NoWrapController.reachabilityChanged(_:)), name: NSNotification.Name.AFNetworkingReachabilityDidChange, object: nil)
		self.game = game
		if let guid = game.purgeCacheGuid {
			let cacheUtility = CacheUtility(gamename: game.name, purgecacheGuid: guid)
			if (cacheUtility.purgeRequired()) {
				cacheUtility.purgeTheCache()
				cacheUtility.savePurgeGuidToUserDefaults()
			}
		}
		self.nwjcConfig = nwjcConfig
		self.setup()
	}
	
  required override init(nibName: String?, bundle: Bundle?) {
    self.showPlaceHolderView = true
    self.showSplashBackButton = true
    super.init(nibName: nibName, bundle: bundle)
  }
  
  required init?(coder aDecoder: NSCoder) {
    self.showPlaceHolderView = true
    self.showSplashBackButton = true
    super.init(coder: aDecoder)
  }
  
  deinit
  {
    NotificationCenter.default.removeObserver(self, name: NSNotification.Name.AFNetworkingReachabilityDidChange, object: nil)
    UIApplication.shared.isIdleTimerDisabled = false
    if let placeholderViewTimer = self.placeholderViewTimer {
      placeholderViewTimer.invalidate()
    }
    if let webView = webView {
      webView.cancelLoad()
    }
  }
	
	fileprivate func setup()
  {
    if let game = game {
      game.package.gameLaunched()
    }
    
    webView = NWJCWKWebView(posGame: game, failureBlock: {
      [unowned self] errorMessage in
      // TODO:
      // We need an error dialogue here, the H5 game failed to load (noted this when cache manifest was not available)
      self.errorWhenLoadingGame = true
      self.dismissGameAndLaunchScriptedAction()
    })

    // If NWJC was not initialised in the NWJCWebView, the webView object will also be nil as it wouldn't have been created.
    if webView?.webView() == nil {
      errorWhenLoadingGame = true
    }

    placeholderView = NWJCGameLoaderView(splash: game.splash(), heightOffset: game.getSplashHeightOffset())
    
    if let webView = webView {
      if let _view = webView.webView() {
        _view.frame = CGRect(x: self.view.bounds.minX, y: self.view.bounds.minY + 20, width: self.view.bounds.width, height: self.view.bounds.height - 20)
        _view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        _view.isOpaque = false
        _view.backgroundColor = UIColor.black
        self.view.addSubview(_view)
      }
    }
    
    // Add fake view over all other views.
    if let fk = placeholderView {
      fk.frame = view.bounds
      fk.backgroundColor = UIColor.black
      fk.autoresizingMask = [.flexibleWidth, .flexibleHeight];
      self.view.addSubview(fk)
    }
    
    // Add Splash 'back to lobby' button button
    if let image = UIImage(named: "BackToLobby") {
      backButton.setImage(image, for: .normal)
    }
    backButton.addTarget(self, action: #selector(NoWrapController.backToLobbyFromButton(_:)), for: .touchUpInside)
    backButton.translatesAutoresizingMaskIntoConstraints = false
    backButton.contentMode = UIViewContentMode.center
    
    self.view.addSubview(backButton)
    
    var buttonXConstraint: NSLayoutConstraint?
    var buttonYConstraint: NSLayoutConstraint?
    
    if UIDevice.current.userInterfaceIdiom == .phone {
      if UIScreen.main.bounds.size.height == 736.0 {
        buttonXConstraint = NSLayoutConstraint(item: backButton, attribute: NSLayoutAttribute.leading, relatedBy: NSLayoutRelation.equal, toItem: self.view, attribute: NSLayoutAttribute.leading, multiplier: 1.0, constant: 20.0)
      }
    } else if UIDevice.current.userInterfaceIdiom == .pad {
      buttonXConstraint = NSLayoutConstraint(item: backButton, attribute: NSLayoutAttribute.leading, relatedBy: NSLayoutRelation.equal, toItem: self.view, attribute: NSLayoutAttribute.leading, multiplier: 1.0, constant: 30.0)
      buttonYConstraint = NSLayoutConstraint(item: backButton, attribute: NSLayoutAttribute.top, relatedBy: NSLayoutRelation.equal, toItem: self.view, attribute: NSLayoutAttribute.top, multiplier: 1.0, constant: 45.0)
    }
    
    if buttonXConstraint === nil {
      buttonXConstraint = NSLayoutConstraint(item: backButton, attribute: NSLayoutAttribute.leading, relatedBy: NSLayoutRelation.equal, toItem: self.view, attribute: NSLayoutAttribute.leading, multiplier: 1.0, constant: 15.0)
    }
    
    if buttonYConstraint === nil {
      buttonYConstraint = NSLayoutConstraint(item: backButton, attribute: NSLayoutAttribute.top, relatedBy: NSLayoutRelation.equal, toItem: self.view, attribute: NSLayoutAttribute.top, multiplier: 1.0, constant: 35.0)
    }
    
    let buttonWidthConstraint = NSLayoutConstraint(item: backButton, attribute: NSLayoutAttribute.width, relatedBy: NSLayoutRelation.equal, toItem: nil, attribute: NSLayoutAttribute.notAnAttribute, multiplier: 1.0, constant: 47.0)
    let buttonHeightConstraint = NSLayoutConstraint(item: backButton, attribute: NSLayoutAttribute.height, relatedBy: NSLayoutRelation.equal, toItem: nil, attribute: NSLayoutAttribute.notAnAttribute, multiplier: 1.0, constant: 47.0)
    
    self.view.addConstraint(buttonXConstraint!)
    self.view.addConstraint(buttonYConstraint!)
    self.view.addConstraint(buttonWidthConstraint)
    self.view.addConstraint(buttonHeightConstraint)
    
    UIApplication.shared.isIdleTimerDisabled = true
  }
  
  override func viewDidDisappear(_ animated: Bool) {
    super.viewDidDisappear(animated)
  }
  
  override func viewWillDisappear(_ animated: Bool) {
    super.viewWillDisappear(animated)
    
    NotificationCenter.default.post(name: Notification.Name(rawValue: "POS_CHANGE_STATUS_BAR_COLOR"), object: nil)
    
    casinoSDK.requestBalanceUpdate()
  }
  override func viewWillAppear(_ animated: Bool) {
    super.viewWillAppear(animated)
    
    UIApplication.shared.setStatusBarStyle(.lightContent, animated: true)
    self.setNeedsStatusBarAppearanceUpdate()
  }
  
  override func viewDidAppear(_ animated: Bool)
  {
    super.viewDidAppear(animated)
    self.goingToPresentViewController = false
    (UIApplication.shared.delegate as! MGSFakeDelegates).setCurrentViewController(self)
    NotificationCenter.default.post(name: Notification.Name(rawValue: "VIEW_CONTROLLER_PRESENTED"), object: self)
  }
  
  override func viewDidLoad()
  {
    super.viewDidLoad()
    
    if webView != nil
    {
			game.package.requestSource = Int32(BEAMPackageRequestSource.lobby.rawValue)
			if (game.package.state == CInt(BEAMPackageState.complete.rawValue)) {
				game.package.isLoading = true;
			} else {
				game.package.isLoading = false;
			}
    }
    
    view.backgroundColor = UIColor.black
    navigationController?.setNavigationBarHidden(false, animated: false)
    UIApplication.shared.setStatusBarStyle(.lightContent, animated: true)
    self.setNeedsStatusBarAppearanceUpdate()
    
    if let webView = webView {
      webView.completionBlock = {
        [unowned self] in
        
        self.showSplashBackButton = false
        self.hidePlaceHolderView()
      }
      webView.progressBlock = {
        [unowned self] percent in
        if percent > 0 {
          self.hidePlaceHolderView()
        }
      }
      
      if let nwjc = webView.nwjc {
        nwjc.onLoadLobby = {
          [unowned self] in
          self.dismissGameAndLaunchScriptedAction()
        }
        
        nwjc.onLoadBanking = {
          [unowned self] in
          self.dismissGameAndLaunchScriptedAction {
            MGSScriptedAction.shared().launchecash()
          }
        }
        
        nwjc.onSwitchToRealPlay = {
          [unowned self] in
          self.dismissGameAndLaunchScriptedAction {
            MGSScriptedAction.shared().switchuser()
          }
        }
        
        nwjc.onCacheManifestLoadSuccess = {
          [unowned self] in
          self.createHideFromViewsTimer()
        }
        
        nwjc.onCacheManifestDownloadFailed = {
          [unowned self] in
          
          self.dismissGameAndLaunchScriptedAction{
            GlobalAlertView.showAlert(NSLocalizedString("BEAMPackageDownloadError", comment: ""), message: NSLocalizedString("BEAMPackageDownloadErrorMessage", comment: ""), buttons: [NSLocalizedString("Cancel", comment: "Cancel")], buttonBlock: nil)
          }
        }
				
				nwjc.onLoadHelp = {
					[unowned self] in

					let helpURL = POSHelpViewController.helpURL() as NSString
					MGSScriptedAction.shared().launchurl(helpURL, with: self)
				}
				
        nwjc.onLoadResponsibleGaming = {
          [unowned self] in
          guard let productType = self.config.getString("producttype") else {
            return
          }
          
          if productType.lowercased() == "quickfire" {
            NotificationCenter.default.post(Notification(name: Notification.Name(rawValue: "QUICKFIRE_WEBVIEW_REQUEST"), object: ModalWebViewTarget.responsibleGaming.rawValue)) // res is short for responsible gaming
          } else {
            
            
            if let action = self.config.getExpandedString("url.responsible_gaming.action", withDefault: nil),
              action.caseInsensitiveCompare("launchresponsiblegaming") == ComparisonResult.orderedSame {
              
                self.dismissGameAndLaunchScriptedAction {
                    MGSScriptedAction.shared().launchresponsiblegaming()
                }
              
            } else if let url = self.config.getExpandedString("url.responsible_gaming.url", withDefault: nil){
              var launchURL: NSString!
              
              if let post = self.config.getExpandedString("url.responsible_gaming.post", withDefault: nil) {
                launchURL = NSString(string: "\(url);\(post)")
              }else{
                launchURL = NSString(string: url)
              }
              
              if !self.goingToPresentViewController {
                self.goingToPresentViewController = true
                DispatchQueue.main.async { [unowned self] in
                  MGSScriptedAction.shared().launchurl(launchURL, with: self)
                }
              }
            }
          }
        }
        
        nwjc.disableGameTutorials = self.nwjcConfig!.shouldDisableGameTutorials
        
        nwjc.useOverridenSoundSettings = self.nwjcConfig!.shouldOverrideSoundSettings
      }
      
      BEAM.client().pauseDownloadsAndPreserveDownloadStack()
      
      // store the current game in play to prevent push notifications for the current game being displayed to the user
      config.setString("lastGamePlayed", obj: game!.name)
      
      webView.loadGame()
      
    }
  }
  
  override func didReceiveMemoryWarning()
  {
    super.didReceiveMemoryWarning()
  }
  
  override var prefersStatusBarHidden : Bool {
    return false
  }
  
  override var preferredStatusBarStyle : UIStatusBarStyle
  {
    return .lightContent
  }
  
  override var supportedInterfaceOrientations : UIInterfaceOrientationMask {
    return UIInterfaceOrientationMask.landscape
  }
  
  override var shouldAutorotate : Bool {
    return true
  }
  
  internal func dismissGameAndLaunchScriptedAction(_ action: ((Void) -> (Void))? = nil)
  {
    // resume downloads, if any, after gameplay
    // NB (not on the main thead or on no wrap thread)
    DispatchQueue.global(qos: .userInitiated).async(execute: {
      BEAM.client().resumePausedDownloads()
    });
    
    DispatchQueue.main.async { [unowned self] in

      // let config = (UIApplication.sharedApplication().delegate as! MGSFakeDelegates).config()
      // let statusBarIsLightContent: Bool = config.getInteger("statusbarcolor.is_white", withDefault: 0) == 1
      // let statusBarStyle: UIStatusBarStyle = statusBarIsLightContent ? .LightContent : .Default

      // UIApplication.sharedApplication().setStatusBarStyle(statusBarStyle, animated: true)
      // self.setNeedsStatusBarAppearanceUpdate()

			let extraDelay = self.errorWhenLoadingGame == true ? 1.0 : 0.0
      let delayTime = DispatchTime.now() + Double(extraDelay)
			DispatchQueue.main.asyncAfter(deadline: delayTime, execute: {  [weak self] in
				guard let weakSelf = self else { return }
				
				NotificationCenter.default.post(name: Notification.Name(rawValue: "POS_GAME_DISMISSED"), object: nil, userInfo: ["game": weakSelf.game])
				weakSelf.transitioningDelegate = self
				
				weakSelf.presentingViewController?.dismiss(animated: true) { _ in
					weakSelf.transitioningDelegate = weakSelf

					if let action = action {
						action()
					}

					NotificationCenter.default.post(name: Notification.Name(rawValue: "POS_GAME_DISMISSED_AFTER_ANIMATION"), object: nil, userInfo: nil)
				}
			})
    }
  }
  
  func animationController(forDismissed dismissed: UIViewController) -> UIViewControllerAnimatedTransitioning?
  {
    return POSGameTransition()
  }
  
  func backToLobbyFromButton(_ sender: UIButton)
	{
    self.dismissGameAndLaunchScriptedAction()
  }
  
  fileprivate func createHideFromViewsTimer() {
    DispatchQueue.main.async {
      if self.placeholderViewTimer == nil {
        self.placeholderViewTimer = Timer.scheduledTimer(timeInterval: 5.0, target: self, selector: #selector(NoWrapController.hideViewsFromTimer), userInfo: nil, repeats: false);
      }
    }
  }
  
  func hideViewsFromTimer() {
    DispatchQueue.main.async {
      self.hidePlaceHolderView();
      self.showSplashBackButton = false
    }
  }
  
  internal func hidePlaceHolderView() {
    if let placeholderViewTimer = placeholderViewTimer {
      placeholderViewTimer.invalidate()
    }
    
    if self.showPlaceHolderView {
      self.showPlaceHolderView = false
    }
  }
  
  func reachabilityChanged(_ note: Notification) {
    if let userInfo = note.userInfo,
      let reachibiltyStatus = userInfo[AFNetworkingReachabilityNotificationStatusItem] as? NSNumber,
      reachibiltyStatus.intValue == AFNetworkReachabilityStatus.notReachable.rawValue
    {
      dismissGameAndLaunchScriptedAction(nil)
      print(reachibiltyStatus);
    }
  }
}
