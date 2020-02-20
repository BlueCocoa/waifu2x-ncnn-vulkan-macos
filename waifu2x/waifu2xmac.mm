//
//  waifu2xmac.mm
//  waifu2xmac
//
//  Created by Cocoa on 2019/4/25.
//  Copyright © 2019-2020 Cocoa. All rights reserved.
//

#import "waifu2xmac.h"
#import "waifu2x-ncnn-vulkan/src/waifu2x.h"
#import <unistd.h>
#import <algorithm>
#import <vector>
#import <queue>

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
#include "cpu.h"
#include "gpu.h"
#include "platform.h"
#include "waifu2x-ncnn-vulkan/src/filesystem_utils.h"

class Task
{
public:
    int id;

    path_t inpath;
    path_t outpath;

    ncnn::Mat inimage;
    ncnn::Mat outimage;
};

class TaskQueue
{
public:
    TaskQueue()
    {
    }

    void put(const Task& v)
    {
        lock.lock();

        while (tasks.size() >= 8) // FIXME hardcode queue length
        {
            condition.wait(lock);
        }

        tasks.push(v);

        lock.unlock();

        condition.signal();
    }

    void get(Task& v)
    {
        lock.lock();

        while (tasks.size() == 0)
        {
            condition.wait(lock);
        }

        v = tasks.front();
        tasks.pop();

        lock.unlock();

        condition.signal();
    }

private:
    ncnn::Mutex lock;
    ncnn::ConditionVariable condition;
    std::queue<Task> tasks;
};

TaskQueue toproc;
TaskQueue tosave;

class LoadThreadParams
{
public:
    int scale;
    int jobs_load;

    // session data
    std::vector<path_t> input_files;
    std::vector<path_t> output_files;
};

void* load(void* args)
{
    const LoadThreadParams* ltp = (const LoadThreadParams*)args;
    const int count = (int)ltp->input_files.size();
    const int scale = ltp->scale;

    #pragma omp parallel for num_threads(ltp->jobs_load)
    for (int i=0; i<count; i++)
    {
        const path_t& imagepath = ltp->input_files[i];

        unsigned char* pixeldata = 0;
        int w;
        int h;
        int c;

#if _WIN32
        pixeldata = wic_decode_image(imagepath.c_str(), &w, &h, &c);
#else // _WIN32
        pixeldata = stbi_load(imagepath.c_str(), &w, &h, &c, 3);
#endif // _WIN32
        if (pixeldata)
        {
            Task v;
            v.id = i;
            v.inpath = imagepath;
            v.outpath = ltp->output_files[i];

            v.inimage = ncnn::Mat(w, h, (void*)pixeldata, (size_t)3, 3);
            v.outimage = ncnn::Mat(w * scale, h * scale, (size_t)3u, 3);

            toproc.put(v);
        }
        else
        {
#if _WIN32
            fwprintf(stderr, L"decode image %ls failed\n", imagepath.c_str());
#else // _WIN32
            fprintf(stderr, "decode image %s failed\n", imagepath.c_str());
#endif // _WIN32
        }
    }

    return 0;
}

class ProcThreadParams
{
public:
    const Waifu2x* waifu2x;
};

void* proc(void* args)
{
    const ProcThreadParams* ptp = (const ProcThreadParams*)args;
    const Waifu2x* waifu2x = ptp->waifu2x;

    for (;;)
    {
        Task v;

        toproc.get(v);

        if (v.id == -233)
            break;

        waifu2x->process(v.inimage, v.outimage);

        tosave.put(v);
    }

    return 0;
}

class SaveThreadParams
{
public:
    int verbose;
};

void* save(void* args)
{
    const SaveThreadParams* stp = (const SaveThreadParams*)args;
    const int verbose = stp->verbose;

    for (;;)
    {
        Task v;

        tosave.get(v);

        if (v.id == -233)
            break;

        // free input pixel data
        {
            unsigned char* pixeldata = (unsigned char*)v.inimage.data;
#if _WIN32
            free(pixeldata);
#else
            stbi_image_free(pixeldata);
#endif
        }

#if _WIN32
        int success = wic_encode_image(v.outpath.c_str(), v.outimage.w, v.outimage.h, 3, v.outimage.data);
#else
        int success = stbi_write_png(v.outpath.c_str(), v.outimage.w, v.outimage.h, 3, v.outimage.data, 0);
#endif
        if (success)
        {
            if (verbose)
            {
#if _WIN32
                fwprintf(stderr, L"%ls -> %ls done\n", v.inpath.c_str(), v.outpath.c_str());
#else
                fprintf(stderr, "%s -> %s done\n", v.inpath.c_str(), v.outpath.c_str());
#endif
            }
        }
        else
        {
#if _WIN32
            fwprintf(stderr, L"encode image %ls failed\n", v.outpath.c_str());
#else
            fprintf(stderr, "encode image %s failed\n", v.outpath.c_str());
#endif
        }
    }

    return 0;
}

