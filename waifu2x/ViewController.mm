//
//  ViewController.m
//  waifu2x
//
//  Created by Cocoa on 2019/4/25.
//  Copyright © 2019-2020 Cocoa. All rights reserved.
//

#import "ViewController.h"
#import "waifu2xmac.h"
#import "GPUInfo.h"
#import <vector>
#import "gpu.h"

@interface ViewController() {
    VkInstance gpuInstance;
}

@property (strong) NSString * inputImagePath;
@property (strong) NSArray<GPUInfo *> * gpus;
@property (nonatomic) uint32_t currentGPUID;
@property (strong, nonatomic) NSTimer * vramStaticticsTimer;

@end

@implementation ViewController

@synthesize inputImageView;
@synthesize outputImageView;
@synthesize statusLabel;
@synthesize waifu2xProgress;
@synthesize noiseParameter, scaleParameter, tilesizeParameter, loadingJobsParameter, processingJobsParameter, savingJobsParameter;
@synthesize gpus;
@synthesize vramStaticticsLabel;

- (void)viewDidLoad {
    [super viewDidLoad];
    [self.statusLabel setStringValue:NSLocalizedString(@"Idle", @"")];
    [self.waifu2xProgress setMinValue:0.0];
    [self.waifu2xProgress setMaxValue:100.0];

    [self.inputImageView setAllowDrop:YES];
    [self.inputImageView setImageScaling:NSImageScaleProportionallyUpOrDown];
    [self.inputImageView setDelegate:self];
    
    [self.outputImageView setAllowDrag:YES];
    [self.outputImageView setImageScaling:NSImageScaleProportionallyUpOrDown];
    
    [self.modelButton removeAllItems];
    [self.modelButton addItemWithTitle:@"cunet"];
    [self.modelButton addItemWithTitle:@"upconv_7_anime_style_art_rgb"];
    [self.modelButton addItemWithTitle:@"upconv_7_photo"];
    
    [self.gpuIDButton removeAllItems];
    if (![self createGPUInstance]) {
        [self.statusLabel setStringValue:@"Error: cannot create GPU instance with Vulkan"];
    }
}

- (void)changeGPU:(NSPopUpButton *)sender {
    self.currentGPUID = (uint32_t)[self.gpuIDButton indexOfSelectedItem];
}

- (BOOL)createGPUInstance {
    // copied from Tencent/ncnn/gpu.cpp with minor changes
    // https://github.com/Tencent/ncnn/blob/master/src/gpu.cpp
    VkResult ret;

    std::vector<const char*> enabledLayers;
    std::vector<const char*> enabledExtensions;
    
    uint32_t instanceExtensionPropertyCount;
    ret = vkEnumerateInstanceExtensionProperties(NULL, &instanceExtensionPropertyCount, NULL);
    if (ret != VK_SUCCESS) {
        fprintf(stderr, "vkEnumerateInstanceExtensionProperties failed %d\n", ret);
        return NO;
    }

    std::vector<VkExtensionProperties> instanceExtensionProperties(instanceExtensionPropertyCount);
    ret = vkEnumerateInstanceExtensionProperties(NULL, &instanceExtensionPropertyCount, instanceExtensionProperties.data());
    if (ret != VK_SUCCESS) {
        fprintf(stderr, "vkEnumerateInstanceExtensionProperties failed %d\n", ret);
        return NO;
    }

    static int support_VK_KHR_get_physical_device_properties2 = 0;
    for (uint32_t j=0; j<instanceExtensionPropertyCount; j++) {
        const VkExtensionProperties& exp = instanceExtensionProperties[j];
        if (strcmp(exp.extensionName, "VK_KHR_get_physical_device_properties2") == 0) {
            support_VK_KHR_get_physical_device_properties2 = exp.specVersion;
        }
    }
    if (support_VK_KHR_get_physical_device_properties2) {
        enabledExtensions.push_back("VK_KHR_get_physical_device_properties2");
    }
        
    VkApplicationInfo applicationInfo;
    applicationInfo.sType = VK_STRUCTURE_TYPE_APPLICATION_INFO;
    applicationInfo.pNext = 0;
    applicationInfo.pApplicationName = "Image Super Resolution macOS";
    applicationInfo.applicationVersion = 0;
    applicationInfo.pEngineName = "isrmacos";
    applicationInfo.engineVersion = 20200220;
    applicationInfo.apiVersion = VK_MAKE_VERSION(1, 0, 0);

    VkInstanceCreateInfo instanceCreateInfo;
    instanceCreateInfo.sType = VK_STRUCTURE_TYPE_INSTANCE_CREATE_INFO;
    instanceCreateInfo.pNext = 0;
    instanceCreateInfo.flags = 0;
    instanceCreateInfo.pApplicationInfo = &applicationInfo;
    instanceCreateInfo.enabledLayerCount = (uint32_t)enabledLayers.size();
    instanceCreateInfo.ppEnabledLayerNames = enabledLayers.data();
    instanceCreateInfo.enabledExtensionCount = (uint32_t)enabledExtensions.size();
    instanceCreateInfo.ppEnabledExtensionNames = enabledExtensions.data();

    ret = vkCreateInstance(&instanceCreateInfo, 0, &self->gpuInstance);
    if (ret != VK_SUCCESS) {
        fprintf(stderr, "vkCreateInstance failed %d\n", ret);
        return NO;
    }
    
    uint32_t physicalDeviceCount = 0;
    ret = vkEnumeratePhysicalDevices(self->gpuInstance, &physicalDeviceCount, 0);
    if (ret != VK_SUCCESS) {
        fprintf(stderr, "vkEnumeratePhysicalDevices failed %d\n", ret);
    }
    
    std::vector<VkPhysicalDevice> physicalDevices(physicalDeviceCount);
    ret = vkEnumeratePhysicalDevices(self->gpuInstance, &physicalDeviceCount, physicalDevices.data());
    if (ret != VK_SUCCESS) {
        fprintf(stderr, "vkEnumeratePhysicalDevices failed %d\n", ret);
    }
    
    NSMutableArray<GPUInfo *> * gpus = [NSMutableArray arrayWithCapacity:physicalDeviceCount];
    for (uint32_t i=0; i<physicalDeviceCount; i++) {
        const VkPhysicalDevice& physicalDevice = physicalDevices[i];
        VkPhysicalDeviceProperties physicalDeviceProperties;
        vkGetPhysicalDeviceProperties(physicalDevice, &physicalDeviceProperties);
        
        GPUInfo * info = [GPUInfo initWithName:[NSString stringWithFormat:@"%s", physicalDeviceProperties.deviceName] deviceID:i physicalDevice:physicalDevice];
        [gpus addObject:info];
    }
    
    self.gpus = [gpus sortedArrayUsingComparator:^NSComparisonResult(GPUInfo *  _Nonnull obj1, GPUInfo *  _Nonnull obj2) {
        if (obj1.deviceID < obj2.deviceID) {
            return NSOrderedAscending;
        } else{
            return NSOrderedDescending;
        };
    }];
    for (int i = 0; i < self.gpus.count; i++) {
        [self.gpuIDButton addItemWithTitle:[NSString stringWithFormat:@"[%u] %@", self.gpus[i].deviceID, self.gpus[i].name]];
    }
    [self.gpuIDButton setAction:@selector(changeGPU:)];
    self.currentGPUID = 0;
    
    self.vramStaticticsTimer = [NSTimer scheduledTimerWithTimeInterval:1.0 target:self selector:@selector(updateCurrentGPUVRAMStatictics) userInfo:nil repeats:YES];
    [self.vramStaticticsTimer setFireDate:[NSDate date]];
    [self.vramStaticticsTimer fire];
    
    return YES;
}

