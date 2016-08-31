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

#import "BKKeyboardFuncTriggersViewController.h"
#import "BKDefaults.h"

@interface BKKeyboardFuncTriggersViewController ()

@property (nonatomic, strong) NSArray *items;
@property (nonatomic, strong) NSMutableArray *selectedRows;

@end

@implementation BKKeyboardFuncTriggersViewController

- (void)viewDidLoad
{
  [super viewDidLoad];
  [self loadData];
}

- (void)viewWillDisappear:(BOOL)animated
{
  if ([self.navigationController.viewControllers indexOfObject:self] == NSNotFound) {
    [self performSegueWithIdentifier:@"unwindFromKeyboardFuncTriggers" sender:self];
  }
  [super viewWillDisappear:animated];
}

- (void)didReceiveMemoryWarning
{
  [super didReceiveMemoryWarning];
  // Dispose of any resources that can be recreated.
}

- (void)loadData
{
  _items = [NSArray arrayWithArray:[BKDefaults keyboardFuncTriggersList]];
}

- (void)performInitialSelection:(NSArray *)selection
{
  _selectedRows = [NSMutableArray arrayWithArray:selection];
}

- (NSArray *)selectedObjects
{
  return _selectedRows;
}

#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
  return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
  return _items.count;
}


- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
  UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"keyModifierCell" forIndexPath:indexPath];
  cell.textLabel.text = [_items objectAtIndex:indexPath.row];
  if ([self.selectedRows containsObject:cell.textLabel.text]) {
    [cell setAccessoryType:UITableViewCellAccessoryCheckmark];
  } else {
    [cell setAccessoryType:UITableViewCellAccessoryNone];
  }
  return cell;
}


- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
  [tableView deselectRowAtIndexPath:indexPath animated:YES];
  UITableViewCell *cell = [tableView cellForRowAtIndexPath:indexPath];

  // Unselect object if already selected. Select otherwise
  NSUInteger idx = [self.selectedRows indexOfObject:cell.textLabel.text];
  if (idx != NSNotFound) {
    [cell setAccessoryType:UITableViewCellAccessoryNone];
    [self.selectedRows removeObjectAtIndex:idx];
  } else {
    if (self.selectedRows.count < 2) {
      [[tableView cellForRowAtIndexPath:indexPath] setAccessoryType:UITableViewCellAccessoryCheckmark];
      [self.selectedRows addObject:cell.textLabel.text];
    }
  }
}

@end
