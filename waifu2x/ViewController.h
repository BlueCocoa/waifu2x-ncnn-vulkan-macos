//
//  ViewController.h
//  waifu2x
//
//  Created by Cocoa on 2019/4/25.
//  Copyright © 2019-2020 Cocoa. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "AppDelegate.h"
#import "DragDropImageView.h"
#import "DragDropTableView.h"

@interface ViewController : NSViewController<DragDropImageViewDelegate, DragDropTableViewDelegate, NSTableViewDelegate, NSTableViewDataSource, NSTabViewDelegate>

- (IBAction)waifu2x:(id)sender;
- (void)benchmark;

@property (weak) IBOutlet DragDropImageView *inputImageView;
@property (weak) IBOutlet DragDropImageView *outputImageView;
@property (weak) IBOutlet NSTextField *statusLabel;
@property (weak) IBOutlet NSProgressIndicator *waifu2xProgress;
@property (weak) IBOutlet NSTextField *noiseParameter;
@property (weak) IBOutlet NSTextField *scaleParameter;
@property (weak) IBOutlet NSTextField *tilesizeParameter;
@property (weak) IBOutlet NSTextField *loadingJobsParameter;
@property (weak) IBOutlet NSTextField *processingJobsParameter;
@property (weak) IBOutlet NSTextField *savingJobsParameter;
@property (weak) IBOutlet NSPopUpButton *gpuIDButton;
@property (weak) IBOutlet NSPopUpButton *modelButton;
@property (weak) IBOutlet NSTextField *vramStaticticsLabel;
@property (weak) IBOutlet NSTabView *processingModeTab;
@property (weak) IBOutlet DragDropTableView *multipleImageTableView;
@property (weak) IBOutlet NSButton *startButton;

@end

