//
//  GCDWebServer+NJWC.m
//  
//
//  Created by Kishyr Ramdial on 2015/06/19.
//
//

#import "GCDWebServer+NJWC.h"
#import <objc/runtime.h>

@implementation GCDWebServer (NJWC)

- (void)nwjc_setOptionValue:(id)value forKey:(NSString *)key
{
  Ivar optionsInstance = class_getInstanceVariable([self class], "_options");
  NSDictionary *privateOptions = (NSDictionary *)object_getIvar(self, optionsInstance);
  NSMutableDictionary *mutableOptions = [NSMutableDictionary dictionaryWithDictionary:privateOptions];
  [mutableOptions setObject:value forKey:key];
  privateOptions = [NSDictionary dictionaryWithDictionary:mutableOptions];
  object_setIvar(self, optionsInstance, privateOptions);
}

@end
