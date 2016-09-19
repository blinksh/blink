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

#import "BKFeedbackViewController.h"
#import "BKLinkActions.h"

@interface BKFeedbackViewController ()

@property (weak, nonatomic) IBOutlet UITableViewCell *twitterLinkCell;
@property (weak, nonatomic) IBOutlet UITableViewCell *githubLinkCell;
@property (weak, nonatomic) IBOutlet UITableViewCell *appstoreLinkCell;

@end

@implementation BKFeedbackViewController

- (void)viewDidLoad
{
  [super viewDidLoad];

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

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
  UITableViewCell *clickedCell = [self.tableView cellForRowAtIndexPath:indexPath];

  if ([clickedCell isEqual:self.twitterLinkCell]) {
    [BKLinkActions sendToTwitter];
  } else if ([clickedCell isEqual:self.githubLinkCell]) {
    [BKLinkActions sendToGitHub:nil];
  } else if ([clickedCell isEqual:self.appstoreLinkCell]) {
    [BKLinkActions sendToAppStore];
  }
}

@end
