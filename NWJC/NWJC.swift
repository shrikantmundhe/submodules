//
//  NWJC.swift
//  NoWrapJustCache
//
//  Created by Kishyr Ramdial on 2015/04/13.
//  Copyright (c) 2015 MGS. All rights reserved.
//

import UIKit
import MobileCasinoSDKFramework


//MARK: - NoWrapJustCache
final public class NWJC: NSObject
{
  var casinoSDK: CasinoSDK = swiftyAPI.casinoSDK
  var config: IonConfigHandler = swiftyAPI.sharedConfig
  var gameTrackingService = swiftyAPI.globalTrackingService.gameTrackingService
	
  var mid: Int?
  
  public var failureBlock: ((String?) -> ())?
  
  public typealias GenericBlock = (() -> ())?
  
  // MARK: - Properties
  
  // MARK: Public
  public var cacheManifestUrl: URL?
  public var gameHostUrl = BEAM.client().gameRegConfig()?.gameHostUrl()
  public var cdnHostUrl = BEAM.client().gameRegConfig()?.cdnHostUrl()
  public var xManHostUrl = BEAM.client().gameRegConfig()?.xManHostUrl()
	public var lobbyName = BEAM.client().gameRegConfig()?.lobbyName()

  public var game: POSGame? {
    didSet {
      if let webGame = game {
        package = BEAMPackage(name: webGame.name)
        beam.cacheNWJCFilesForPackage(withName: webGame.name)
        
        if webGame.package.nwjcHash.characters.count > 0 {
          cacheManifestHash = webGame.package.nwjcHash
        }
        
        gameName = webGame.name
        
      }
      
      if(swiftyAPI.applicationPreferenceModel.testHarnessEnabled) {
        if let gameName = swiftyAPI.gameTestHarnessModel.gameName, let cid = swiftyAPI.gameTestHarnessModel.clientId, let mid = swiftyAPI.gameTestHarnessModel.moduleId {
          game?.name = gameName
          game?.mid = mid as Int
          game?.cid = cid as Int
        }
        if let gameUrl = swiftyAPI.gameTestHarnessModel.gameHostUrl,
          let cdnUrl = swiftyAPI.gameTestHarnessModel.cdnHostUrl,
          let xman = swiftyAPI.gameTestHarnessModel.xManHostUrl,
          let lobbyName = swiftyAPI.gameTestHarnessModel.lobbyName {
          self.gameHostUrl = URL(string:gameUrl)
          self.cdnHostUrl = URL(string: cdnUrl)
          self.xManHostUrl = URL(string: xman)
          self.lobbyName  = lobbyName
        }
      }
    }
  }
  
  public let beam = BEAM.client()
  public var gameLanguageCode = "en"
  public var disableGameTutorials = true
  public var useOverridenSoundSettings = true
  fileprivate var gameName = ""
  
  weak var noWrapController: NoWrapController?
  
  // MARK: Public Closures
  public var onLoadBanking: GenericBlock
  public var onLoadLobby: GenericBlock
  public var onSwitchToRealPlay: GenericBlock
  public var onLoadResponsibleGaming: GenericBlock
  public var onLoadHelp: GenericBlock
	
  public var onCacheManifestLoadSuccess: GenericBlock {
    didSet {
      if let onCacheManifestLoadSuccess = self.onCacheManifestLoadSuccess, cacheManifestHash != nil {
        onCacheManifestLoadSuccess()
      }
    }
  }
  public var onCacheManifestDownloadFailed: GenericBlock
  
  // MARK: Private
  fileprivate let webServer = GCDWebServer()!
  fileprivate let p = Plaid()
  fileprivate var package: BEAMPackage?
  fileprivate var port: UInt?
  fileprivate var hasShownModalController: Bool = false
  fileprivate let cacheManifestParser = CacheManifestParser()
  fileprivate let urlSession = URLSession(configuration: URLSessionConfiguration.default)
  fileprivate var webRequestBlocks: [(request: URLRequest, GCDRequest: GCDWebServerRequest, completionBlock: GCDWebServerCompletionBlock)]?
  fileprivate var cacheManifestCheckedRemotely: Bool = false
  fileprivate var cacheManifestHash: String? {
    didSet {
      continueRequests()
      if let onCacheManifestLoadSuccess = self.onCacheManifestLoadSuccess, cacheManifestHash != nil {
        onCacheManifestLoadSuccess()
      }
    }
  }
  
  fileprivate enum PacketState {
    case request
    case response
    case failure
  }
  
  // MARK: URL Building: Constants
  enum URLType: String {
    case Lobby = "xlobbyx"
    case XMan = "xxplay3x"
    case Banking = "xbankingx"
    case Content = "xgcontentx"
    case Game = "xgamex"
    case ResponsibleGaming = "xxresponsiblegamingxx"
		case Help = "xxhelpxx"

  }
  
