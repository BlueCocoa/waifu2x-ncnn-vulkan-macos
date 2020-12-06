//
//  waifu2xmac.h
//  waifu2xmac
//
//  Created by Cocoa on 2019/4/25.
//  Copyright © 2019-2020 Cocoa. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AppKit/AppKit.h>
#import "GPUInfo.h"

typedef void (^waifu2xProgressBlock)(int current, int total, NSString * description);
typedef void (^waifu2xCompleteSingleBlock)(cv::Mat& scaled_frame, int current, uint64_t total);

@interface waifu2xmac : NSObject

+ (void)videoInput:(cv::VideoCapture&)video
        noise:(int)noise
        scale:(int)scale
     tilesize:(int)tilesize
        model:(NSString *)model
        gpuid:(int)gpuid
     tta_mode:(BOOL)enable_tta_mode
 proc_job_num:(int)jobs_proc
 save_job_num:(int)jobs_save
      save_cb:(waifu2xCompleteSingleBlock)save_cb
    VRAMUsage:(double *)usage
     progress:(waifu2xProgressBlock)cb;

+ (NSImage *)input:(NSArray<NSString *> *)inputpaths
            output:(NSArray<NSString *> *)outputpaths
             noise:(int)noise
             scale:(int)scale
          tilesize:(int)tilesize
             model:(NSString *)model
             gpuid:(int)gpuid
          tta_mode:(BOOL)enable_tta_mode
      load_job_num:(int)jobs_load
      proc_job_num:(int)jobs_proc
      save_job_num:(int)jobs_save
         save_file:(BOOL)save_file
           save_cb:(waifu2xCompleteSingleBlock)save_cb
       single_mode:(BOOL)is_single_mode
         VRAMUsage:(double *)usage
          progress:(waifu2xProgressBlock)cb;

@end

