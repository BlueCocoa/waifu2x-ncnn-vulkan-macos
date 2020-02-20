//
//  GPUInfo.m
//  waifu2x-gui
//
//  Created by Cocoa on 20/02/2020.
//  Copyright © 2020 Cocoa Oikawa. All rights reserved.
//

#import "GPUInfo.h"

@implementation GPUInfo 

@synthesize name;
@synthesize deviceID;
@synthesize physicalDevice;

+ (instancetype)initWithName:(NSString *)name deviceID:(uint32_t)deviceID physicalDevice:(VkPhysicalDevice)device {
    GPUInfo * info = [[GPUInfo alloc] init];
    if (info) {
        [info setName:name];
        [info setDeviceID:deviceID];
        [info setPhysicalDevice:device];
    }
    return info;
}

@end
