////////////////////////////////////////////////////////////////////////////////
//
// B L I N K
//
// Copyright (C) 2016 Blink Mobile Shell Project
//
// This file is part of Blink.
//
// Blink is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// Blink is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License
// along with Blink. If not, see <http://www.gnu.org/licenses/>.
//
// In addition, Blink is also subject to certain additional terms under
// GNU GPL version 3 section 7.
//
// You should have received a copy of these additional terms immediately
// following the terms and conditions of the GNU General Public License
// which accompanied the Blink Source Code. If not, see
// <http://www.github.com/blinksh/blink>.
//
////////////////////////////////////////////////////////////////////////////////


#import "BKKeyboardShortcutsViewController.h"
#import "BKDefaults.h"
#import "BKKeyboardFuncTriggersViewController.h"
#import "BKKeyboardViewController.h"

@interface BKKeyboardShortcutsViewController ()
@property (nonatomic, strong) NSDictionary *currentlyAvailableShortCuts;
@end

@implementation BKKeyboardShortcutsViewController

- (void)viewDidLoad
{
  [super viewDidLoad];
  [self loadData];
  // Uncomment the following line to preserve selection between presentations.
  // self.clearsSelectionOnViewWillAppear = NO;

  // Uncomment the following line to display an Edit button in the navigation bar for this view controller.
  // self.navigationItem.rightBarButtonItem = self.editButtonItem;
}

- (void)loadData
{
  _currentlyAvailableShortCuts = @{ @"New Shell" : @"Key + T",
                                    @"Close Shell" : @"Key + W",
                                    @"Next Shell" : @"Key + ]",
                                    @"Previous Shell" : @"Key + [",
                                    @"Other Screen" : @"Key + O",
                                    @"Show Config" : @"Key + ," };
}

- (void)didReceiveMemoryWarning
{
  [super didReceiveMemoryWarning];
  // Dispose of any resources that can be recreated.
}

- (void)viewWillDisappear:(BOOL)animated
{
  if ([self.navigationController.viewControllers indexOfObject:self] == NSNotFound) {
    if (_selectedObjects && _selectedObjects.count > 0) {
      [self performSegueWithIdentifier:@"unwindFromKeyboardFuncTriggers" sender:self];
    }
  }
  [super viewWillDisappear:animated];
}

#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
  return 2;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
  if (section == 0) {
    return 1;
  } else {
    return self.currentlyAvailableShortCuts.count;
  }
}


- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
  UITableViewCell *cell;
  if (indexPath.section == 0) {
    cell = [tableView dequeueReusableCellWithIdentifier:@"shortcutSelectionCell" forIndexPath:indexPath];
    cell.textLabel.text = (NSString *)BKKeyboardFuncShortcutTriggers;
    cell.detailTextLabel.text = [self detailForKeyboardFunc:BKKeyboardFuncShortcutTriggers];
  } else if (indexPath.section == 1) {
    cell = [tableView dequeueReusableCellWithIdentifier:@"shortcutsDisplayCell" forIndexPath:indexPath];

    cell.textLabel.text = [_currentlyAvailableShortCuts allKeys][indexPath.row];
    cell.detailTextLabel.text = [_currentlyAvailableShortCuts allValues][indexPath.row];
  }
  return cell;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section
{
  if (section == 0) {
    return @"CHOOSE TRIGGER";
  } else {
    return @"SHORTCUTS HELP";
  }
}

- (NSString *)detailForKeyboardFunc:(const NSString *)func
{
  NSString *trigger = [[BKDefaults keyboardFuncTriggers][func] componentsJoinedByString:@" + "];

  if ([func isEqualToString:(NSString *)BKKeyboardFuncFTriggers]) {
    return [trigger stringByAppendingString:@" + number"];
  } else if ([func isEqualToString:(NSString *)BKKeyboardFuncCursorTriggers]) {
    return [trigger stringByAppendingString:@" + arrow"];
  } else if ([func isEqualToString:(NSString *)BKKeyboardFuncShortcutTriggers]) {
    return [trigger stringByAppendingString:@" + key"];
  }

  return nil;
}

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender
{
  if ([segue.identifier isEqualToString:@"keyboardFuncShortcutTriggers"]) {
    BKKeyboardFuncTriggersViewController *vc = segue.destinationViewController;
    vc.function = @"Shortcuts";
    [vc performInitialSelection:[BKDefaults keyboardFuncTriggers][@"Shortcuts"]];
  }
}


- (IBAction)unwindFromKeyboardShortcutsFuncTriggers:(UIStoryboardSegue *)sender
{
  BKKeyboardFuncTriggersViewController *vc = sender.sourceViewController;
  UITableViewCell *cell = [self.tableView cellForRowAtIndexPath:[NSIndexPath indexPathForRow:0 inSection:0]];

  NSString *function = cell.textLabel.text;
  self.selectedObjects = [vc selectedObjects];

  [BKDefaults setTriggers:self.selectedObjects forFunction:function];
  [BKDefaults saveDefaults];

  cell.detailTextLabel.text = [self detailForKeyboardFunc:function];

  [[NSNotificationCenter defaultCenter]
    postNotificationName:@"BKKeyboardFuncTriggerChanged"
                  object:vc
                userInfo:@{
                  @"func" : function,
                  @"trigger" : self.selectedObjects
                }];
}

@end
