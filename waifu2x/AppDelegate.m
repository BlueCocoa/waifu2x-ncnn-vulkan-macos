//
//  AppDelegate.m
//  waifu2x
//
//  Created by Cocoa on 2019/4/25.
//  Copyright © 2019-2020 Cocoa. All rights reserved.
//

#import "AppDelegate.h"
#ifndef NCNN_REV
#define NCNN_REV "unknown"
#endif
#ifndef WAIFU2X_NCNN_VULKAN_GIT_REV
#define WAIFU2X_NCNN_VULKAN_GIT_REV "unknown"
#endif

@interface AppDelegate ()

@end

@implementation AppDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)notification {
    [self.ncnn_git_rev setTitle:[NSString stringWithFormat:@"ncnn: %s", NCNN_REV]];
    [self.waifu2x_git_rev setTitle:[NSString stringWithFormat:@"waifu2x: %s", WAIFU2X_NCNN_VULKAN_GIT_REV]];
    self.ncnn_git_rev.enabled = NO;
    self.waifu2x_git_rev.enabled = NO;
}

- (BOOL)applicationShouldHandleReopen:(NSApplication *)sender hasVisibleWindows:(BOOL)flag {
    if (!flag) {
        for (id window in sender.windows) {
            [window makeKeyAndOrderFront:self];
        }
    }
    return YES;
}

- (IBAction)benchmark:(id)sender {
    [self.viewController performSelector:@selector(benchmark)];
}

@end
