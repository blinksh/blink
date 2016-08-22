//
//  PKAppearanceViewController.m
//  settings
//
//  Created by Atul M on 14/08/16.
//  Copyright © 2016 CARLOS CABANERO. All rights reserved.
//

#import "PKAppearanceViewController.h"
#import "PKTheme.h"
#import "PKFont.h"
#import "PKDefaults.h"
#define FONT_SIZE_FIELD_TAG 2001
#define FONT_SIZE_STEPPER_TAG 2002

@interface PKAppearanceViewController ()

@property (nonatomic, strong) NSIndexPath *selectedFontIndexPath;
@property (nonatomic, strong) NSIndexPath *selectedThemeIndexPath;
@property (weak, nonatomic) UITextField *fontSizeField;
@property (weak, nonatomic) UIStepper *fontSizeStepper;
@end

@implementation PKAppearanceViewController

- (void)viewDidLoad {
    [self loadDefaultValues];
    [super viewDidLoad];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void)viewWillDisappear:(BOOL)animated{
    [super viewWillDisappear:animated];
    [self saveDefaultValues];
}

- (void)viewWillAppear:(BOOL)animated{
    [super viewWillAppear:animated];
}

- (void)loadDefaultValues{
    NSString *selectedThemeName = [PKDefaults selectedThemeName];
    PKTheme *selectedTheme = [PKTheme withTheme:selectedThemeName];
    if(selectedTheme != nil) {
        _selectedThemeIndexPath = [NSIndexPath indexPathForRow:[[PKTheme all]indexOfObject:selectedTheme] inSection:0];
    }
    NSString *selectedFontName = [PKDefaults selectedFontName];
    PKFont *selectedFont = [PKFont withFont:selectedFontName];
    if(selectedFont != nil) {
        _selectedFontIndexPath = [NSIndexPath indexPathForRow:[[PKFont all]indexOfObject:selectedFont] inSection:1];
    }
}

- (void)saveDefaultValues{
    if(_fontSizeField.text != nil && ![_fontSizeField.text isEqualToString:@""]){
        [PKDefaults setFontSize:[NSNumber numberWithInt:_fontSizeField.text.intValue]];
    }
    if(_selectedFontIndexPath != nil){
        [PKDefaults setFontName:[[[PKFont all]objectAtIndex:_selectedFontIndexPath.row]name]];
    }
    if(_selectedThemeIndexPath != nil){
        [PKDefaults setThemeName:[[[PKTheme all]objectAtIndex:_selectedThemeIndexPath.row]name]];
    }
    [PKDefaults saveDefaults];
}

#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 3;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    if (section == 0) {
        return [[PKTheme all]count]+1;
    } else if(section == 1){
        return [[PKFont all]count]+1;
    } else {
        return 1;
    }
}

- (void)setFontsUIForCell:(UITableViewCell*)cell atIndexPath:(NSIndexPath*)indexPath{
    if(indexPath.row == [[PKFont all]count]){
        cell.textLabel.text = @"Add a new font";
        cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
    } else {
        if (_selectedFontIndexPath == indexPath) {
            [cell setAccessoryType:UITableViewCellAccessoryCheckmark];
        } else {
            [cell setAccessoryType:UITableViewCellAccessoryNone];
        }
        cell.textLabel.text = [[[PKFont all]objectAtIndex:indexPath.row]name];
    }
}

- (void)setThemesUIForCell:(UITableViewCell*)cell atIndexPath:(NSIndexPath*)indexPath{
    if(indexPath.row == [[PKTheme all]count]){
        cell.textLabel.text = @"Add a new theme";
        cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
    } else {
        if (_selectedThemeIndexPath == indexPath) {
            [cell setAccessoryType:UITableViewCellAccessoryCheckmark];
        } else {
            [cell setAccessoryType:UITableViewCellAccessoryNone];
        }
        cell.textLabel.text = [[[PKTheme all]objectAtIndex:indexPath.row]name];
    }
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    if(indexPath.section == 0 || indexPath.section == 1){
        UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"themeFontCell" forIndexPath:indexPath];
        if (indexPath.section == 0) {
            [self setThemesUIForCell:cell atIndexPath:indexPath];
        } else {
            [self setFontsUIForCell:cell atIndexPath:indexPath];
        }
        return cell;
    } else {
        UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"fontSizeCell" forIndexPath:indexPath];
        _fontSizeField = [cell viewWithTag:FONT_SIZE_FIELD_TAG];
        _fontSizeStepper = [cell viewWithTag:FONT_SIZE_STEPPER_TAG];
        if([PKDefaults selectedFontSize] != nil){
            _fontSizeStepper.value = [PKDefaults selectedFontSize].integerValue;
            _fontSizeField.text = [NSString stringWithFormat:@"%@ px",[PKDefaults selectedFontSize]];
        } else {
            _fontSizeField.placeholder = @"10 px";
        }
        return cell;
    }
    // Configure the cell...
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath{
    if(indexPath.section == 0){
        if(indexPath.row == [[PKTheme all]count]){
            [self performSegueWithIdentifier:@"addTheme" sender:self];
        } else {
            if (_selectedThemeIndexPath != nil) {
                // When in selectable mode, do not show details.
                [[tableView cellForRowAtIndexPath:_selectedThemeIndexPath] setAccessoryType:UITableViewCellAccessoryNone];
            }
            _selectedThemeIndexPath = indexPath;
            [tableView deselectRowAtIndexPath:indexPath animated:YES];
            [[tableView cellForRowAtIndexPath:indexPath] setAccessoryType:UITableViewCellAccessoryCheckmark];
        }
    } else if (indexPath.section == 1){
        if(indexPath.row == [[PKFont all]count]){
            [self performSegueWithIdentifier:@"addFont" sender:self];
        } else {
            if (_selectedFontIndexPath != nil) {
                // When in selectable mode, do not show details.
                [[tableView cellForRowAtIndexPath:_selectedFontIndexPath] setAccessoryType:UITableViewCellAccessoryNone];
            }
            _selectedFontIndexPath = indexPath;
            [tableView deselectRowAtIndexPath:indexPath animated:YES];
            [[tableView cellForRowAtIndexPath:indexPath] setAccessoryType:UITableViewCellAccessoryCheckmark];
        }
    }
}

