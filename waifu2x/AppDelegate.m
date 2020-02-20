//
//  AppDelegate.m
//  waifu2x
//
//  Created by Cocoa on 2019/4/25.
//  Copyright © 2019-2020 Cocoa. All rights reserved.
//

#import "AppDelegate.h"

@interface AppDelegate ()

@end

@implementation AppDelegate

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
