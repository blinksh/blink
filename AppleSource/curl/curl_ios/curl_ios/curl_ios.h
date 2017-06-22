//
//  curl_ios.h
//  curl_ios
//
//  Created by Nicolas Holzschuch on 16/06/2017.
//  Copyright © 2017 Nicolas Holzschuch. All rights reserved.
//

#import <UIKit/UIKit.h>

//! Project version number for curl_ios.
FOUNDATION_EXPORT double curl_iosVersionNumber;

//! Project version string for curl_ios.
FOUNDATION_EXPORT const unsigned char curl_iosVersionString[];

// In this header, you should import all the public headers of your framework using statements like #import <curl_ios/PublicHeader.h>

// Only one command
extern int curl_main(int argc, char *argv[]);
