//
//  NoWrapJustCacheTests.swift
//  NoWrapJustCacheTests
//
//  Created by Kishyr Ramdial on 2015/02/04.
//  Copyright (c) 2015 MGS. All rights reserved.
//

import UIKit
import XCTest

class NoWrapJustCacheTests: XCTestCase
{
  let fileManager = NSFileManager.defaultManager()
  let cachePath = NSSearchPathForDirectoriesInDomains(.CachesDirectory, .UserDomainMask, true)[0].stringByAppendingPathComponent("NoWrapJustCache")
  let Beam = BEAM.client()
  var package = BEAMPackage()

  override func setUp() {
    super.setUp()
    
    Beam.setupDatabase()
    
    package = BEAMPackage()
    package.name = "TestPackage1"
    package.save()
    
    Beam.__resetDatabase()
  }
  
  override func tearDown() {
    super.tearDown()
  }

  // CacheMoney Tests
  
  func testCreatingCacheDirectoryOnInit() {
    fileManager.removeItemAtPath(cachePath, error: nil)
    if fileManager.fileExistsAtPath(cachePath) {
      XCTFail("Cache path still exists")
    }
    else {
      XCTAssertTrue(fileManager.fileExistsAtPath(cachePath), "Cache Directory didn't get created")
    }
  }
  
  func testPathForKey() {
    let key = "TestingKey"
    let pathKey = cachePath.stringByAppendingPathComponent("\(key).raw")
    
    let path = Beam.pathForKey(key)
    XCTAssertTrue(path == pathKey, "Path with hashed key isn't the same")
  }
  
  func testSettingAndGettingData() {
    let stringValue = "TestingValue"
    let value = stringValue.dataUsingEncoding(NSUTF8StringEncoding, allowLossyConversion: false)!
    let key = "TestingKey"
    
    let pathForKey = Beam.pathForKey(key)
    Beam.setData(value, forKey: key)
    
    XCTAssertTrue(fileManager.fileExistsAtPath(pathForKey), "Key doesn't exist on disk")
    XCTAssertTrue(Beam.__cacheHasDataForKey(key), "Value doesn't exist in the NSCache object")

    if let returnedData = Beam.dataForKey(key) {
      let stringData = NSString(data: returnedData, encoding: NSUTF8StringEncoding)
      XCTAssertTrue(stringValue == stringData, "Returned data isn't the same")
    }
    else {
      XCTFail("No data returned for key")
    }
  }
  
  func testAddFileToDatabse() {
    let hash = "123asd4561"
    let path = "/request/with/path"
    let etag = "12345678901"
    let mt = "image/jpg"
    let mh = "3D211B1ECCEA68F134A4D242D48BDE5D"
    
    let result: Bool = BEAMWebFile.addFileWithHash(hash, path: path, etag: etag, mimetype: mt, fileSize: 0, package: package, manifestHash: mh)
    XCTAssertTrue(result, "Failed to add file to db")
    
    let file: BEAMWebFile? = BEAMWebFile(path: path, inPackage: package)
    XCTAssertFalse(file == nil, "File is nil")
    XCTAssertTrue(file?.fileHash == hash, "File hash doesn't match")
    XCTAssertTrue(file?.etag == etag, "File etag doesn't match")
  }

  func testAddDuplicatesToDatabase() {
    let hash = "123asd4562"
    let path = "/request/with/path"
    let etag = "12345678902"
    let mt = "image/jpg"
    let mh = "3D211B1ECCEA68F134A4D242D48BDE5D"
    
    BEAMWebFile.addFileWithHash(hash, path: path, etag: etag, mimetype: mt, fileSize: 0, package: package, manifestHash: mh)
    BEAMWebFile.addFileWithHash(hash, path: path, etag: etag, mimetype: mt, fileSize: 0, package: package, manifestHash: mh)
    
    let allFiles = BEAMWebFile.allFiles() as! [BEAMWebFile]
    XCTAssertTrue(count(allFiles) == 1, "Database is adding duplicates based on path")
  }
  
  func testDeleteFileFromDatabase() {
    let hash = "123asd4561"
    let path = "/request/with/path"
    let etag = "12345678901"
    let mt = "image/jpg"
    let mh = "3D211B1ECCEA68F134A4D242D48BDE5D"
    
    BEAMWebFile.addFileWithHash(hash, path: path, etag: etag, mimetype: mt, fileSize: 0, package: package, manifestHash: mh)
    BEAMWebFile.deleteFileWithPath(path)
    let file: BEAMWebFile? = BEAMWebFile(path: path, inPackage: package)
    XCTAssertTrue(file == nil, "File exists after being delete from database")
  }
}
