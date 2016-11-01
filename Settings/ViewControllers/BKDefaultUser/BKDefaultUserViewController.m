//
//  BKDefaultUserViewController.m
//  Blink
//
//  Created by Atul M on 31/10/16.
//  Copyright © 2016 Carlos Cabañero Projects SL. All rights reserved.
//

#import "BKDefaultUserViewController.h"
#import "BKDefaults.h"
@interface BKDefaultUserViewController ()

@property (nonatomic, weak) IBOutlet UITextField *userNameField;

@end

@implementation BKDefaultUserViewController

- (void)viewDidLoad {
  [super viewDidLoad];
  self.userNameField.text = [BKDefaults defaultUserName];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return 1;
}

- (void)unwindForSegue:(UIStoryboardSegue *)unwindSegue towardsViewController:(UIViewController *)subsequentVC{
  if(self.userNameField.text != nil && ![self.userNameField.text isEqualToString:@""]){
    [BKDefaults setDefaultUserName:self.userNameField.text];
    [BKDefaults saveDefaults];
  }
}

@end
