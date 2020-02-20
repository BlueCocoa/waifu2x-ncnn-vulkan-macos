//
//  ViewController.m
//  waifu2x
//
//  Created by Cocoa on 2019/4/25.
//  Copyright © 2019-2020 Cocoa. All rights reserved.
//

#import "ViewController.h"
#import <vector>
#import <unistd.h>
#import <chrono>
#import "waifu2xmac.h"
#import "GPUInfo.h"
#import "gpu.h"

@interface ViewController() {
    VkInstance gpuInstance;
}

@property (strong) NSString * inputImagePath;
@property (strong) NSArray<GPUInfo *> * gpus;
@property (nonatomic) uint32_t currentGPUID;
@property (strong, nonatomic) NSTimer * vramStaticticsTimer;
@property (strong, nonatomic) NSMutableArray * inputImageFiles;
@property (atomic) BOOL isProcessing;
@property (nonatomic) BOOL isBenchmarking;

@end

@implementation ViewController

@synthesize inputImageView;
@synthesize outputImageView;
@synthesize statusLabel;
@synthesize waifu2xProgress;
@synthesize noiseParameter, scaleParameter, tilesizeParameter, loadingJobsParameter, processingJobsParameter, savingJobsParameter;
@synthesize gpus;
@synthesize vramStaticticsLabel;
@synthesize processingModeTab;
@synthesize multipleImageTableView;

- (void)viewDidLoad {
    [super viewDidLoad];
    ((AppDelegate *)[NSApp delegate]).viewController = self;
    
    [self.statusLabel setStringValue:NSLocalizedString(@"Idle", @"")];
    [self.waifu2xProgress setMinValue:0.0];
    [self.waifu2xProgress setMaxValue:100.0];

    [self.inputImageView setAllowDrop:YES];
    [self.inputImageView setAllowDrag:NO];
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
    
    self.inputImageFiles = [[NSMutableArray alloc] init];
    
    [self.multipleImageTableView setDataSource:self];
    [self.multipleImageTableView setDelegate:self];
    [self.multipleImageTableView setAllowDrop:YES];
    [self.multipleImageTableView setDropDelegate:self];
    
    [self.processingModeTab setDelegate:self];
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
    
    [self updateVRAMStaticticsWithTimeInterval:1.0];
    [self.vramStaticticsLabel setToolTip:@"VRAM usage / total"];
    
    return YES;
}

- (void)updateVRAMStaticticsWithTimeInterval:(NSTimeInterval)interval {
    if (self.vramStaticticsTimer) {
        [self.vramStaticticsTimer setFireDate:[NSDate distantFuture]];
        [self.vramStaticticsTimer invalidate];
        self.vramStaticticsTimer = nil;
    }
    self.vramStaticticsTimer = [NSTimer scheduledTimerWithTimeInterval:interval target:self selector:@selector(updateCurrentGPUVRAMStatictics) userInfo:nil repeats:YES];
    [self.vramStaticticsTimer setFireDate:[NSDate date]];
    [self.vramStaticticsTimer fire];
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
    [self.vramStaticticsLabel.cell setTitle:[NSString stringWithFormat:@"%.0lf/%0.lf MB", used, total]];
}

- (NSArray *)generateOutputPaths:(NSArray *)inputpaths {
    NSMutableArray * outputpaths = [NSMutableArray arrayWithCapacity:inputpaths.count];;
    for (NSString * filepath in inputpaths) {
        [outputpaths addObject:[filepath stringByAppendingPathExtension:@"png"]];
    }
    return outputpaths;
}

