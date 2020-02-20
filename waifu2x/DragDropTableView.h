//
//  DragDropTableView.h
//  waifu2x-gui
//
//  Created by Cocoa on 20/02/2020.
//  Copyright © 2020 Cocoa Oikawa. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <AppKit/AppKit.h>

NS_ASSUME_NONNULL_BEGIN

@protocol DragDropTableViewDelegate;

@interface DragDropTableView : NSTableView <NSDraggingDestination>

@property (assign) BOOL allowDrop;
@property (assign) id<DragDropTableViewDelegate> dropDelegate;

- (id)initWithCoder:(NSCoder *)coder;

@end

@protocol DragDropTableViewDelegate <NSObject>

- (void)dropTableComplete:(NSArray<NSString *> *)files;

@end

NS_ASSUME_NONNULL_END