- (IBAction)unwindFromAddFont:(UIStoryboardSegue *)sender{
    int lastIndex = (int)[PKFont count];
    if (![self.tableView cellForRowAtIndexPath:[NSIndexPath indexPathForRow:lastIndex inSection:1]]) {
        [self.tableView insertRowsAtIndexPaths:@[[NSIndexPath indexPathForRow:lastIndex-1 inSection:1]] withRowAnimation:UITableViewRowAnimationBottom];
    }
    
}

- (IBAction)unwindFromAddTheme:(UIStoryboardSegue *)sender{
    int lastIndex = (int)[PKTheme count];
    if (![self.tableView cellForRowAtIndexPath:[NSIndexPath indexPathForRow:lastIndex inSection:0]]) {
        [self.tableView insertRowsAtIndexPaths:@[[NSIndexPath indexPathForRow:lastIndex-1 inSection:0]] withRowAnimation:UITableViewRowAnimationBottom];
    }
}

// Override to support conditional editing of the table view.
- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath {
    // Return NO if you do not want the specified item to be editable.
    if((indexPath.section == 0 && indexPath.row < [PKTheme count]) || (indexPath.section == 1 && indexPath.row < [PKFont count])){
        return YES;
    } else {
        return NO;
    }
    
}

// Override to support editing the table view.
- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath {
    if (editingStyle == UITableViewCellEditingStyleDelete) {
        // Delete the row from the data source
        if(indexPath.section == 0){
            [PKTheme removeThemeAtIndex:(int)indexPath.row];
            
            if(indexPath.row < _selectedThemeIndexPath.row){
                _selectedThemeIndexPath = [NSIndexPath indexPathForRow:_selectedThemeIndexPath.row-1 inSection:0];
            } else if(indexPath.row == _selectedThemeIndexPath.row){
                _selectedThemeIndexPath = nil;
            }
            
        } else if (indexPath.section == 1){
            [PKFont removeFontAtIndex:(int)indexPath.row];
            
            if(indexPath.row < _selectedFontIndexPath.row){
                _selectedFontIndexPath = [NSIndexPath indexPathForRow:_selectedFontIndexPath.row-1 inSection:0];
            } else if(indexPath.row == _selectedFontIndexPath.row){
                _selectedFontIndexPath = nil;
            }
        }
        [tableView deleteRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationFade];
    } else if (editingStyle == UITableViewCellEditingStyleInsert) {
        // Create a new instance of the appropriate class, insert it into the array, and add a new row to the table view
    }   
}
- (IBAction)stepperButtonPressed:(id)sender {
    _fontSizeField.text = [NSString stringWithFormat:@"%d px",(int)[_fontSizeStepper value]];
}

/*
// Override to support rearranging the table view.
- (void)tableView:(UITableView *)tableView moveRowAtIndexPath:(NSIndexPath *)fromIndexPath toIndexPath:(NSIndexPath *)toIndexPath {
}
*/

/*
// Override to support conditional rearranging of the table view.
- (BOOL)tableView:(UITableView *)tableView canMoveRowAtIndexPath:(NSIndexPath *)indexPath {
    // Return NO if you do not want the item to be re-orderable.
    return YES;
}
*/

/*
#pragma mark - Navigation

// In a storyboard-based application, you will often want to do a little preparation before navigation
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    // Get the new view controller using [segue destinationViewController].
    // Pass the selected object to the new view controller.
}
*/

@end