- (void)benchmark {
    __block NSMutableArray * result = [[NSMutableArray alloc] init];
    
    int noise = 2;
    int scale = 2;
    int gpuID = self.gpus[self.gpuIDButton.indexOfSelectedItem].deviceID;
    NSArray * models = @[@"models-cunet", @"models-upconv_7_anime_style_art_rgb"];
    NSArray<NSNumber *> * tilesizes = @[@(400), @(200), @(100)];
    NSArray<NSNumber *> * inputSizes = @[@(200), @(400), @(1000), @(2000), @(4000)];
    NSArray * outputfiles = @[@"/tmp/waifu2x-macos-benchmark.png"];
    
    self.isProcessing = YES;
    self.isBenchmarking = YES;
    [self allowUserIntereaction:NO];
    
    dispatch_async(dispatch_get_global_queue(0, 0), ^{
        [result addObject:@"|Model|Image Size|Target Size|Block Size|Total Time(sec)|GPU Memory(MB)|"];
        [result addObject:@"|---|---|---|---|---|---|"];
        for (NSString * model in models) {
            for (NSNumber * inputSize in inputSizes) {
                int imageSize = inputSize.intValue;
                int targetSize = imageSize * scale;
                NSString * inputfile = [[NSBundle mainBundle] pathForResource:[[NSString alloc] initWithFormat:@"benchmark/%dx%d", imageSize, imageSize] ofType:@"png"];
                if (inputfile == nil) { continue; }
                
                NSMutableArray<NSMutableArray<NSNumber *> *> * tilesResult = [[NSMutableArray alloc] initWithCapacity:tilesizes.count];
                for (NSNumber * tilesize in tilesizes) {
                    NSMutableArray<NSNumber *> * tileResult = [[NSMutableArray alloc] initWithCapacity:2];
                    int tsize = [tilesize intValue];
                    dispatch_sync(dispatch_get_main_queue(), ^{
                        [self.statusLabel setStringValue:[[NSString alloc] initWithFormat:@"Benchmark - %@ - (%dx%d)@%d", model, imageSize, imageSize, tsize]];
                    });
                    
                    double usage = 0;
                    std::chrono::steady_clock::time_point begin = std::chrono::steady_clock::now();
                    
                    [waifu2xmac input:@[inputfile]
                               output:outputfiles
                                noise:noise
                                scale:scale
                             tilesize:tsize
                                model:model
                                gpuid:gpuID
                         load_job_num:1
                         proc_job_num:1
                         save_job_num:1
                          single_mode:NO
                            VRAMUsage:&usage
                             progress:nil];
                    
                    std::chrono::steady_clock::time_point end = std::chrono::steady_clock::now();
                    
                    dispatch_sync(dispatch_get_main_queue(), ^{
                        double elapsed_time = std::chrono::duration_cast<std::chrono::milliseconds>(end - begin).count() / 1000.0;
                        [tileResult addObject:@(elapsed_time)];
                        [tileResult addObject:@(usage)];
                        [tilesResult addObject:tileResult];
                    });
                }
                
                NSMutableString * totalTime = [[NSMutableString alloc] init];
                NSMutableString * memoryUsage = [[NSMutableString alloc] init];
                NSMutableString * tilesizeDesc = [[NSMutableString alloc] init];
                for (NSUInteger index = 0; index < tilesizes.count; index++) {
                    NSMutableArray<NSNumber *> * tileResult = tilesResult[index];
                    [tilesizeDesc appendFormat:@"%d/", tilesizes[index].intValue];
                    [totalTime appendFormat:@"%.2lf/", tileResult[0].doubleValue];
                    [memoryUsage appendFormat:@"%.0lf/", tileResult[1].doubleValue];
                }
                [result addObject:[[NSString alloc] initWithFormat:@"|%@|%dx%d|%dx%d|%@|%@|%@|",
                                   model,
                                   imageSize, imageSize,
                                   targetSize, targetSize,
                                   [tilesizeDesc substringToIndex:tilesizeDesc.length - 1],
                                   [totalTime substringToIndex:totalTime.length - 1],
                                   [memoryUsage substringToIndex:memoryUsage.length - 1]]];
            }
        }
        
        dispatch_sync(dispatch_get_main_queue(), ^{
            [self.statusLabel setStringValue:NSLocalizedString(@"Idle", @"")];
            [self allowUserIntereaction:YES];
            self.isProcessing = NO;
            self.isBenchmarking = NO;
            
            NSAlert *alert = [[NSAlert alloc] init];
            [alert addButtonWithTitle:@"Copy"];
            [alert addButtonWithTitle:@"Cancel"];
            [alert setMessageText:@"Benchmark Result"];
            NSMutableString * resultString = [[NSMutableString alloc] init];
            for (NSString * p in result) {
                [resultString appendFormat:@"%@\n", p];
            }
            [alert setInformativeText:resultString];
            [alert setAlertStyle:NSAlertStyleInformational];
            [alert beginSheetModalForWindow:[self view].window completionHandler:^(NSModalResponse returnCode) {
                if (returnCode == 1000) {
                    [[NSPasteboard generalPasteboard] clearContents];
                    [[NSPasteboard generalPasteboard] setString:resultString forType:NSStringPboardType];
                }
            }];
        });
    });
}

- (void)allowUserIntereaction:(BOOL)enabled {
    if ([self.processingModeTab indexOfTabViewItem:[self.processingModeTab selectedTabViewItem]] == 1) {
        [self.multipleImageTableView setAllowDrop:enabled];
    } else {
        [self.inputImageView setAllowDrop:enabled];
        [self.inputImageView setEditable:enabled];
        [self.inputImageView setAllowsCutCopyPaste:enabled];
        [self.outputImageView setAllowDrag:enabled];
        [self.outputImageView setEditable:enabled];
        [self.outputImageView setAllowsCutCopyPaste:enabled];
    }
    [self.startButton setEnabled:enabled];
}

