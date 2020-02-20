//
//  AppDelegate.h
//  waifu2x
//
//  Created by Cocoa on 2019/4/25.
//  Copyright © 2019-2020 Cocoa. All rights reserved.
//

#import <Cocoa/Cocoa.h>


@interface AppDelegate : NSWindowController <NSApplicationDelegate>

@property (assign) id viewController;
- (IBAction)benchmark:(id)sender;

@end

