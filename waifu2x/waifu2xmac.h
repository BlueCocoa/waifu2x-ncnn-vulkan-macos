//
//  waifu2xmac.h
//  waifu2xmac
//
//  Created by Cocoa on 2019/4/25.
//  Copyright © 2019-2020 Cocoa. All rights reserved.
//

#import <AppKit/AppKit.h>
#import <Foundation/Foundation.h>

typedef void (^waifu2xProgressBlock)(int current, int total, NSString * description);

@interface GPUInfo : NSObject
@property (strong) NSString * name;
@property (nonatomic) uint32_t deviceID;
@end

@interface waifu2xmac : NSObject

+ (NSImage *)input:(NSString *)image
                      noise:(int)noise
                      scale:(int)scale
                   tilesize:(int)tilesize
                      model:(NSString *)model
                      gpuid:(int)gpuid
               load_job_num:(int)jobs_load
               proc_job_num:(int)jobs_proc
               save_job_num:(int)jobs_save
                   progress:(waifu2xProgressBlock)cb;
+ (NSArray<GPUInfo *> *)AllGPUs;
@end

