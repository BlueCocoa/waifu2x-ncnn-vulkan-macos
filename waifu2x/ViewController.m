//
//  ViewController.m
//  waifu2x
//
//  Created by Cocoa on 2019/4/25.
//  Copyright © 2019-2020 Cocoa. All rights reserved.
//

#import "ViewController.h"
#import "waifu2xmac.h"



@interface ViewController()

@property (strong) NSString * inputImagePath;
@property (strong) NSArray<GPUInfo *> * gpus;
@end

@implementation ViewController

@synthesize inputImageView;
@synthesize outputImageView;
@synthesize statusLabel;
@synthesize waifu2xProgress;
@synthesize noiseParameter, scaleParameter, tilesizeParameter, loadingJobsParameter, processingJobsParameter, savingJobsParameter;
@synthesize gpus;

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
    gpus = [waifu2xmac AllGPUs];
    gpus = [gpus sortedArrayUsingComparator:^NSComparisonResult(GPUInfo *  _Nonnull obj1, GPUInfo *  _Nonnull obj2) {
        if (obj1.deviceID < obj2.deviceID) {
            return NSOrderedAscending;
        } else{
            return NSOrderedDescending;
        };
    }];
    for (int i = 0; i < gpus.count; i++) {
        [self.gpuIDButton addItemWithTitle:[NSString stringWithFormat:@"[%u] %@", gpus[i].deviceID, gpus[i].name]];
    }
}

- (void)dropComplete:(NSString *)filePath {
    self.inputImagePath = filePath;
}

- (IBAction)waifu2x:(NSButton *)sender {
    __block NSImage * input = inputImageView.image;
    if (!input) {
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
