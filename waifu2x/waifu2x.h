//
//  waifu2x.h
//  waifu2x
//
//  Created by Cocoa Oikawa on 2019/4/25.
//  Copyright © 2019 Cocoa Oikawa. All rights reserved.
//

#import <AppKit/AppKit.h>
#import <Foundation/Foundation.h>

static const uint32_t waifu2x_preproc_spv_data[] = {
    #include "waifu2x_preproc.spv.hex.h"
};
static const uint32_t waifu2x_preproc_fp16s_spv_data[] = {
    #include "waifu2x_preproc_fp16s.spv.hex.h"
};
static const uint32_t waifu2x_preproc_int8s_spv_data[] = {
    #include "waifu2x_preproc_int8s.spv.hex.h"
};
static const uint32_t waifu2x_postproc_spv_data[] = {
    #include "waifu2x_postproc.spv.hex.h"
};
static const uint32_t waifu2x_postproc_fp16s_spv_data[] = {
    #include "waifu2x_postproc_fp16s.spv.hex.h"
};
static const uint32_t waifu2x_postproc_int8s_spv_data[] = {
    #include "waifu2x_postproc_int8s.spv.hex.h"
};

typedef void (^waifu2xProgressBlock)(int current, int total, NSString * description);

@interface waifu2x : NSObject

+ (NSBitmapImageRep *)input:(NSImage *)imagePath noise:(int)noise scale:(int)scale tilesize:(int)tilesize progress:(waifu2xProgressBlock)cb;

@end