  // MARK: URL Building: Urls
  fileprivate var lobbyUrl: String? {
    return urlForType(.Lobby)
  }
  
  fileprivate var xManUrl: String? {
    return urlForType(.XMan)
  }
  
  fileprivate var bankingUrl: String? {
    return urlForType(.Banking)
  }
  
  // MARK: URL Building: Base Urls
  fileprivate var contentUrl: String? {
    return urlForType(.Content, forScheme: self.cdnHostUrl?.scheme)
  }
  
  fileprivate var gameUrl: String? {
    return urlForType(.Game, forScheme: self.gameHostUrl?.scheme)
  }
  
  fileprivate var responsibleGamingURL: String? {
    return urlForType(.ResponsibleGaming)
  }
	fileprivate var helpUrl: String? {
		return urlForType(.Help)
	}
	
  fileprivate func urlForType(_ urlType: URLType, forScheme scheme: String? = "http") -> String? {
    if
    let port = self.port,
      let scheme = scheme
    {
      return "\(scheme)://localhost:\(port)/\(urlType.rawValue)"
    }
    
    return nil
  }
  
  // MARK: - Forward-Proxy
  
  override init() {
    super.init()
  }
  
  init(failureBlock: ((String?) -> ())?)
  {
    super.init()
		
    GCDWebServer.setLogLevel(4)
    p.includedTypes = [.Hit, .Miss, .MustCache, .Saved, .Xman, .Skipped]
    
    addHandlerFor("GET")
    addHandlerFor("POST")
    
    webServer.start(withPort: 0, bonjourName: nil)
    port = webServer.port
    webServer.nwjc_setOptionValue(NSNumber(value: port!), forKey: "Port")
    
    resetLocalStorage(port)
    
    p.enabled = true
    
    self.failureBlock = failureBlock
  }
  
  deinit
  {
    stopServer()
    
    if (cacheManifestCheckedRemotely == false) {
      // Check the cache manifest file after we've left the game for any upgrades that the game needs to do.
      deferredCacheManifest()
    }
    
    BEAM.client().cleanUpHashCache()
  }
  
  func stopServer() {
    urlSession.invalidateAndCancel()
    
    if !(webServer.isRunning) {
      webServer.stop()
      webServer.removeAllHandlers()
    }
  }
  
  fileprivate func addHandlerFor(_ methodType: String)
  {
    var requestClass = GCDWebServerRequest.self
    
    switch methodType {
    case "POST":
      requestClass = GCDWebServerDataRequest.self
    default:
      requestClass = GCDWebServerRequest.self
    }
    
    webServer.addDefaultHandler(forMethod: methodType, request: requestClass) {
      [weak self] request, completionBlock in
      
      if let weakSelf = self, let request = request {
        // Check to see if the request is handled..i.e web page overlays
        
        let queryElements: [String] = request.query.map { k, v in "\(k)=\(v)" }
        
        var host = weakSelf.gameHostUrl
        var path: String = request.path
        
        switch request.url.path {
        case let urlPath where (urlPath.hasPrefix("/\(URLType.Content.rawValue)")):
          host = weakSelf.cdnHostUrl
          let pathRange = path.range(of: "/\(URLType.Content.rawValue)")
          path = path.replacingCharacters(in: pathRange!, with: host!.path)
          
        case let urlPath where (urlPath.hasPrefix("/\(URLType.XMan.rawValue)")):
          host = weakSelf.xManHostUrl
          let pathRange = path.range(of: "/\(URLType.XMan.rawValue)")
          path = path.replacingCharacters(in: pathRange!, with: host!.path)

        case let urlPath where (urlPath.hasPrefix("/\(URLType.Lobby.rawValue)")):
          completionBlock!(GCDWebServerErrorResponse(statusCode: 200))
          
          // Check if navState == Login then switch user.

          if (request.method == "POST" && (request as! GCDWebServerDataRequest).data != nil) {
            
						let postData = (request as! GCDWebServerDataRequest).data
            if let postStr = NSString(data: postData!, encoding: String.Encoding.utf8.rawValue)
            {
              let postArr = postStr.components(separatedBy: "&")
              var postQuery = [String: String]()
              
              for postKeyVal in postArr
              {
                if let keyValArray = postKeyVal.components(separatedBy: "=") as [String]? {
                  postQuery[keyValArray[0]] = keyValArray[1]
                }
              }
              
              if let navState = postQuery["navState"] {
                if navState.lowercased() == "login"
                {
                  if let onSwitchToRealPlay = weakSelf.onSwitchToRealPlay
                  {
                    onSwitchToRealPlay()
                  }
                }
                else if let onLoadLobby = weakSelf.onLoadLobby
                {
                  onLoadLobby()
                }
              }
            }
          }
          return
          
        case let urlPath where (urlPath.hasPrefix("/\(URLType.Banking.rawValue)")):
          completionBlock!(GCDWebServerErrorResponse(statusCode: 200))
          if let onLoadBanking = weakSelf.onLoadBanking {
            onLoadBanking()
          }
          return
        default:
          host = weakSelf.gameHostUrl
          path = request.path
        }
        
        // Get Cookies from header.
        // var cookieQueryElements = [String: String]()
        // if let headers = request.headers as? [String: String], let cookie = headers["Cookie"]
        // {
        // let cookieParts = split(cookie){$0 == "&"}
        // for cookiePart in cookieParts
        // {
        // let resArr = split(cookiePart){$0 == "="}
        // cookieQueryElements[resArr.first!] = resArr.last
        // }
        // }
        // //Set the res onto the end of the URL.
        // if let cookieRes = cookieQueryElements["resolution"]
        // {
        // queryElements.append("resolution=\(cookieRes)")
        // }
        
        let queryString = queryElements.joined(separator: "&").addingPercentEncoding(withAllowedCharacters: .urlHostAllowed)
        if let host = host, let scheme = host.scheme, let domain = host.host {
          let urlString = "\(scheme)://\(domain)\(path)?\(queryString!)"
          
          // Build up the request
          var urlRequest = URLRequest(url: URL(string: urlString)!)
          urlRequest.addValue("NoWrapJustCache9000", forHTTPHeaderField: "NWJC")
          urlRequest.httpMethod = methodType
          if request.method == "POST"
          {
            if ((request as! GCDWebServerDataRequest).data != nil) {
              urlRequest.httpBody = (request as! GCDWebServerDataRequest).data
            }
          }
          
          if host == weakSelf.xManHostUrl {
            weakSelf.nativeXmanRequest(urlRequest, completionBlock: completionBlock!)
          }
          else {
            weakSelf.makeRequest(urlRequest, GCDRequest: request, completionBlock: completionBlock!)
          }
        }
      }
    }
  }
  
