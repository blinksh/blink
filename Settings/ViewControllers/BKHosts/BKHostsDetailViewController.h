//
//  HostsDetailViewController.h
//  Blink
//
//  Created by CARLOS CABANERO on 01/07/16.
//  Copyright © 2016 Carlos Cabañero Projects SL. All rights reserved.
//

#import <UIKit/UIKit.h>
@class BKHosts;
@interface BKHostsDetailViewController : UITableViewController

@property (weak, nonatomic) BKHosts *bkHost;
@property (assign, nonatomic) BOOL isExistingHost;
@end
