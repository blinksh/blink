//
//  BKPubKeyQRScanViewController.h
//  Blink
//
//  Created by Roman Belyakovsky on 03/04/2017.
//  Copyright © 2017 Carlos Cabañero Projects SL. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <AVFoundation/AVFoundation.h>

@protocol importKeyProtocol <NSObject>

- (void)importKey:(NSString *)pbkey;

@end

@interface BKPubKeyQRScanViewController : UIViewController

@property(nonatomic,assign)id delegate;

@property (weak, nonatomic) IBOutlet UIView *videoView;

@end