  fileprivate func makeRequest(_ urlRequest: URLRequest, GCDRequest: GCDWebServerRequest, completionBlock: @escaping GCDWebServerCompletionBlock)
  {
    if cacheManifestHash == nil {
      let deferredSelector = (request: urlRequest, GCDRequest: GCDRequest, completionBlock: completionBlock)
      
      if var webRequestBlocks = webRequestBlocks {
        webRequestBlocks.append(deferredSelector)
      }
      else {
        webRequestBlocks = [deferredSelector]
      }
      
      fetchCacheManifest()
    }
    else
    {
      
      var dataCached = false
      var mustCache = true
      let cachePath = trimmedPathForUrlRequest(urlRequest)
      
      if let game = game
      {
        if let
        cacheObject = beam.hashCache[cachePath] as? [String: String],
          let fileData = beam.fileData(withPath: cachePath, inPackage: game.name)
        {
          if let
          cachedData = fileData["data"] as? Data,
            let mimetype = cacheObject["type"]
          {
            var response = self.responseWithPossiblePartialContent(GCDRequest, data: cachedData, mimeType: mimetype)
            
            completionBlock(response)
            dataCached = true
            p.log(.Hit, cachePath)
          }
        }
        else {
          if let (cachedData, mimetype) = fileDataForRequest(urlRequest, inPackage: game.name as NSString) {
            var response = self.responseWithPossiblePartialContent(GCDRequest, data: cachedData, mimeType: mimetype)
            
            completionBlock(response)
            dataCached = true
            p.log(.Hit, cachePath)
          }
        }
      }
      
      if !dataCached {
        
var dataTask: URLSessionDataTask?
        dataTask = urlSession.dataTask(with: urlRequest, completionHandler: {
          [weak self] data, response, error in
          
          if let weakSelf = self {
            
if (error != nil) {
              print("Error: \(error)")
              completionBlock(nil)
              
              // If for some reason it cant load the main page on live then we will kick back to lobby.
              if let onLoadLobby = weakSelf.onLoadLobby, let url = urlRequest.url, let params = url.getKeyVals(), params["gameName"] != nil
              {
                onLoadLobby()
              }
            }
            else {
              var transformedData = data
              let responseHeaders = (response as! HTTPURLResponse).allHeaderFields
              
              if let data = data {
                var responseString = NSString(data: data, encoding: String.Encoding.utf8.rawValue)
                if let rs = responseString {
                  var responseText = rs
                  
                  if let gameUrl = weakSelf.gameUrl, let gHostURL = weakSelf.gameHostUrl?.absoluteString
                  {
                    responseText = rs.replacingOccurrences(of: gHostURL, with: gameUrl) as NSString
                  }
                  
                  if let contentUrl = weakSelf.contentUrl, let cdnHost = weakSelf.cdnHostUrl?.absoluteString
                  {
                    let contentUrlURL = URL(string: contentUrl)!
                    responseText = responseText.replacingOccurrences(of: cdnHost, with: contentUrl) as NSString
                    responseText = responseText.replacingOccurrences(of: "\(weakSelf.cdnHostUrl!.host!)\(weakSelf.cdnHostUrl?.path)", with: "\(contentUrlURL.host!):\(contentUrlURL.port!)\(contentUrlURL.path)") as NSString

                    var signalEngine: String {
                      var js = "";
                      js += "mgs.mobile.casino.v.SignalEngine.gameEvent.add(function(data, value) { ";
                      js += "if (data == 'preloaderRemoved') webkit.messageHandlers.progressComplete.postMessage(data);"
                      js += "if (data == 'gameReady') webkit.messageHandlers.progressComplete.postMessage(data);"
                      js += "if (data == 'loadProgressUpdate') webkit.messageHandlers.progressUpdate.postMessage(value);"
                      js += "if (data == 'fatalError') window.location = webkit.messageHandlers.loadFailure.postMessage(value);"
                      js += "}, null);"

                      if weakSelf.useOverridenSoundSettings == true {
                        let soundEnabled = BEAM.client().configHandler.getInteger("sound", withDefault: 1) == 1 ? "true" : "false"
                        js += "mgs.mobile.casino.v.localStorage.setString(\"\(soundEnabled)\", \"soundsEnabled\");"
                      }
                      
                      return js
                    }
                    
                    let signalJS = "" +
                      "var signalCheckInterval;" +
                      "var signalCheck = function(){" +
                      "if(typeof mgs != 'undefined' && typeof mgs.mobile != 'undefined' && typeof mgs.mobile.casino != 'undefined'  && typeof mgs.mobile.casino.v != 'undefined'){" +
                      signalEngine +
                      "clearInterval(signalCheckInterval);" +
                      "}" +
                      "};" +
                      "signalCheckInterval = setInterval(signalCheck, 100);"
                    
                    responseText = responseText.replacingOccurrences(of: "</body>", with: "<script type=\"text/javascript\">\(signalJS)</script></body>") as NSString
                    
                    if let findReplaceArray = BEAM.client().gameRegConfig()?.findReplaceResponsibleGaming() as? [NSDictionary] {
                      
                      for findReplace in findReplaceArray {
                        if let find = findReplace["find"] as? String, let replace = findReplace["replace"] as? String
                        {
                          // introducing a hack to hide the responsible gaming link in game for TEG
                          // typically this is set by config.xml in the GAO directory
                          // however making a change there will affect all of our brands
                          if let productType = self?.config.getString("producttype")!.lowercased() {
                            let components = productType.components(separatedBy: "_")
                            if( components[0] == "teg" ){
                              responseText = responseText.replacingOccurrences(of: "\"linkEnabled\":true", with: "\"linkEnabled\":false") as NSString
                            }
                            else {
                              responseText = responseText.replacingOccurrences(of: find, with: replace) as NSString
                            }
                          }
                          else {
                            responseText = responseText.replacingOccurrences(of: find, with: replace) as NSString
                          }
                        }
                      }
                      
                    }
                    
                  }
                  
                  transformedData = responseText.data(using: String.Encoding.utf8.rawValue)
                }
              }
              
              if (transformedData == nil) {
                print("Uh oh! \(transformedData)")
              }
              
              if let cacheControl = responseHeaders["Cache-Control"] as? String {
                
								let cacheControlValues = cacheControl.components(separatedBy: ",")
                var mustCacheFile = false
                
                for cacheControlValue in cacheControlValues {
                  let value = cacheControlValue.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
                  if value.hasPrefix("max-age") {
                    mustCacheFile = true
                  }
                }
                
                if mustCache && mustCacheFile {
                  let absUrl = urlRequest.url!.absoluteString
                  weakSelf.p.log(.MustCache, "\(Unmanaged.passUnretained(weakSelf).toOpaque()) \(absUrl)")
                  
                  let queue = DispatchQueue(label: "com.mgs.nwjc.bg", attributes: [])
                  queue.async {
                    
                    let dataCopy = transformedData
                    if let package = weakSelf.package {
                      NWJC.saveData(dataCopy, forRequestPath: weakSelf.trimmedPathForUrlRequest(urlRequest), withResponse: (response as! HTTPURLResponse), inPackage: package, withManifestHash: weakSelf.cacheManifestHash, andCacheInMemory: true)
                    }
                  }
                }
                else {
                  weakSelf.p.log(.Miss, urlRequest.url!.absoluteString)
                }
              }
              
              let dataResponse = weakSelf.responseWithPossiblePartialContent(GCDRequest, data: transformedData!, mimeType: response!.mimeType!)
              completionBlock(dataResponse)
            }
          }
        }) 
        
        dataTask!.resume()
      }
    }
  }
  
