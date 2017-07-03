//
//  libarchive_ios.h
//  libarchive_ios
//
//  Created by Nicolas Holzschuch on 03/07/2017.
//  Copyright © 2017 Nicolas Holzschuch. All rights reserved.
//

#import <UIKit/UIKit.h>

//! Project version number for libarchive_ios.
FOUNDATION_EXPORT double libarchive_iosVersionNumber;

//! Project version string for libarchive_ios.
FOUNDATION_EXPORT const unsigned char libarchive_iosVersionString[];

// In this header, you should import all the public headers of your framework using statements like #import <libarchive_ios/PublicHeader.h>

int tar_main(int argc, char **argv);
