//
//  BKPubKeyQRScanViewController.m
//  Blink
//
//  Created by Roman Belyakovsky on 03/04/2017.
//  Copyright © 2017 Carlos Cabañero Projects SL. All rights reserved.
//

#import "BKPubKeyQRScanViewController.h"

@interface BKPubKeyQRScanViewController ()

@end

@implementation BKPubKeyQRScanViewController

@synthesize delegate;

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

/*
#pragma mark - Navigation

// In a storyboard-based application, you will often want to do a little preparation before navigation
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    // Get the new view controller using [segue destinationViewController].
    // Pass the selected object to the new view controller.
}
*/

- (IBAction)cancelQRScan:(id)sender {
  [self dismissViewControllerAnimated:YES completion:nil];
  [delegate importKey:@"test"];
}

@end