  fileprivate func responseWithPossiblePartialContent(_ request: GCDWebServerRequest, data: Data, mimeType: String) -> GCDWebServerDataResponse {
    var dataResponse: GCDWebServerDataResponse
    
    if request.hasByteRange(), let range = request.byteRange.toRange() {
      let rangedData = data.subdata(in: range)
      
      dataResponse = GCDWebServerDataResponse(data: rangedData, contentType: mimeType)
      dataResponse.statusCode = GCDWebServerSuccessfulHTTPStatusCode.httpStatusCode_PartialContent.rawValue
      dataResponse.setValue("bytes \(request.byteRange.location)-\(request.byteRange.location + request.byteRange.length - 1)/\(data.count)", forAdditionalHeader: "Content-Range")
      dataResponse.setValue("bytes", forAdditionalHeader: "Accept-Ranges")
      dataResponse.setValue("keep-alive", forAdditionalHeader: "Connection")
    } else {
      dataResponse = GCDWebServerDataResponse(data: data, contentType: mimeType)
    }
    
    dataResponse.cacheControlMaxAge = 7200
    
    return dataResponse;
  }
  
  // MARK: - Cache Manifest Parsing
  
  public func fetchCacheManifest()
  {
    if let game = game {
      let cacheManifestURLs = self.beam.cacheManifestURLs(for: game.package) as! [String: URL]
      if let cmURL = cacheManifestURLs["URL"] {
        self.getCacheManifestFileUsingURL(cmURL, successBlock: nil, failureBlock: {
          [weak self] in
          
          if let weakSelf = self {
            if let cmENURL = cacheManifestURLs["ENURL"] {
              weakSelf.getCacheManifestFileUsingURL(cmENURL, successBlock: nil, failureBlock: weakSelf.onCacheManifestDownloadFailed)
            } else if let onCacheManifestDownloadFailed = weakSelf.onCacheManifestDownloadFailed {
              onCacheManifestDownloadFailed()
            }
          }
        })
      }
    }
  }
  
