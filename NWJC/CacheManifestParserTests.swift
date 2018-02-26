//
//  CacheManifestParserTests.swift
//  CacheManifestParserTests
//
//  Created by Kishyr Ramdial on 2015/04/01.
//  Copyright (c) 2015 MGS. All rights reserved.
//

import UIKit
import XCTest

class CacheManifestParserTests: XCTestCase {
  
  let cmp = CacheManifestParser()
  
  override func setUp() {
    super.setUp()
    
    cmp.manifestUrl = NSBundle.mainBundle().URLForResource("BarsNStripes.appcache", withExtension: nil)
//    cmp.manifestUrl = NSURL(string: "http://mobile3.gameassists.co.uk/MobileWebGames_Showcase/CacheManifests/Showcase_mgs_barsNStripes_en_1024x768.appcache")
  }
  
  override func tearDown() {
    super.tearDown()
  }
  
  func testDownloadingCache() {
    let expectation: XCTestExpectation = expectationWithDescription("Downloading Cache Manifest async")
    
    cmp.downloadManifestWithSuccessBlock({
      manifest in
      
      XCTAssertTrue(true, "This should never return false")
      expectation.fulfill()

    }, failureBlock: {
      XCTFail("There was a failure downloading the cache manifest")
      expectation.fulfill()
    })
    
    waitForExpectationsWithTimeout(5.0, handler: nil)
  }
  
  func testParsingManifestHash() {
    let expectation: XCTestExpectation = expectationWithDescription("Downloading Cache Manifest async and testing parsing")
    
    cmp.downloadManifestWithSuccessBlock({
      [unowned self] manifest in
      
      XCTAssertFalse(manifest.hash == nil, "Manifest hash is nil")
      XCTAssertFalse(manifest.files == nil, "Manifest files are nil")
      
      if let manifestHash = manifest.hash {
        XCTAssertTrue(manifestHash == "D41D8CD98F00B204E9800998ECF8427E", "Manifest hash doesn't match")
      }
      else {
        XCTFail("Manifest hash doesn't match")
      }
      
      if let manifestFiles = manifest.files {
        XCTAssertTrue(count(manifest.files!) > 0, "Manifest has no files")
      }
      else {
        XCTFail("Manifest has no files")
      }
      
      expectation.fulfill()

    }, failureBlock: {
      XCTFail("There was a failure parsing the cache manifest")
      expectation.fulfill()
    })
    
    waitForExpectationsWithTimeout(5.0, handler: nil)
  }
  
}
