//
//  DragDropTableView.m
//  waifu2x-gui
//
//  Created by Cocoa on 20/02/2020.
//  Copyright © 2020 Cocoa Oikawa. All rights reserved.
//

#import "DragDropTableView.h"

@implementation DragDropTableView

@synthesize dropDelegate;

- (id)initWithCoder:(NSCoder *)coder {
    self = [super initWithCoder:coder];
    if ( self ) {
        self.allowDrop = YES;
        [self registerForDraggedTypes:[NSArray arrayWithObject:(NSString *)kUTTypeFileURL]];
    }
    return self;
}

- (NSDragOperation)draggingEntered:(id<NSDraggingInfo>)sender {
    if (!self.allowDrop) {
        return NSDragOperationNone;
    }
    
    return NSDragOperationCopy;
}

- (BOOL)performDragOperation:(id <NSDraggingInfo>)sender {
    NSArray* urls = nil;
    if (self.acceptedTypes) {
        urls = [sender.draggingPasteboard
                         readObjectsForClasses:[NSArray arrayWithObject:[NSURL class]]
                         options:[NSDictionary dictionaryWithObjectsAndKeys:
                                  [NSNumber numberWithBool:YES], NSPasteboardURLReadingFileURLsOnlyKey,
                                  self.acceptedTypes, NSPasteboardURLReadingContentsConformToTypesKey, nil]
                         ];
    } else {
        urls = [sender.draggingPasteboard
                readObjectsForClasses:[NSArray arrayWithObject:[NSURL class]]
                options:nil];
    }
    
    NSMutableArray * files = [[NSMutableArray alloc] init];
    for (NSURL * fileurl in urls) {
        BOOL isDirectory;
        NSString * filepath = fileurl.filePathURL.path;
        if ([[NSFileManager defaultManager] fileExistsAtPath:filepath isDirectory:&isDirectory]) {
            if (isDirectory) {
                NSDirectoryEnumerator<NSString *> * enumerator = [[NSFileManager defaultManager] enumeratorAtPath:filepath];
                [enumerator skipDescendants];
                for (NSString * file in enumerator) {
                    NSString * path = [NSString stringWithFormat:@"%@/%@", filepath, file];
                    BOOL isDirectory;
                    if ([[NSFileManager defaultManager] fileExistsAtPath:path isDirectory:&isDirectory]) {
                        if (!isDirectory) {
                            [files addObject:path];
                        }
                    }
                }
            } else {
                [files addObject:filepath];
            }
        }
    }
    
    if ([self.dropDelegate respondsToSelector:@selector(dropTable:Complete:)]) {
        [self.dropDelegate dropTable:self Complete:files];
    }
    
    return YES;
}

@end