@implementation waifu2xmac

+ (NSImage *)input:(NSArray<NSString *> *)inputpaths
            output:(NSArray<NSString *> *)outputpaths
             noise:(int)noise
             scale:(int)scale
          tilesize:(int)tilesize
             model:(NSString *)model
             gpuid:(int)gpuid
      load_job_num:(int)jobs_load
      proc_job_num:(int)jobs_proc
      save_job_num:(int)jobs_save
          progress:(waifu2xProgressBlock)cb {
    NSImage * result = nil;
    int total = 9;
    
    if (inputpaths.count != outputpaths.count) {
        cb(1, total, NSLocalizedString(@"Error: inequivalent number of input / output files", @""));
    }
    
    cb(1, total, NSLocalizedString(@"Check parameters...", @""));
    if (noise < -1 || noise > 3)
    {
        cb(1, total, NSLocalizedString(@"Error: supported noise is 0, 1 or 2", @""));
        return nil;
    }

    if (scale < 1 || scale > 2)
    {
        cb(1, total, NSLocalizedString(@"Error: supported scale is 1 or 2", @""));
        return nil;
    }

    if (tilesize < 32)
    {
        cb(1, total, NSLocalizedString(@"Error: tilesize should no less than 32", @""));
        return nil;
    }
    
    if (jobs_proc <= 0)
    {
        jobs_proc = INT32_MAX;
    }
    
    if (jobs_load <= 0)
    {
        jobs_load = 1;
    }
    
    if (jobs_save <= 0)
    {
        jobs_save = 2;
    }

    cb(2, total, NSLocalizedString(@"Prepare models...", @""));
    
    int prepadding = 0;
    if ([model isEqualToString:@"models-cunet"]) {
        if (noise == -1)
        {
            prepadding = 18;
        }
        else if (scale == 1)
        {
            prepadding = 28;
        }
        else if (scale == 2)
        {
            prepadding = 18;
        }
    } else if ([model isEqualToString:@"models-upconv_7_anime_style_art_rgb"]) {
        prepadding = 7;
    } else if ([model isEqualToString:@"models-upconv_7_photo"]) {
        prepadding = 7;
    } else {
        cb(3, total, NSLocalizedString(@"[ERROR] No such model", @""));
        return nil;
    }
    
    NSString * parampath = nil;
    NSString * modelpath = nil;
    if (noise == -1)
    {
        parampath = [[NSBundle mainBundle] pathForResource:[NSString stringWithFormat:@"models/%@/scale2.0x_model.param", model] ofType:nil];
        modelpath = [[NSBundle mainBundle] pathForResource:[NSString stringWithFormat:@"models/%@/scale2.0x_model.bin", model] ofType:nil];
    }
    else if (scale == 1)
    {
        parampath = [[NSBundle mainBundle] pathForResource:[NSString stringWithFormat:@"models/%@/noise%d_model.param", model, noise] ofType:nil];
        modelpath = [[NSBundle mainBundle] pathForResource:[NSString stringWithFormat:@"models/%@/noise%d_model.bin", model, noise] ofType:nil];
    }
    else if (scale == 2)
    {
        parampath = [[NSBundle mainBundle] pathForResource:[NSString stringWithFormat:@"models/%@/noise%d_scale2.0x_model.param", model, noise] ofType:nil];
        modelpath = [[NSBundle mainBundle] pathForResource:[NSString stringWithFormat:@"models/%@/noise%d_scale2.0x_model.bin", model, noise] ofType:nil];
    }
    
    cb(3, total, NSLocalizedString(@"Creating GPU instance...", @""));
    ncnn::create_gpu_instance();
    int cpu_count = std::max(1, ncnn::get_cpu_count());
    jobs_load = std::min(jobs_load, cpu_count);
    jobs_save = std::min(jobs_save, cpu_count);
    
    int gpu_count = ncnn::get_gpu_count();
    if (gpuid < 0 || gpuid >= gpu_count)
    {
        cb(3, total, NSLocalizedString(@"[ERROR] Invalid gpu device", @""));

        ncnn::destroy_gpu_instance();
        return nil;
    }
    
    int gpu_queue_count = ncnn::get_gpu_info(gpuid).compute_queue_count;
    jobs_proc = std::min(jobs_proc, gpu_queue_count);
    
    std::vector<path_t> input_files;
    std::vector<path_t> output_files;
    
    for (NSUInteger index = 0; index < inputpaths.count; index++) {
        input_files.emplace_back([inputpaths[index] UTF8String]);
        output_files.emplace_back([outputpaths[index] UTF8String]);
    }
    
    {
        Waifu2x waifu2x(gpuid);

        cb(4, total, NSLocalizedString(@"Loading models...", @""));
        waifu2x.load([parampath UTF8String], [modelpath UTF8String]);

        waifu2x.noise = noise;
        waifu2x.scale = scale;
        waifu2x.tilesize = tilesize;
        waifu2x.prepadding = prepadding;
        
        // main routine
        {
            cb(5, total, NSLocalizedString(@"Initializing pipeline...", @""));
            
            // load image
            LoadThreadParams ltp;
            ltp.scale = scale;
            ltp.jobs_load = jobs_load;
            ltp.input_files = input_files;
            ltp.output_files = output_files;

            ncnn::Thread load_thread(load, (void*)&ltp);
            
            // waifu2x proc
            ProcThreadParams ptp;
            ptp.waifu2x = &waifu2x;

            std::vector<ncnn::Thread*> proc_threads(jobs_proc);
            for (int i=0; i<jobs_proc; i++)
            {
                proc_threads[i] = new ncnn::Thread(proc, (void*)&ptp);
            }

            // save image
            SaveThreadParams stp;
            stp.verbose = 0;
            
            std::vector<ncnn::Thread*> save_threads(jobs_save);
            for (int i=0; i<jobs_save; i++)
            {
                save_threads[i] = new ncnn::Thread(save, (void*)&stp);
            }

            // end
            load_thread.join();

            cb(6, total, NSLocalizedString(@"Done image(s) loading...", @""));
            Task end;
            end.id = -233;

            for (int i=0; i<jobs_proc; i++)
            {
                toproc.put(end);
            }

            cb(7, total, NSLocalizedString(@"Waifu2x processing...", @""));
            for (int i=0; i<jobs_proc; i++)
            {
                proc_threads[i]->join();
                delete proc_threads[i];
            }
            
            
            cb(8, total, NSLocalizedString(@"Saving image(s)...", @""));
            for (int i=0; i<jobs_save; i++)
            {
                tosave.put(end);
            }

            for (int i=0; i<jobs_save; i++)
            {
                save_threads[i]->join();
                delete save_threads[i];
            }
        }
    }
    
    ncnn::destroy_gpu_instance();
    
    cb(9, total, NSLocalizedString(@"done!", @""));
    
    if (inputpaths.count == 1) {
        result = [[NSImage alloc] initWithContentsOfFile:outputpaths[0]];
    }
    
    return result;
}

