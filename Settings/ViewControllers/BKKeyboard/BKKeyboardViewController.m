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

#import "BKKeyboardViewController.h"
#import "BKDefaults.h"
#import "BKKeyboardModifierViewController.h"
#import "BKSettingsNotifications.h"

#define KEY_LABEL_TAG 1001
#define VALUE_LABEL_TAG 1002

NSString *const BKKeyboardModifierChanged = @"BKKeyboardModifierChanged";

@interface BKKeyboardViewController ()

@property (nonatomic, strong) NSIndexPath *currentSelectionIdx;
@property (nonatomic, strong) NSMutableArray *keyList;
@property (nonatomic, strong) NSMutableDictionary *keyboardMapping;

@end

@implementation BKKeyboardViewController

- (void)viewDidLoad
{
  [super viewDidLoad];
  [self loadData];
  // Uncomment the following line to preserve selection between presentations.
  // self.clearsSelectionOnViewWillAppear = NO;

  // Uncomment the following line to display an Edit button in the navigation bar for this view controller.
  // self.navigationItem.rightBarButtonItem = self.editButtonItem;
}

- (void)didReceiveMemoryWarning
{
  [super didReceiveMemoryWarning];
  // Dispose of any resources that can be recreated.
}

- (NSString *)selectedObject
{
  return _keyList[_currentSelectionIdx.row];
}

- (void)loadData
{
  _keyList = [BKDefaults keyboardKeyList];
  _keyboardMapping = [BKDefaults keyboardMapping];
}

#pragma mark - UICollection View Delegates

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
  return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
  return _keyList.count;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section
{
  return @"MODIFIER MAPPINGS";
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
  UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"keyMapperCell" forIndexPath:indexPath];

  UILabel *keyLabel = [cell viewWithTag:KEY_LABEL_TAG];
  keyLabel.text = [_keyList objectAtIndex:indexPath.row];

  UILabel *valueLabel = [cell viewWithTag:VALUE_LABEL_TAG];
  valueLabel.text = [_keyboardMapping objectForKey:keyLabel.text];
  return cell;
}

- (NSIndexPath *)tableView:(UITableView *)tableView willSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
  _currentSelectionIdx = indexPath;
  return indexPath;
}

#pragma mark - Navigation

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender
{
  if ([segue.identifier isEqualToString:@"keyboardModifier"]) {
    BKKeyboardModifierViewController *modifier = segue.destinationViewController;
    [modifier performInitialSelection:[_keyboardMapping objectForKey:[self selectedObject]]];
  }
}

- (IBAction)unwindFromKeyboardModifier:(UIStoryboardSegue *)sender
{
  BKKeyboardModifierViewController *modifier = sender.sourceViewController;
  UITableViewCell *cell = [self.tableView cellForRowAtIndexPath:_currentSelectionIdx];

  UILabel *valueLabel = [cell viewWithTag:VALUE_LABEL_TAG];
  valueLabel.text = [modifier selectedObject];

  [_keyboardMapping setObject:valueLabel.text forKey:[self selectedObject]];
  [BKDefaults setModifer:valueLabel.text forKey:[self selectedObject]];
  [BKDefaults saveDefaults];
  
  // Notify
  [[NSNotificationCenter defaultCenter]
      postNotificationName:BKKeyboardModifierChanged
		    object:modifier
		  userInfo:@{
      @"modifier": [self selectedObject],
	@"sequence":valueLabel.text}
   ];
}

@end