  public func getCacheManifestFileUsingURL(_ url: URL, successBlock: GenericBlock, failureBlock: GenericBlock)
  {
    if let
    game = game,
//      resolution = NWJC.currentResolution(),
    let package = package
    {
      cacheManifestParser.manifestUrl = url
      cacheManifestParser.weakDownloadManifestForPackage(package, withSuccessBlock: {
        [weak self](package, manifest, files) in
        
        if let weakSelf = self {
          weakSelf.cacheManifestHash = manifest
          game.package.verifyPackage(withHash: weakSelf.cacheManifestHash)
          weakSelf.cacheManifestCheckedRemotely = true
          weakSelf.cacheManifestUrl = url
          
          print("Cache manifest hash: \(weakSelf.cacheManifestHash)")
          
          if let successBlock = successBlock {
            successBlock()
          }
        }
        
        }, withFailureBlock: failureBlock)
    }
  }
  
  public func deferredCacheManifest()
  {
    if let
    package = package,
      let game = game
    {
      let cacheManifestURLs = BEAM.client().cacheManifestURLs(for: game.package) as! [String: URL]
      if let cmURL = cacheManifestURLs["URL"] {
        let cmp = BEAM.client().cacheManifestParser
        cmp.manifestUrl = cmURL
        cmp.weakDownloadManifestForPackage(package, withSuccessBlock: {
          pacakge, manifest, files in
          
          game.package.verifyPackage(withHash: manifest)
          
          }, withFailureBlock: {
          if let cmENURL = cacheManifestURLs["ENURL"] {
            let cmpEN = BEAM.client().cacheManifestParser
            cmpEN.manifestUrl = cmENURL
            cmpEN.weakDownloadManifestForPackage(package, withSuccessBlock: {
              pacakge, manifest, files in
              
              game.package.verifyPackage(withHash: manifest)
              }, withFailureBlock: nil)
          }
        })
      }
      
    }
  }
  
  public func parseHTMLforCacheManifest(_ html: String) -> URL?
  {
    let regex: NSRegularExpression?
    do {
      regex = try NSRegularExpression(pattern: "manifest=\"(.*)\"", options: NSRegularExpression.Options.caseInsensitive)
    } catch _ as NSError {
      regex = nil
    }
    
    if let regex = regex {
      let result = regex.firstMatch(in: html, options: [], range: NSMakeRange(0, html.characters.count))
      if let result = result {
        let range = result.rangeAt(1)
        if range.location != NSNotFound {
          let path = (html as NSString).substring(with: range)
          
          let urlString = "\(gameHostUrl)/mgs/\(path)"
          return URL(string: urlString)
        }
      }
    }
    
    return nil
  }
  
