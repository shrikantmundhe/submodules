//
//  CacheManifestParser.swift
//  CacheManifestParser
//
//  Created by Kishyr Ramdial on 2015/04/01.
//  Copyright (c) 2015 MGS. All rights reserved.
//

import Foundation

@objc
open class CacheManifestParser : NSObject
{
  public typealias FailureBlock = (() -> ())?
  public typealias ManifestSuccessBlock = (BEAMPackage, String?, [String]?) -> ()
  
  open var manifestUrl: URL?
  open var package: BEAMPackage?
  fileprivate let session = URLSession(configuration: URLSessionConfiguration.default)
  
  override init() {
    super.init()
  }
  
  deinit {
    session.invalidateAndCancel()
  }
  
  open func downloadManifestForPackage(_ package: BEAMPackage, withSuccessBlock successBlock: @escaping ManifestSuccessBlock, withFailureBlock failureBlock: FailureBlock) {
    if let manifestUrl = manifestUrl {
      self.package = package;
      var task: URLSessionDataTask?
      task = session.dataTask(with: manifestUrl, completionHandler: {
        [unowned self] body, response, error in
        
        let statusCode = (response != nil) ? (response as! HTTPURLResponse).statusCode : -1
        let statusOK = statusCode >= 200 && statusCode <= 299
        
        if (error == nil && statusOK)
        {
          if let cacheString = NSString(data: body!, encoding: String.Encoding.utf8.rawValue) as String? {
						let parsed = self.parseManifestString(cacheString)
            successBlock(parsed.package, parsed.hash, parsed.files)
          }
          else {
            if let failureBlock = failureBlock {
              failureBlock()
            }
          }
        }
        else {
          if let failureBlock = failureBlock {
            failureBlock()
          }
        }
      }) 
      
      task!.resume()
    }
  }
  
  //We duplicated this method because in NWJC it was crasking with unowned self, so we duplicated it and made it weak self, I know this is not the fix but we didnt want to fix the bugs as it was close to release
  //and we didnt want to break any functionality, this will be added to our techinal list to fix.
  open func weakDownloadManifestForPackage(_ package: BEAMPackage, withSuccessBlock successBlock: @escaping ManifestSuccessBlock, withFailureBlock failureBlock: FailureBlock) {
    if let manifestUrl = manifestUrl {
      self.package = package;
      var task: URLSessionDataTask?
      task = session.dataTask(with: manifestUrl, completionHandler: {
        [weak self] body, response, error in
        
        if let weakSelf = self { //this breaks game manager (cant use weak self because beam uses this for background loading ) NWJC is incorrect.
          let statusCode = (response != nil) ? (response as! HTTPURLResponse).statusCode : -1
          let statusOK = statusCode >= 200 && statusCode <= 299
          
          if (error == nil && statusOK)
          {
            if let cacheString = NSString(data: body!, encoding: String.Encoding.utf8.rawValue) as String? {
							let parsed = weakSelf.parseManifestString(cacheString)
							successBlock(parsed.package, parsed.hash, parsed.files)
            }
            else {
              if let failureBlock = failureBlock {
                failureBlock()
              }
            }
          }
          else {
            if let failureBlock = failureBlock {
              failureBlock()
            }
          }
        }
      }) 
      
      task!.resume()
    }
  }
  
  
  

	func parseManifestString(_ manifest: String) -> (package: BEAMPackage, hash: String?, files: [String]?) {

    func parseHash() -> String? {
      return manifest.sha1()
    }
    
    func parseFiles() -> [String]? {
      let noCarridgeManifest = manifest.replacingOccurrences(of: "\r\n", with: "\n")
      
      guard let cacheHeaderRange = noCarridgeManifest.range(of: "CACHE:"), let networkHeaderRange = noCarridgeManifest.range(of: "NETWORK:") else {
        return nil
      }
      
      let filesRange = cacheHeaderRange.upperBound ..< networkHeaderRange.lowerBound
      let filesStr = noCarridgeManifest.substring(with: filesRange)
      let files = filesStr.components(separatedBy: "\n")
      
      return files.filter( { $0 != "" } )
    }
    
    return (self.package!, parseHash(), parseFiles())
  }
}

extension String {
  func sha1() -> String {
    let data = self.data(using: String.Encoding.utf8)!
    var digest = [UInt8](repeating: 0, count: Int(CC_SHA1_DIGEST_LENGTH))
    CC_SHA1((data as NSData).bytes, CC_LONG(data.count), &digest)
    let hexBytes = digest.map { String(format: "%02hhx", $0) }
    return hexBytes.joined(separator: "")
  }
}
