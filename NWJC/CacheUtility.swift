//
//  PurgeCache.swift
//  IOSCasino
//
//  Created by Nicole Naidoo on 2016/11/09.
//  Copyright © 2016 Microgaming. All rights reserved.
//

import Foundation

open class CacheUtility {
	
	fileprivate let cacheState = "CacheState"
	fileprivate var gameName : String
	fileprivate var purgeCacheGuid : String
	
	init(gamename: String, purgecacheGuid: String) {
		gameName = gamename
		purgeCacheGuid = purgecacheGuid
	}
	
	open func purgeRequired() -> Bool {
		let defaults = UserDefaults.standard
		if let stateDictionary = defaults.dictionary(forKey: cacheState) {
			if let guid = stateDictionary[gameName] as? String {
				if (purgeCacheGuid == guid) {
					return false
				}
			}
		}
		return true
	}
	
	open func purgeTheCache() {
		if let package = BEAMPackage(name: gameName) {
			let removePackageQueue = DispatchQueue(label: "com.mgs.beam.removepackage-queue", attributes: [])
			removePackageQueue.async(execute: {
				package.remove()
			})
		}
	}
	
	open func savePurgeGuidToUserDefaults() {
		let defaults = UserDefaults.standard
		if var stateDictionary = defaults.dictionary(forKey: cacheState) {
			stateDictionary.updateValue(purgeCacheGuid, forKey: gameName)
			defaults.setValue(stateDictionary, forKey: cacheState)
		}
		else {
			let dictionary = [gameName:purgeCacheGuid]
			defaults.setValue(dictionary, forKey: cacheState)
		}
	}
}
