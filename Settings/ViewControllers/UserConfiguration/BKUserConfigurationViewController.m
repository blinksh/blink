//
//  BKUserConfigurationViewController.m
//  Blink
//
//  Created by Atul M on 22/11/16.
//  Copyright © 2016 Carlos Cabañero Projects SL. All rights reserved.
//

@import CloudKit;
#import "BKUserConfigurationViewController.h"

@interface BKUserConfigurationViewController ()

@property (nonatomic, weak) IBOutlet UISwitch *toggleiCloudSync;

@end

@implementation BKUserConfigurationViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    [self setupUI];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void)setupUI{
  [_toggleiCloudSync setOn:[BKUserConfigurationViewController userSettingsValueForKey:@"iCloudSync"]];
}

#pragma mark - Action Method

- (IBAction)didToggleSwitch:(id)sender{
  UISwitch *toggleSwitch = (UISwitch*)sender;
  if(toggleSwitch == _toggleiCloudSync){
    [self checkiCloudStatusAndToggle];
  }
}

- (void)checkiCloudStatusAndToggle
{
  [[CKContainer defaultContainer] accountStatusWithCompletionHandler:
   ^(CKAccountStatus accountStatus, NSError *error) {
     if (accountStatus == CKAccountStatusNoAccount) {
       dispatch_async(dispatch_get_main_queue(), ^{
         UIAlertController *alertController = [UIAlertController alertControllerWithTitle:@"Error" message:@"Please login to your iCloud account to enable Sync" preferredStyle:UIAlertControllerStyleAlert];
         UIAlertAction *ok = [UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil];
         [alertController addAction:ok];
         [self presentViewController:alertController animated:YES completion:nil];
         [_toggleiCloudSync setOn:NO];
       });
     } else {
       [BKUserConfigurationViewController setUserSettingsValue:_toggleiCloudSync.isOn forKey:@"iCloudSync"];
     }
   }];
}

+ (void)setUserSettingsValue:(BOOL)value forKey:(NSString*)key{
  NSMutableDictionary *userSettings = [NSMutableDictionary dictionaryWithDictionary:  [[NSUserDefaults standardUserDefaults]objectForKey:@"userSettings"]];
  if(userSettings == nil){
    userSettings = [NSMutableDictionary dictionary];
  }
  [userSettings setObject:[NSNumber numberWithBool:value] forKey:key];
  [[NSUserDefaults standardUserDefaults]setObject:userSettings forKey:@"userSettings"];
}

+ (BOOL)userSettingsValueForKey:(NSString*)key{
  NSDictionary *userSettings = [[NSUserDefaults standardUserDefaults]objectForKey:@"userSettings"];
  if(userSettings != nil){
    if([userSettings objectForKey:key]){
      NSNumber *value = [userSettings objectForKey:key];
      return value.boolValue;
    }else{
      return NO;
    }
  }else{
    return NO;
  }
  return NO;
}


@end