  /**
   This method is called after cacheManifestHash is set to ensure that any requests we have waiting are executed.
   */
  public func continueRequests()
  {
    if let webRequestBlocks = webRequestBlocks {
      for deferredSelector in webRequestBlocks {
        makeRequest(deferredSelector.request, GCDRequest: deferredSelector.GCDRequest, completionBlock: deferredSelector.completionBlock)
      }
    }
  }
  
  fileprivate func getPacketAttribute(_ packet: String, attrName: String) -> String?
  {
    var verb: String?
    do {
      let regex = try NSRegularExpression(pattern: "\(attrName)=[\"'](.*?)[\"']", options: NSRegularExpression.Options.caseInsensitive)
      
      let result = regex.firstMatch(in: packet, options: [], range: NSMakeRange(0, packet.characters.count));
      if let range = result?.rangeAt(1) {
        if range.location != NSNotFound {
          verb = (packet as NSString).substring(with: range)
        }
      }
    } catch _ as NSError {
    }
    return verb
  }
  
  // MARK: - Xman-Raptor Transcoding
  
  fileprivate func nativeXmanRequest(_ urlRequest: URLRequest, completionBlock: @escaping GCDWebServerCompletionBlock)
  {
    guard let body = urlRequest.httpBody, let packet = String(data: body, encoding: .utf8) else {
      print("nativeXmanRequest:: No body")
      return
    }
    
    
    trackPacket(.request,packet: packet)
    
    if let url = urlRequest.url {
      p.log(.Xman, url.absoluteString)
    }
    casinoSDK.transcodeAndSend(packet, ofType: .PTT_HTML5_XMAN, onReceive: {
      [weak self](packetId, data, userData) in
      
      if (data != nil) {
        if let responsePacket = NSString(data: data!, encoding: String.Encoding.utf8.rawValue) {
          self?.trackPacket(.response, packet: responsePacket as String)
        }
        completionBlock(GCDWebServerDataResponse(data: data, contentType: "application/xml"))
      }
      else {
        self?.trackPacket(.failure,packet: packet)
      }
      
    }, withUserData: packet)

  }
  
  fileprivate func trackPacket(_ packetState: PacketState, packet:String) {
    let packetType = getPacketType(packet)
		
    switch packetState {
    case .request:
      gameTrackingService.packetRequest(forGame: gameName, ofPacketType: packetType)
    case .response:
      gameTrackingService.packetReceived(forGame: gameName, ofPacketType: packetType)
    case .failure:
      gameTrackingService.packetFailed(forGame:gameName, ofPacketType: packetType,withErrorCode: 0)
    }
  }
  
  fileprivate func getPacketType(_ packet: String)-> String{
    if let verbex = self.getPacketAttribute(packet, attrName: "verbex") {
      print(verbex)
      return verbex.lowercased()
    }
    if let verb = self.getPacketAttribute(packet, attrName: "verb") {
      print(verb)
      return verb.lowercased()
    }
    return ""
  }
  
  // MARK: - Database and Cache
  
  public class func saveData(_ data: Data?, forRequestPath requestPath: String, withResponse response: HTTPURLResponse, inPackage package: BEAMPackage, withManifestHash manifestHash: String?, andCacheInMemory cache: Bool)
  {
    // dont save nil data, which can occur when we cannot download mandatory files from H5's cachemanifest
    if let data = data {
      
let hash = data.md5()
      
      if let manifestHash = manifestHash
      {
        BEAM.client().setData(data, forKey: hash, andCacheInMemory: cache)
        BEAMWebFile.add(withHash: hash,
          path: requestPath,
          mimetype: response.mimeType!,
          fileSize: data.count,
          package: package,
          manifestHash: manifestHash
        )
        
        Plaid.logMessage(.Saved, requestPath)
      }
    }
  }
  
  fileprivate func fileDataForRequest(_ request: URLRequest, inPackage package: NSString) -> (Data, String)?
  {
    let path = trimmedPathForUrlRequest(request)
    if beam.hashCache[path] != nil {
      if let webFile = beam.fileData(withPath: path, inPackage: package as String) {
        return (webFile["data"] as! Data, webFile["type"] as! String)
      }
      else {
        return nil
      }
    }
    else {
      return nil
    }
  }
  
  fileprivate func trimmedPathForUrlRequest(_ request: URLRequest) -> String
  {
    /*
     TODO: confirm if the question mark on the end is required
     var trimmedPath = request.URL!.absoluteString!.stringByReplacingOccurrencesOfString("\(gameHostUrl.scheme!)://\(gameHostUrl.host!)/", withString:"")
     trimmedPath = trimmedPath.stringByReplacingOccurrencesOfString("\(cdnHostUrl.scheme!)://\(cdnHostUrl.host!)/", withString:"")
     */
    
    let path = request.url!.path as NSString
    return path.substring(from: 1)
  }
  
  // MARK: - Helpers
  
  public func gameUrlRequest() -> URLRequest?
  {
    return urlRequestForWebGame(game)
  }
  