- (IBAction)waifu2x:(NSButton *)sender {
    int noise = self.noiseParameter.intValue;
    int scale = self.scaleParameter.intValue;
    int tilesize = self.tilesizeParameter.intValue;
    int load_jobs = self.loadingJobsParameter.intValue;
    int proc_jobs = self.processingJobsParameter.intValue;
    int save_jobs = self.savingJobsParameter.intValue;
    NSString * model = [NSString stringWithFormat:@"models-%@", [self.modelButton selectedItem].title];
    int gpuID = self.gpus[self.gpuIDButton.indexOfSelectedItem].deviceID;
    BOOL isSingleMode = true;
    
    NSArray<NSString *> * inputpaths = nil;
    NSArray<NSString *> * outputpaths = nil;
    if ([self.processingModeTab indexOfTabViewItem:[self.processingModeTab selectedTabViewItem]] == 1) {
        if (self.inputImageFiles.count == 0) {
            return;
        }
        
        inputpaths = self.inputImageFiles;
        outputpaths = [self generateOutputPaths:self.inputImageFiles];
        isSingleMode = false;
    } else {
        if (!self.inputImageView.image) {
            return;
        }
        
        char tmp_filename_buf[32] = {'\0'};
        const char * template_filename = "/tmp/isrm-XXXXXX";
        strncpy(tmp_filename_buf, template_filename, strlen(template_filename));
        int err = mkstemp(tmp_filename_buf);
        if (err < 1) {
            [self.statusLabel setStringValue:[NSString stringWithFormat:@"Error: cannot create tmp file: %s", strerror(errno)]];
            return;
        }
        outputpaths = @[[NSString stringWithFormat:@"%s.png", tmp_filename_buf]];
        inputpaths = @[self.inputImagePath];
    }
    
    [self allowUserIntereaction:NO];
    self.isProcessing = YES;
    
    dispatch_async(dispatch_get_global_queue(0, 0), ^{
        NSImage * result = [waifu2xmac input:inputpaths
                                      output:outputpaths
                                       noise:noise
                                       scale:scale
                                    tilesize:tilesize
                                       model:model
                                       gpuid:gpuID
                                load_job_num:load_jobs
                                proc_job_num:proc_jobs
                                save_job_num:save_jobs
                                 single_mode:isSingleMode
                                   VRAMUsage:nullptr
                                    progress:^(int current, int total, NSString *description) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [self.statusLabel setStringValue:[NSString stringWithFormat:@"[%d/%d] %@", current, total, description]];
                [self.waifu2xProgress setDoubleValue:((double)current)/total * 100];
            });
        }];

        self.isProcessing = NO;
        [self allowUserIntereaction:YES];
        
        if (isSingleMode) {
            dispatch_async(dispatch_get_main_queue(), ^{
                if (!result) {
                    return;
                }

                [self.outputImageView setImage:result];
                unlink(outputpaths[0].UTF8String);
            });
        }
    });
}

#pragma mark - DragDropImageViewDelegate

- (void)dropComplete:(NSString *)filePath {
    self.inputImagePath = filePath;
}

#pragma mark - DragDropTableViewDelegate

- (void)dropTableComplete:(NSArray<NSString *> *)files {
    [self.inputImageFiles addObjectsFromArray:files];
    [self.multipleImageTableView reloadData];
}

#pragma mark - NSTableViewDataSource

- (NSInteger)numberOfRowsInTableView:(NSTableView *)tableView {
    if (tableView == self.multipleImageTableView) {
        return self.inputImageFiles.count;
    } else {
        return 0;
    }
}

#pragma mark - NSTableViewDelegate

- (nullable NSView *)tableView:(NSTableView *)tableView viewForTableColumn:(nullable NSTableColumn *)tableColumn row:(NSInteger)row {
    if (tableView == self.multipleImageTableView) {
        NSTableCellView * cell = [tableView makeViewWithIdentifier:tableColumn.identifier owner:self];
        [cell.textField setStringValue:[self.inputImageFiles objectAtIndex:row]];
        return cell;
    } else {
        return nil;
    }
}

- (BOOL)tableView:(NSTableView *)tableView acceptDrop:(id<NSDraggingInfo>)info row:(NSInteger)row dropOperation:(NSTableViewDropOperation)dropOperation {
    return YES;
}

- (NSDragOperation)tableView:(NSTableView *)tableView validateDrop:(id<NSDraggingInfo>)info proposedRow:(NSInteger)row proposedDropOperation:(NSTableViewDropOperation)dropOperation {
    return NSDragOperationCopy;
}

#pragma mark - NSTabViewDelegate

- (BOOL)tabView:(NSTabView *)tabView shouldSelectTabViewItem:(nullable NSTabViewItem *)tabViewItem {
    return !self.isProcessing;
}

- (IBAction)delete:(id)sender {
    if ([self.processingModeTab indexOfTabViewItem:[self.processingModeTab selectedTabViewItem]] == 1) {
        NSIndexSet * selectedSet = [self.multipleImageTableView selectedRowIndexes];
        if (selectedSet.count > 0) {
            [self.inputImageFiles removeObjectsAtIndexes:selectedSet];
            [self.multipleImageTableView reloadData];
            if (selectedSet.count == 1) {
                [self.multipleImageTableView selectRowIndexes:[NSIndexSet indexSetWithIndex:selectedSet.firstIndex] byExtendingSelection:NO];
            }
        } else {
            NSBeep();
        }
    }
}

@end
