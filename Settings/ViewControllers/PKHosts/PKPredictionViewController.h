//
//  PKPredictionViewController.h
//  settings
//
//  Created by Atul M on 11/08/16.
//  Copyright © 2016 CARLOS CABANERO. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface PKPredictionViewController : UITableViewController

- (void)performInitialSelection:(NSString *)selectedPrediction;
- (id)selectedObject;
@end
