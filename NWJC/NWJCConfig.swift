//
//  NWJCConfig.swift
//  Betway
//
//  Created by Ryan Chand on 2015/11/09.
//  Copyright © 2015 MGS. All rights reserved.
//
//  creating a NWJC config class to facilitate any setup requirements for NWJC, this object can be tweaked and passed to NoWrapController
//  to initialize NWJC with the settings in this class.

import Foundation

@objc
open class NWJCConfig: NSObject {
  // this will disable the H5 game tutorial when true is set
  // and will enable (not disable) the H5 game tutorial when false is set
  // Note. it requires string values of true and false, and this will be initialized to true by default
  var shouldDisableGameTutorials = true
  
  // this will override the sounds settings to be set from the applicaiton config handler when set to true
  // and when set to false it will default to the H5 local storage session instead
  var shouldOverrideSoundSettings = true
  
  /* add additional NWJC configuration settings here */
}
