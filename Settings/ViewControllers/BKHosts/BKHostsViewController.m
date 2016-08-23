//
//  BKHostsViewController.m
//  settings
//
//  Created by Atul M on 11/08/16.
//  Copyright © 2016 CARLOS CABANERO. All rights reserved.
//

#import "BKHostsViewController.h"
#import "BKHostsDetailViewController.h"
#import "BKHosts.h"

@implementation BKHostsViewController

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
    if(!details.isExistingHost){
        NSIndexPath *newIdx = [NSIndexPath indexPathForRow:(BKHosts.count - 1) inSection:0];
        [self.tableView insertRowsAtIndexPaths:@[ newIdx ] withRowAnimation:UITableViewRowAnimationBottom];
    } else {
        [self.tableView reloadRowsAtIndexPaths:@[[[self tableView] indexPathForSelectedRow]] withRowAnimation:UITableViewRowAnimationBottom];
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

@end
