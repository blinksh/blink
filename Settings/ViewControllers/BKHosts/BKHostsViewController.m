////////////////////////////////////////////////////////////////////////////////
//
// B L I N K
//
// Copyright (C) 2016-2018 Blink Mobile Shell Project
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

#import "BKHostsViewController.h"
#import "BKHosts.h"
#import "BKHostsDetailViewController.h"
#import "BKiCloudSyncHandler.h"

@implementation BKHostsViewController

- (void)viewDidLoad
{
  [super viewDidLoad];
  [[UIApplication sharedApplication] setNetworkActivityIndicatorVisible:YES];
  [[BKiCloudSyncHandler sharedHandler] setMergeHostCompletionBlock:^{
    dispatch_async(dispatch_get_main_queue(), ^{
      [[UIApplication sharedApplication] setNetworkActivityIndicatorVisible:NO];
      [self.tableView reloadData];
    });
  }];
  [[BKiCloudSyncHandler sharedHandler] checkForReachabilityAndSync:nil];
}

#pragma mark - UITable View delegates

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
  return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
  return BKHosts.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
  NSInteger pkIdx = indexPath.row;
  UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"Cell" forIndexPath:indexPath];
  BKHosts *pk = [BKHosts.all objectAtIndex:pkIdx];

  if (pk.iCloudConflictDetected == [NSNumber numberWithBool:YES]) {
    if ((pk.iCloudConflictDetected.boolValue && pk.iCloudConflictCopy)) {
      cell.textLabel.textColor = [UIColor redColor];
    } else {
      cell.textLabel.textColor = [UIColor blackColor];
      [BKHosts markHost:pk.host forRecord:[BKHosts recordFromHost:pk] withConflict:NO];
    }
  } else {
    cell.textLabel.textColor = [UIColor blackColor];
  }
  // Configure the cell...
  cell.textLabel.text = pk.host;
  cell.detailTextLabel.text = @"";

  return cell;
}

- (UITableViewCellEditingStyle)tableView:(UITableView *)tableView editingStyleForRowAtIndexPath:(NSIndexPath *)indexPath
{
  return UITableViewCellEditingStyleDelete;
}

- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath
{
  if (editingStyle == UITableViewCellEditingStyleDelete) {
    CKRecordID *recordId = [[BKHosts.all objectAtIndex:indexPath.row] iCloudRecordId];
    if (recordId != nil) {
      [[BKiCloudSyncHandler sharedHandler] deleteRecord:recordId ofType:BKiCloudRecordTypeHosts];
    }
    [BKHosts.all removeObjectAtIndex:indexPath.row];
    [self.tableView deleteRowsAtIndexPaths:@[ indexPath ] withRowAnimation:true];
    [BKHosts saveHosts];
    [self.tableView reloadData];
  }
}

#pragma mark - Navigation

- (IBAction)unwindFromCreate:(UIStoryboardSegue *)sender
{
  BKHostsDetailViewController *details = sender.sourceViewController;
  if (!details.isExistingHost) {
    NSIndexPath *newIdx = [NSIndexPath indexPathForRow:(BKHosts.count - 1) inSection:0];
    [self.tableView insertRowsAtIndexPaths:@[ newIdx ] withRowAnimation:UITableViewRowAnimationBottom];
  } else {

    NSUInteger lastRow = [self.tableView numberOfRowsInSection:0];
    if ([self.tableView indexPathForSelectedRow] && lastRow > [[self.tableView indexPathForSelectedRow] row]) {
      [self.tableView reloadRowsAtIndexPaths:@[ [[self tableView] indexPathForSelectedRow] ] withRowAnimation:UITableViewRowAnimationBottom];
    }
  }
}

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender
{
  // Get the new view controller using [segue destinationViewController].
  // Pass the selected object to the new view controller.
  if ([[segue identifier] isEqualToString:@"newHost"]) {
    BKHostsDetailViewController *details = segue.destinationViewController;
    NSIndexPath *indexPath = [[self tableView] indexPathForSelectedRow];
    details.isExistingHost = YES;
    BKHosts *bkHost = [BKHosts.all objectAtIndex:indexPath.row];
    details.bkHost = bkHost;
    return;
  }
}

- (void)dealloc
{
  [[UIApplication sharedApplication] setNetworkActivityIndicatorVisible:NO];
}

@end
