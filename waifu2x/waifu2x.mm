//
//  waifu2x.m
//  waifu2x
//
//  Created by Cocoa Oikawa on 2019/4/25.
//  Copyright © 2019 Cocoa Oikawa. All rights reserved.
//

#import "waifu2x.h"
#import <unistd.h>
#import <algorithm>
#import <vector>

// image decoder and encoder with stb
#define STB_IMAGE_IMPLEMENTATION
#define STBI_NO_PSD
#define STBI_NO_TGA
#define STBI_NO_GIF
#define STBI_NO_HDR
#define STBI_NO_PIC
#include "stb_image.h"
#define STB_IMAGE_WRITE_IMPLEMENTATION
#include "stb_image_write.h"

// ncnn
#include "layer_type.h"
#include "net.h"
#include "gpu.h"

@implementation waifu2x

+ (NSBitmapImageRep *)input:(NSImage *)image noise:(int)noise scale:(int)scale tilesize:(int)tilesize progress:(waifu2xProgressBlock)cb {
    NSBitmapImageRep * output = nil;
    int total = 11;

    cb(1, total, NSLocalizedString(@"Check parameters...", @""));
    if (noise < -1 || noise > 3)
    {
        cb(1, total, NSLocalizedString(@"Error: supported noise is 0, 1 or 2", @""));
        return output;
    }

    if (scale < 1 || scale > 2)
    {
        cb(1, total, NSLocalizedString(@"Error: supported scale is 1 or 2", @""));
        return output;
    }

    if (tilesize < 32)
    {
        cb(1, total, NSLocalizedString(@"Error: tilesize should no less than 32", @""));
        return output;
    }

    cb(2, total, NSLocalizedString(@"Prepare models...", @""));
    const int TILE_SIZE_X = tilesize;
    const int TILE_SIZE_Y = tilesize;
    int prepadding = 0;
    NSString * parampath = nil;
    NSString * modelpath = nil;
    if (noise == -1)
    {
        prepadding = 18;
        parampath = [[NSBundle mainBundle] pathForResource:@"scale2.0x_model.param" ofType:nil];
        modelpath = [[NSBundle mainBundle] pathForResource:@"scale2.0x_model.bin" ofType:nil];
    }
    else if (scale == 1)
    {
        prepadding = 28;
        parampath = [[NSBundle mainBundle] pathForResource:[NSString stringWithFormat:@"noise%d_model.param", noise] ofType:nil];
        modelpath = [[NSBundle mainBundle] pathForResource:[NSString stringWithFormat:@"noise%d_model.bin", noise] ofType:nil];
    }
    else if (scale == 2)
    {
        prepadding = 18;
        parampath = [[NSBundle mainBundle] pathForResource:[NSString stringWithFormat:@"noise%d_scale2.0x_model.param", noise] ofType:nil];
        modelpath = [[NSBundle mainBundle] pathForResource:[NSString stringWithFormat:@"noise%d_scale2.0x_model.bin", noise] ofType:nil];
    }
    
    setenv("VK_ICD_FILENAMES", [[NSBundle mainBundle] pathForResource:@"MoltenVK_icd" ofType:@"json"].UTF8String, 1);

    cb(3, total, NSLocalizedString(@"Creating GPU instance...", @""));
    ncnn::create_gpu_instance();
    ncnn::VulkanDevice* vkdev = new ncnn::VulkanDevice;

    // HACK ncnn fp16a produce incorrect result, force off
    // TODO provide a way to control storage and arothmetic precision in ncnn
    ((ncnn::GpuInfo*)(&vkdev->info))->support_fp16_arithmetic = false;

    {
        ncnn::Net waifu2x;

        waifu2x.use_vulkan_compute = true;
        waifu2x.set_vulkan_device(vkdev);

        cb(4, total, NSLocalizedString(@"Loading models...", @""));
        waifu2x.load_param(parampath.UTF8String);
        waifu2x.load_model(modelpath.UTF8String);

        ncnn::Option opt = ncnn::get_default_option();
        opt.blob_vkallocator = vkdev->allocator();
        opt.workspace_vkallocator = vkdev->allocator();
        opt.staging_vkallocator = vkdev->staging_allocator();

        cb(5, total, NSLocalizedString(@"Initialize pipeline...", @""));
        // initialize preprocess and postprocess pipeline
        ncnn::Pipeline* waifu2x_preproc;
        ncnn::Pipeline* waifu2x_postproc;
        {
            std::vector<ncnn::vk_specialization_type> specializations(1);
            specializations[0].i = 0;

            waifu2x_preproc = new ncnn::Pipeline(vkdev);
            waifu2x_preproc->set_optimal_local_size_xyz(32, 32, 3);
            if (vkdev->info.support_fp16_storage && vkdev->info.support_int8_storage)
                waifu2x_preproc->create(waifu2x_preproc_int8s_spv_data, sizeof(waifu2x_preproc_int8s_spv_data), "waifu2x_preproc_int8s", specializations, 2, 9);
            else if (vkdev->info.support_fp16_storage)
                waifu2x_preproc->create(waifu2x_preproc_fp16s_spv_data, sizeof(waifu2x_preproc_fp16s_spv_data), "waifu2x_preproc_fp16s", specializations, 2, 9);
            else
                waifu2x_preproc->create(waifu2x_preproc_spv_data, sizeof(waifu2x_preproc_spv_data), "waifu2x_preproc", specializations, 2, 9);

            waifu2x_postproc = new ncnn::Pipeline(vkdev);
            waifu2x_postproc->set_optimal_local_size_xyz(32, 32, 3);
            if (vkdev->info.support_fp16_storage && vkdev->info.support_int8_storage)
                waifu2x_postproc->create(waifu2x_postproc_int8s_spv_data, sizeof(waifu2x_postproc_int8s_spv_data), "waifu2x_postproc_int8s", specializations, 2, 8);
            else if (vkdev->info.support_fp16_storage)
                waifu2x_postproc->create(waifu2x_postproc_fp16s_spv_data, sizeof(waifu2x_postproc_fp16s_spv_data), "waifu2x_postproc_fp16s", specializations, 2, 8);
            else
                waifu2x_postproc->create(waifu2x_postproc_spv_data, sizeof(waifu2x_postproc_spv_data), "waifu2x_postproc", specializations, 2, 8);
        }

        // main routine
        {
            cb(6, total, NSLocalizedString(@"Decoding input image...", @""));

            char buffer[128] = {'\0'};
            sprintf(buffer, "/tmp/waifu2x.XXXXXXXXXXXXXXXXXXXXXXXXXXXXX");
            mkstemp(buffer);

            NSData *pngData = [[NSBitmapImageRep imageRepWithData:[image TIFFRepresentation]] representationUsingType:NSBitmapImageFileTypePNG properties:@{}];
            [pngData writeToFile:[NSString stringWithFormat:@"%s", buffer] atomically:YES];

            int w, h, c;
            unsigned char* rgbdata = stbi_load(buffer, &w, &h, &c, 3);

            ncnn::Mat outrgb(w * scale, h * scale, (size_t)3u, 3);

            // prepadding
            int prepadding_bottom = prepadding;
            int prepadding_right = prepadding;
            if (scale == 1)
            {
                prepadding_bottom += (h + 3) / 4 * 4 - h;
                prepadding_right += (w + 3) / 4 * 4 - w;
            }
            if (scale == 2)
            {
                prepadding_bottom += (h + 1) / 2 * 2 - h;
                prepadding_right += (w + 1) / 2 * 2 - w;
            }

            // each tile 400x400
            int xtiles = (w + TILE_SIZE_X - 1) / TILE_SIZE_X;
            int ytiles = (h + TILE_SIZE_Y - 1) / TILE_SIZE_Y;

            cb(7, total, NSLocalizedString(@"Uplaoding data to GPU...", @""));
            int step8flag = 0;
            // TODO #pragma omp parallel for
            for (int yi = 0; yi < ytiles; yi++)
            {
                int in_tile_y0 = std::max(yi * TILE_SIZE_Y - prepadding, 0);
                int in_tile_y1 = std::min((yi + 1) * TILE_SIZE_Y + prepadding_bottom, h);

                ncnn::Mat in;
                if (vkdev->info.support_fp16_storage && vkdev->info.support_int8_storage)
                {
                    in = ncnn::Mat(w, (in_tile_y1 - in_tile_y0), rgbdata + in_tile_y0 * w * 3, (size_t)3u, 1);
                }
                else
                {

                    in = ncnn::Mat::from_pixels(rgbdata + in_tile_y0 * w * 3, ncnn::Mat::PIXEL_RGB, w, (in_tile_y1 - in_tile_y0));
                }

                ncnn::VkCompute cmd(vkdev);

                // upload
                ncnn::VkMat in_gpu;
                {
                    in_gpu.create_like(in, opt.blob_vkallocator, opt.staging_vkallocator);

                    in_gpu.prepare_staging_buffer();
                    in_gpu.upload(in);

                    cmd.record_upload(in_gpu);

                    if (xtiles > 1)
                    {
                        cmd.submit();
                        cmd.wait();
                        cmd.reset();
                    }
                }

                int out_tile_y0 = std::max(yi * TILE_SIZE_Y, 0);
                int out_tile_y1 = std::min((yi + 1) * TILE_SIZE_Y, h);

                ncnn::VkMat out_gpu;
                if (vkdev->info.support_fp16_storage && vkdev->info.support_int8_storage)
                {
                    out_gpu.create(w * scale, (out_tile_y1 - out_tile_y0) * scale, (size_t)3u, 1, opt.blob_vkallocator, opt.staging_vkallocator);
                }
                else
                {
                    out_gpu.create(w * scale, (out_tile_y1 - out_tile_y0) * scale, 3, (size_t)4u, 1, opt.blob_vkallocator, opt.staging_vkallocator);
                }

                for (int xi = 0; xi < xtiles; xi++)
                {
                    // preproc
                    ncnn::VkMat in_tile_gpu;
                    {
                        // crop tile
                        int tile_x0 = xi * TILE_SIZE_X;
                        int tile_x1 = std::min((xi + 1) * TILE_SIZE_X, w) + prepadding + prepadding_right;
                        int tile_y0 = yi * TILE_SIZE_Y;
                        int tile_y1 = std::min((yi + 1) * TILE_SIZE_Y, h) + prepadding + prepadding_bottom;

                        in_tile_gpu.create(tile_x1 - tile_x0, tile_y1 - tile_y0, 3, (size_t)4u, 1, opt.blob_vkallocator, opt.staging_vkallocator);

                        std::vector<ncnn::VkMat> bindings(2);
                        bindings[0] = in_gpu;
                        bindings[1] = in_tile_gpu;

                        std::vector<ncnn::vk_constant_type> constants(9);
                        constants[0].i = in_gpu.w;
                        constants[1].i = in_gpu.h;
                        constants[2].i = in_gpu.cstep;
                        constants[3].i = in_tile_gpu.w;
                        constants[4].i = in_tile_gpu.h;
                        constants[5].i = in_tile_gpu.cstep;
                        constants[6].i = std::max(prepadding - yi * TILE_SIZE_Y, 0);
                        constants[7].i = prepadding;
                        constants[8].i = xi * TILE_SIZE_X;

                        cmd.record_pipeline(waifu2x_preproc, bindings, constants, in_tile_gpu);
                    }

                    if (!step8flag) {
                        step8flag = 1;
                        cb(8, total, NSLocalizedString(@"waifu2x model forwarding...", @""));
                    }

                    // waifu2x
                    ncnn::VkMat out_tile_gpu;
                    {
                        ncnn::Extractor ex = waifu2x.create_extractor();
                        ex.input("Input1", in_tile_gpu);

                        ex.extract("Eltwise4", out_tile_gpu, cmd);
                    }

                    // postproc
                    {
                        std::vector<ncnn::VkMat> bindings(2);
                        bindings[0] = out_tile_gpu;
                        bindings[1] = out_gpu;

                        std::vector<ncnn::vk_constant_type> constants(8);
                        constants[0].i = out_tile_gpu.w;
                        constants[1].i = out_tile_gpu.h;
                        constants[2].i = out_tile_gpu.cstep;
                        constants[3].i = out_gpu.w;
                        constants[4].i = out_gpu.h;
                        constants[5].i = out_gpu.cstep;
                        constants[6].i = xi * TILE_SIZE_X * scale;
                        constants[7].i = out_gpu.w - xi * TILE_SIZE_X * scale;

                        ncnn::VkMat dispatcher;
                        dispatcher.w = out_gpu.w - xi * TILE_SIZE_X * scale;
                        dispatcher.h = out_gpu.h;
                        dispatcher.c = 3;

                        cmd.record_pipeline(waifu2x_postproc, bindings, constants, dispatcher);
                    }

                    if (xtiles > 1)
                    {
                        cmd.submit();
                        cmd.wait();
                        cmd.reset();
                    }
                }

                cb(9, total, NSLocalizedString(@"retrieving output...", @""));
                // download
                {
                    out_gpu.prepare_staging_buffer();
                    cmd.record_download(out_gpu);

                    cmd.submit();
                    cmd.wait();
                }

                if (vkdev->info.support_fp16_storage && vkdev->info.support_int8_storage)
                {

                    ncnn::Mat out(out_gpu.w, out_gpu.h, (unsigned char*)outrgb.data + yi * scale * TILE_SIZE_Y * w * scale * 3, (size_t)3u, 1);

                    out_gpu.download(out);
                }
                else
                {
                    ncnn::Mat out;
                    out.create_like(out_gpu, opt.blob_allocator);
                    out_gpu.download(out);

                    out.to_pixels((unsigned char*)outrgb.data + yi * scale * TILE_SIZE_Y * w * scale * 3, ncnn::Mat::PIXEL_RGB);
                }
            }

            stbi_image_free(rgbdata);
            unlink(buffer);

            NSData *data = [NSData dataWithBytes:outrgb.data length:3 * outrgb.total()];
            CGColorSpaceRef colorSpace;
            if (outrgb.elemsize == 1)
            {
                colorSpace = CGColorSpaceCreateDeviceGray();
            }
            else
            {
                colorSpace = CGColorSpaceCreateDeviceRGB();
            }
            CGDataProviderRef provider = CGDataProviderCreateWithCFData((__bridge CFDataRef)data);
            CGImageRef outputImageRef = CGImageCreate(outrgb.w,                                       // Width
                                                outrgb.h,                                       // Height
                                                8,                                              // Bits per component
                                                8 * outrgb.elemsize,                            // Bits per pixel
                                                3 * outrgb.w,                                   // Bytes per row
                                                colorSpace,                                     // Colorspace
                                                kCGImageAlphaNone | kCGBitmapByteOrderDefault,  // Bitmap info flags
                                                provider,                                       // CGDataProviderRef
                                                NULL,                                           // Decode
                                                false,                                          // Should interpolate
                                                kCGRenderingIntentDefault);                     // Intent

            output = [[NSBitmapImageRep alloc] initWithCGImage:outputImageRef];

            CGImageRelease(outputImageRef);
            CGDataProviderRelease(provider);
            CGColorSpaceRelease(colorSpace);
        }

        cb(10, total, NSLocalizedString(@"cleanup...", @""));
        // cleanup preprocess and postprocess pipeline
        {
            delete waifu2x_preproc;
            delete waifu2x_postproc;
        }
    }

    delete vkdev;

    ncnn::destroy_gpu_instance();

    cb(11, total, NSLocalizedString(@"done!", @""));
    return output;
}

@end
