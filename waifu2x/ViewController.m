//
//  ViewController.m
//  waifu2x
//
//  Created by Cocoa Oikawa on 2019/4/25.
//  Copyright © 2019 Cocoa Oikawa. All rights reserved.
//

#import "ViewController.h"
#import "waifu2x.h"

@interface ViewController()

@property (strong) NSString * inputImagePath;

@end

@implementation ViewController

@synthesize inputImageView;
@synthesize outputImageView;
@synthesize statusLabel;
@synthesize waifu2xProgress;
@synthesize noiseParameter, scaleParameter, tilesizeParameter;

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

    [sender setEnabled:NO];
    [self.inputImageView setEditable:NO];
    [self.inputImageView setAllowsCutCopyPaste:NO];

    dispatch_async(dispatch_get_global_queue(0, 0), ^{
        NSBitmapImageRep * bitmapRep = [waifu2x input:self.inputImagePath noise:noise scale:scale tilesize:tilesize progress:^(int current, int total, NSString *description) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [self.statusLabel setStringValue:[NSString stringWithFormat:@"[%d/%d] %@", current, total, description]];
                [self.waifu2xProgress setDoubleValue:((double)current)/total * 100];
            });
        }];

        dispatch_async(dispatch_get_main_queue(), ^{
            [sender setEnabled:YES];
            [self.inputImageView setEditable:YES];
            [self.inputImageView setAllowsCutCopyPaste:YES];
            if (!bitmapRep) {
                return;
            }

            NSImage * outputImage = [[NSImage alloc] init];
            [outputImage addRepresentation:bitmapRep];
            [self.outputImageView setImage:outputImage];
        });
    });
}

@end