  public func urlRequestForWebGame(_ webGame: POSGame?) -> URLRequest?
  {
    if let webGame = webGame,
      let lobbyUrl = self.lobbyUrl,
      let bankingUrl = self.bankingUrl,
      let xManUrl = self.xManUrl,
			let helpUrl = self.helpUrl
    {
      
			let host = "http://localhost:\(self.port!)"
      let path = "MobileWebGames/game/mgs"
      var queryPart = [String: Any]()
      
      // Setup the query parms to talk to the webserver.
      queryPart["lobbyURL"] = lobbyUrl.urlEncode()
      queryPart["bankingURL"] = bankingUrl.urlEncode()
      queryPart["xmanEndPoints"] = xManUrl.urlEncode()
			queryPart["helpURL"] = helpUrl.urlEncode()
      queryPart["moduleID"] = webGame.mid
      queryPart["clientID"] = webGame.cid
      queryPart["gameName"] = webGame.name
      queryPart["gameTitle"] = webGame.name
      queryPart["LanguageCode"] = config.getString("ul")
      queryPart["lobbyName"] = lobbyName
      queryPart["loginType"] = "FullUPE"
      queryPart["routerEndPoints"] = "" // Is this needed?
      queryPart["disablePoweredBy"] = "false"
      queryPart["isPracticePlay"] =  self.casinoSDK.playerType() == 1 ? "true" : "false"
      queryPart["disableTutorial"] = disableGameTutorials ? "true" : "false"
      queryPart["casinoID"] = swiftyAPI.casinoSDK.serverID()
      queryPart["username"] = "positron"
      queryPart["password"] = "positron"
      queryPart["clientTypeID"] = swiftyAPI.casinoSDK.clientType()
      queryPart["resolution"] = NWJC.currentResolution()
			
			
      if dontDisplayCurrencySymbol(), let isoCode = casinoSDK.playerSessionDetail("CurrencyISOCode")
      {
        let symbols = [getCurrencySymbolFor(isoCode, key: "full"), getCurrencySymbolFor(isoCode, key: "symbol")]
        var encoded = ""
        if let currencyDisplayFormat = casinoSDK.playerSessionDetail("CurrencyDisplayFormat") {
          let stripped = stripOutCurrencyFrom(currencyDisplayFormat, symbolsToStrip: symbols)
          encoded = stripped.urlEncode()
        }
        queryPart["currencyFormat"] = encoded
      }
      
      let queryElements: [String] = queryPart.map { k, v in "\(k)=\(v)" }
      let query = queryElements.joined(separator: "&")
      
      let urlString = "\(host)/\(path)?\(query)"
      
      return URLRequest(url: URL(string: urlString)!)
    }
    
    return nil
  }
  
  fileprivate func dontDisplayCurrencySymbol() -> Bool {
    return config.getInteger("showcurrencysymbol", withDefault: 1) == 0
  }
  
  fileprivate func getCurrencySymbolFor(_ isoCode: String, key: String) -> String {
    if let plistPath = Bundle.main.path(forResource: "CurrencySymbols", ofType: "plist") {
      if let resultDictionary = NSMutableDictionary(contentsOfFile: plistPath) {
        if let dict = resultDictionary.object(forKey: isoCode) as? NSMutableDictionary, let symbol = dict.object(forKey: key) as? String {
          return symbol
        }
      }
    }
    return ""
  }
  
  fileprivate func stripOutCurrencyFrom(_ displayFormat: String, symbolsToStrip: [String]) -> String {
    for index in 0 ..< symbolsToStrip.count {
      if let range = displayFormat.range(of: symbolsToStrip[index]) {
        return displayFormat.substring(to: range.lowerBound) + displayFormat.substring(from: range.upperBound)
      }
    }
    return displayFormat
  }
  
  public class func currentResolution() -> String?
  {
    if UIDevice.current.userInterfaceIdiom == .pad
    {
      return "1024x768" // We dont support retina iPad
    }
    else if UIDevice.current.userInterfaceIdiom == .phone
    {
      if UIScreen.main.bounds.size.height == 480 && UIScreen.main.bounds.size.width == 320
      {
        return "960x640" // We only support retina iPhone
      }
      else
      {
        return "1136x640"
      }
    }
    return nil
  }
  
