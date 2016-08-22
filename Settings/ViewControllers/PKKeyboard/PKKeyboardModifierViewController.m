//
//  PKKeyboardModifierViewController.m
//  settings
//
//  Created by Atul M on 13/08/16.
//  Copyright © 2016 CARLOS CABANERO. All rights reserved.
//

#import "PKKeyboardModifierViewController.h"
#import "PKDefaults.h"
@interface PKKeyboardModifierViewController ()

@property (nonatomic, strong) NSIndexPath* currentSelectionIdx;
@property (nonatomic, strong) NSMutableArray *items;

@end

@implementation PKKeyboardModifierViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    [self loadData];
}

- (void)viewWillDisappear:(BOOL)animated
{
    if ([self.navigationController.viewControllers indexOfObject:self] == NSNotFound) {
        [self performSegueWithIdentifier:@"unwindFromKeyboardModifier" sender:self];
    }
    [super viewWillDisappear:animated];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (NSString*)selectedObject
{
    return _items[_currentSelectionIdx.row];
}

- (void)loadData{
    _items = [PKDefaults keyboardModifierList];
}

- (void)performInitialSelection:(NSString *)selectedModifier
{
    if(_items == nil || _items.count == 0){
        [self loadData];
    }
    NSInteger pos;
    if (selectedModifier.length) {
        pos = [_items indexOfObject:selectedModifier];
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
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"keyModifierCell" forIndexPath:indexPath];
    cell.textLabel.text = [_items objectAtIndex:indexPath.row];
    if (_currentSelectionIdx == indexPath) {
        [cell setAccessoryType:UITableViewCellAccessoryCheckmark];
    } else {
        [cell setAccessoryType:UITableViewCellAccessoryNone];
    }
    return cell;
}


- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath{
    if (_currentSelectionIdx != nil) {
        // When in selectable mode, do not show details.
        [[tableView cellForRowAtIndexPath:_currentSelectionIdx] setAccessoryType:UITableViewCellAccessoryNone];
    }
    _currentSelectionIdx = indexPath;
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    [[tableView cellForRowAtIndexPath:indexPath] setAccessoryType:UITableViewCellAccessoryCheckmark];
}

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender{
    
}

@end