- (void)updateCurrentGPUVRAMStatictics {
    const auto& device = self.gpus[self.currentGPUID].physicalDevice;
    VkPhysicalDeviceProperties deviceProperties;
    vkGetPhysicalDeviceProperties(device, &deviceProperties);
    
    VkPhysicalDeviceMemoryProperties deviceMemoryProperties;
    VkPhysicalDeviceMemoryBudgetPropertiesEXT budget = {
      .sType = VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_MEMORY_BUDGET_PROPERTIES_EXT
    };

    VkPhysicalDeviceMemoryProperties2 props = {
      .sType = VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_MEMORY_PROPERTIES_2,
      .pNext = &budget,
      .memoryProperties = deviceMemoryProperties,
    };
    vkGetPhysicalDeviceMemoryProperties2(device, &props);
    
    double total = budget.heapBudget[0];
    double used = budget.heapUsage[0];
    
    total /= 1024.0 * 1024.0;
    used /= 1024.0 * 1024.0;
    
    [self.vramStaticticsLabel.cell setTitle:[NSString stringWithFormat:@"%.0lf/%0.lfMB", used, total]];
}

- (void)dropComplete:(NSString *)filePath {
    self.inputImagePath = filePath;
}

- (IBAction)waifu2x:(NSButton *)sender {
    if (!self.inputImageView.image) {
        return;
    }

    int noise = self.noiseParameter.intValue;
    int scale = self.scaleParameter.intValue;
    int tilesize = self.tilesizeParameter.intValue;
    int load_jobs = self.loadingJobsParameter.intValue;
    int proc_jobs = self.processingJobsParameter.intValue;
    int save_jobs = self.savingJobsParameter.intValue;

    [sender setEnabled:NO];
    [self.inputImageView setEditable:NO];
    [self.inputImageView setAllowsCutCopyPaste:NO];

    NSString * model = [NSString stringWithFormat:@"models-%@", [self.modelButton selectedItem].title];
    int gpuID = self.gpus[self.gpuIDButton.indexOfSelectedItem].deviceID;
    
    dispatch_async(dispatch_get_global_queue(0, 0), ^{
        NSImage * result = [waifu2xmac input:self.inputImagePath
                                                   noise:noise
                                                   scale:scale
                                                tilesize:tilesize
                                                   model:model
                                                   gpuid:gpuID
                                            load_job_num:load_jobs
                                            proc_job_num:proc_jobs
                                            save_job_num:save_jobs
                                                progress:^(int current, int total, NSString *description) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [self.statusLabel setStringValue:[NSString stringWithFormat:@"[%d/%d] %@", current, total, description]];
                [self.waifu2xProgress setDoubleValue:((double)current)/total * 100];
            });
        }];

        dispatch_async(dispatch_get_main_queue(), ^{
            [sender setEnabled:YES];
            [self.inputImageView setEditable:YES];
            [self.inputImageView setAllowsCutCopyPaste:YES];
            if (!result) {
                return;
            }

            [self.outputImageView setImage:result];
        });
    });
}

@end