  /**
   Resets the localstroage database file, so there is only one thus keeping the database in sync with the users last settings

   - parameter httpPort:
   */
  fileprivate func resetLocalStorage(_ httpPort: UInt?)
  {
    // TODO test on device...
    #if (arch(i386) || arch(x86_64)) && os(iOS)
      let bundleId = Bundle.main.infoDictionary!["CFBundleIdentifier"] as! String
      let pathsToFix = ["WebKit/LocalStorage", "WebKit/\(bundleId)/WebsiteData/LocalStorage", "Caches"]
    #else
      let pathsToFix = ["WebKit/LocalStorage", "WebKit/WebsiteData/LocalStorage", "Caches"] // UIWebView && WkWebViewPaths
    #endif
    
    // Check each path and fix up the localstorage files for 'localhost'
    for path in pathsToFix
    {
      let cacheURL = FileManager.default.urls(for: .libraryDirectory, in: .userDomainMask).last?.appendingPathComponent(path)
      
      if let cacheURL = cacheURL
      {
        let cacheDirContents: [URL]?
        do {
          cacheDirContents = try FileManager.default.contentsOfDirectory(at: cacheURL, includingPropertiesForKeys: [URLResourceKey.contentModificationDateKey], options: .skipsHiddenFiles)
        } catch _ {
          cacheDirContents = nil
        }
        
        let localstorageFiles = cacheDirContents?.filter() {
          $0.lastPathComponent.endsWith(".localstorage") && $0.lastPathComponent.beginsWith("http_localhost")
        }
        
        if let localstorageFiles = localstorageFiles {
          if localstorageFiles.count > 0 {
            
            var localstorageFile: URL? = nil
            
            if localstorageFiles.count > 1 {
              // Just incase we are getting a large list of files and sort it by date modified.
              
              let sLocal = localstorageFiles.sorted {
                var file1Date: AnyObject? = nil
                var file2Date: AnyObject? = nil
                do {
                  try ($0 as NSURL).getResourceValue(&file1Date, forKey: URLResourceKey.contentModificationDateKey)
                  try ($1 as NSURL).getResourceValue(&file2Date, forKey: URLResourceKey.contentModificationDateKey)
                } catch _ {
                  // do nothing
                }
                
                let date1 = file1Date as! Date
                let date2 = file2Date as! Date
                
                return date1.compare(date2) == ComparisonResult.orderedSame
              }
              
              let filesToDelete = sLocal[0 ... sLocal.count - 2]
              for toDelete in filesToDelete
              {
                do {
                  try FileManager.default.removeItem(at: toDelete)
                } catch _ {
                }
              }
              
              localstorageFile = sLocal.last
            }
            else
            {
              localstorageFile = localstorageFiles.first
            }
            
            if let localstorageFile = localstorageFile, let port = httpPort
            {
              do {
                try FileManager.default.moveItem(at: localstorageFile, to: cacheURL.appendingPathComponent("http_localhost_\(port).localstorage"))
              } catch _ {
              }
            }
          }
        }
      }
    }
  }
  
  public func launchActionByRequest(_ request: URLRequest) -> Bool {
    var shouldFollowUrl = false
    
    if let url = request.url {
      let path = url.path

      switch path {
      case let isInRange where isInRange.range(of: URLType.ResponsibleGaming.rawValue) != nil:
        if let onLoadRespGaming = self.onLoadResponsibleGaming {
          onLoadRespGaming()
        }
			case let isInRange where isInRange.range(of: URLType.Help.rawValue) != nil:
				if let onLoadHelp = self.onLoadHelp {
					onLoadHelp()
				}
			default:
        shouldFollowUrl = (url.host == "localhost") // if the host is localhost then redirect.
      }
			
    }
    
    return shouldFollowUrl
  }
}

extension String {
  func urlEncode() -> String {
    return (CFURLCreateStringByAddingPercentEscapes(nil, self as CFString!, nil, "!*'();:@&=+$,/?%#[]" as CFString!, CFStringBuiltInEncodings.UTF8.rawValue) as NSString) as String
  }
  func beginsWith (_ str: String) -> Bool {
    if let range = self.range(of: str) {
      return range.lowerBound == self.startIndex
    }
    return false
  }
  
  func endsWith (_ str: String) -> Bool {
    if let range = self.range(of: str) {
      return range.upperBound == self.endIndex
    }
    return false
  }
}

extension Data {
  func md5() -> String {
    let digestLength = Int(CC_MD5_DIGEST_LENGTH)
    let md5Buffer = UnsafeMutablePointer<CUnsignedChar>.allocate(capacity: digestLength)

    _ = self.withUnsafeBytes { bytes in
      CC_MD5(bytes, CC_LONG(self.count), md5Buffer)
    }

    let output = NSMutableString(capacity: Int(CC_MD5_DIGEST_LENGTH * 2))
    for i in 0 ..< digestLength {
      output.appendFormat("%02x", md5Buffer[i])
    }
    
    return String(format: output as String)
  }
}

extension URL {
  
  func getKeyVals() -> [String: String]? {
    guard let keyValues = self.query?.components(separatedBy: "&") else {
      return nil
    }
    var results = [String: String]()
    if keyValues.count > 0 {
      for pair in keyValues {
        let kv = pair.components(separatedBy: "=")
        if kv.count > 1 {
          results.updateValue(kv[1], forKey: kv[0])
        }
      }
      
    }
    return results
  }
}
