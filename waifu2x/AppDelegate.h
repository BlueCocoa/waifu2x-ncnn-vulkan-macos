//
//  AppDelegate.h
//  waifu2x
//
//  Created by Cocoa on 2019/4/25.
//  Copyright © 2019-2020 Cocoa. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "library-info.h"

@interface AppDelegate : NSWindowController <NSApplicationDelegate>

@property (assign) id viewController;
@property (weak) IBOutlet NSMenuItem *ncnn_git_rev;
@property (weak) IBOutlet NSMenuItem *waifu2x_git_rev;

- (IBAction)benchmark:(id)sender;

@end

