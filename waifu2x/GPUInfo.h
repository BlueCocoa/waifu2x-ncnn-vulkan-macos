//
//  GPUInfo.h
//  waifu2x-gui
//
//  Created by Cocoa on 20/02/2020.
//  Copyright © 2020 Cocoa Oikawa. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <IOKit/graphics/IOGraphicsLib.h>
#import <vulkan/vulkan.h>

NS_ASSUME_NONNULL_BEGIN

@interface GPUInfo : NSObject

+ (instancetype)initWithName:(NSString *)name deviceID:(uint32_t)deviceID physicalDevice:(VkPhysicalDevice)device;

@property (strong) NSString * name;
@property (nonatomic) uint32_t deviceID;
@property (nonatomic) VkPhysicalDevice physicalDevice;

@end

NS_ASSUME_NONNULL_END