//+ (NSArray<GPUInfo *> *)AllGPUs {
//    NSMutableArray * gpus = [[NSMutableArray alloc] init];
//    ncnn::create_gpu_instance();
//    uint32_t deviceCount = ncnn::get_gpu_count();
//
//    for (uint32_t i = 0; i < deviceCount; i++) {
//        const auto& device = ncnn::get_gpu_info(i).physical_device;
//        VkPhysicalDeviceProperties deviceProperties;
//        vkGetPhysicalDeviceProperties(device, &deviceProperties);
//
//        VkPhysicalDeviceMemoryProperties deviceMemoryProperties;
//        size_t totalVRAM = 0;
//        VkPhysicalDeviceMemoryBudgetPropertiesEXT budget = {
//          .sType = VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_MEMORY_BUDGET_PROPERTIES_EXT
//        };
//
//        VkPhysicalDeviceMemoryProperties2 props = {
//          .sType = VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_MEMORY_PROPERTIES_2,
//          .pNext = &budget,
//          .memoryProperties = deviceMemoryProperties,
//        };
//        vkGetPhysicalDeviceMemoryProperties2(device, &props);
//        totalVRAM = budget.heapBudget[0];
//        
//        GPUInfo * info = [GPUInfo initWithName:[NSString stringWithFormat:@"%s", deviceProperties.deviceName] deviceID:i totalVRAM:totalVRAM];
//        [gpus addObject:info];
//    }
//
//    ncnn::destroy_gpu_instance();
//    return gpus;
//}

@end
