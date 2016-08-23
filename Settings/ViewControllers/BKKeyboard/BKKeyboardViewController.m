//
//  BKKeyboardViewController.m
//  settings
//
//  Created by Atul M on 13/08/16.
//  Copyright © 2016 CARLOS CABANERO. All rights reserved.
//

#import "BKKeyboardViewController.h"
#import "BKKeyboardModifierViewController.h"
#import "BKDefaults.h"

#define KEY_LABEL_TAG 1001
#define VALUE_LABEL_TAG 1002

@interface BKKeyboardViewController ()

@property (nonatomic, strong) NSIndexPath* currentSelectionIdx;
@property (nonatomic, strong) NSMutableArray *keyList;
@property (nonatomic, strong) NSMutableDictionary *keyboardMapping;

@end

@implementation BKKeyboardViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    [self loadData];
    // Uncomment the following line to preserve selection between presentations.
    // self.clearsSelectionOnViewWillAppear = NO;
    
    // Uncomment the following line to display an Edit button in the navigation bar for this view controller.
    // self.navigationItem.rightBarButtonItem = self.editButtonItem;
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (NSString*)selectedObject
{
    return _keyList[_currentSelectionIdx.row];
}

- (void)loadData{
    _keyList = [BKDefaults keyBoardKeyList];
    _keyboardMapping = [BKDefaults keyBoardMapping];
}

# pragma mark - UICollection View Delegates

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView{
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section{
    return _keyList.count;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section{
    return @"MODIFIER MAPPINGS";
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath{
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"keyMapperCell" forIndexPath:indexPath];
    
    UILabel *keyLabel = [cell viewWithTag:KEY_LABEL_TAG];
    keyLabel.text = [_keyList objectAtIndex:indexPath.row];
    
    UILabel *valueLabel = [cell viewWithTag:VALUE_LABEL_TAG];
    valueLabel.text = [_keyboardMapping objectForKey:keyLabel.text];
    return cell;
}

- (NSIndexPath *)tableView:(UITableView *)tableView willSelectRowAtIndexPath:(NSIndexPath *)indexPath{
    _currentSelectionIdx = indexPath;
    return indexPath;
}

# pragma mark - Navigation

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender{
    if([segue.identifier isEqualToString:@"keyboardModifier"]){
        BKKeyboardModifierViewController *modifier = segue.destinationViewController;
        [modifier performInitialSelection:[_keyboardMapping objectForKey:[self selectedObject]]];
    }
}

- (IBAction)unwindFromKeyboardModifier:(UIStoryboardSegue *)sender{
    BKKeyboardModifierViewController *modifier = sender.sourceViewController;
    UITableViewCell *cell = [self.tableView cellForRowAtIndexPath:_currentSelectionIdx];
    
    UILabel *valueLabel = [cell viewWithTag:VALUE_LABEL_TAG];
    valueLabel.text = [modifier selectedObject];
    
    [_keyboardMapping setObject:valueLabel.text forKey:[self selectedObject]];
    [BKDefaults setModifer:valueLabel.text forKey:[self selectedObject]];
    [BKDefaults saveDefaults];
}

@end
