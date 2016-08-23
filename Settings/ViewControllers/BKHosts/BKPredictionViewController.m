//
//  BKPredictionViewController.m
//  settings
//
//  Created by Atul M on 11/08/16.
//  Copyright © 2016 CARLOS CABANERO. All rights reserved.
//

#import "BKPredictionViewController.h"
#import "BKHosts.h"
@interface BKPredictionViewController ()
@property (nonatomic, strong) NSMutableArray *items;
@property NSIndexPath *currentSelectionIdx;

@end

@implementation BKPredictionViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    [self loadData];
    // Uncomment the following line to preserve selection between presentations.
    // self.clearsSelectionOnViewWillAppear = NO;
    
    // Uncomment the following line to display an Edit button in the navigation bar for this view controller.
    // self.navigationItem.rightBarButtonItem = self.editButtonItem;
}

- (void)viewWillDisappear:(BOOL)animated
{
    if ([self.navigationController.viewControllers indexOfObject:self] == NSNotFound) {
        [self performSegueWithIdentifier:@"unwindFromPrediction" sender:self];
    }
    [super viewWillDisappear:animated];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (id)selectedObject
{
    return _items[_currentSelectionIdx.row];
}

- (void)loadData{
    _items = [BKHosts predictionStringList];
}

- (void)performInitialSelection:(NSString *)selectedPrediction
{
    if(_items == nil || _items.count == 0){
        [self loadData];
    }
    NSInteger pos;
    if (selectedPrediction.length) {
        pos = [_items indexOfObject:selectedPrediction];
    } else {
        pos = 0;
    }
    _currentSelectionIdx = [NSIndexPath indexPathForRow:pos inSection:0];
}

#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return _items.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"predictionCell" forIndexPath:indexPath];
    cell.textLabel.text = [_items objectAtIndex:indexPath.row];
    if (_currentSelectionIdx == indexPath) {
        [cell setAccessoryType:UITableViewCellAccessoryCheckmark];
    } else {
        [cell setAccessoryType:UITableViewCellAccessoryNone];
    }
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (_currentSelectionIdx != nil) {
        // When in selectable mode, do not show details.
        [[tableView cellForRowAtIndexPath:_currentSelectionIdx] setAccessoryType:UITableViewCellAccessoryNone];
    }
    _currentSelectionIdx = indexPath;
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    [[tableView cellForRowAtIndexPath:indexPath] setAccessoryType:UITableViewCellAccessoryCheckmark];
}

@end
