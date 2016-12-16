//
//  BKUserConfigurationViewController.h
//  Blink
//
//  Created by Atul M on 22/11/16.
//  Copyright © 2016 Carlos Cabañero Projects SL. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface BKUserConfigurationViewController : UITableViewController
+ (BOOL)userSettingsValueForKey:(NSString*)key;
@end
