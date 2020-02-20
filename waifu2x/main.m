//
//  main.m
//  waifu2x
//
//  Created by Cocoa on 2019/4/25.
//  Copyright © 2019-2020 Cocoa. All rights reserved.
//

#import <Cocoa/Cocoa.h>

int main(int argc, const char * argv[]) {
    setenv("VK_ICD_FILENAMES", [[NSBundle mainBundle] pathForResource:@"MoltenVK_icd" ofType:@"json"].UTF8String, 1);
    return NSApplicationMain(argc, argv);
}
