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

#import "BKAppearanceViewController.h"
#import "BKDefaults.h"
#import "BKFont.h"
#import "BKTheme.h"
#import "TermView.h"

#define FONT_SIZE_FIELD_TAG 2001
#define FONT_SIZE_STEPPER_TAG 2002

typedef NS_ENUM(NSInteger, BKAppearanceSections) {
  BKAppearance_Terminal = 0,
    BKAppearance_Themes,
    BKAppearance_Fonts,
    BKAppearance_FontSize
};

#define BKAPPEARANCE_TERM_SECTION 0
#define BKAPPEARANCE_THEME_SECTION 1
#define BKAPPEARANCE

NSString *const BKAppearanceChanged = @"BKAppearanceChanged";

@interface BKAppearanceViewController () <TerminalDelegate>

@property (nonatomic, strong) NSIndexPath *selectedFontIndexPath;
@property (nonatomic, strong) NSIndexPath *selectedThemeIndexPath;
@property (weak, nonatomic) UITextField *fontSizeField;
@property (weak, nonatomic) UIStepper *fontSizeStepper;
@property (nonatomic, strong) TerminalView *testTerminal;

@end

@implementation BKAppearanceViewController

- (void)viewDidLoad
{
  [self loadDefaultValues];
  [super viewDidLoad];
}

- (void)didReceiveMemoryWarning
{
  [super didReceiveMemoryWarning];
  // Dispose of any resources that can be recreated.
}

- (void)viewWillDisappear:(BOOL)animated
{
  if (self.isMovingFromParentViewController) {
    [self saveDefaultValues];
  }
}

- (void)loadDefaultValues
{
  NSString *selectedThemeName = [BKDefaults selectedThemeName];
  BKTheme *selectedTheme = [BKTheme withName:selectedThemeName];
  if (selectedTheme != nil) {
    _selectedThemeIndexPath = [NSIndexPath indexPathForRow:[[BKTheme all] indexOfObject:selectedTheme] inSection:BKAppearance_Themes];
  }
  NSString *selectedFontName = [BKDefaults selectedFontName];
  BKFont *selectedFont = [BKFont withName:selectedFontName];
  if (selectedFont != nil) {
    _selectedFontIndexPath = [NSIndexPath indexPathForRow:[[BKFont all] indexOfObject:selectedFont] inSection:BKAppearance_Fonts];
  }
}

- (void)saveDefaultValues
{
  if (_fontSizeField.text != nil && ![_fontSizeField.text isEqualToString:@""]) {
    [BKDefaults setFontSize:[NSNumber numberWithInt:_fontSizeField.text.intValue]];
  }
  if (_selectedFontIndexPath != nil) {
    [BKDefaults setFontName:[[[BKFont all] objectAtIndex:_selectedFontIndexPath.row] name]];
  }
  if (_selectedThemeIndexPath != nil) {
    [BKDefaults setThemeName:[[[BKTheme all] objectAtIndex:_selectedThemeIndexPath.row] name]];
  }

  [BKDefaults saveDefaults];
  [[NSNotificationCenter defaultCenter]
    postNotificationName:BKAppearanceChanged
                  object:self];
}

#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
  return 4;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
  if (section == BKAppearance_Themes) {
    return [[BKTheme all] count] + 1;
  } else if (section == BKAppearance_Fonts) {
    return [[BKFont all] count] + 1;
  } else {
    return 1;
  }
}

- (void)setFontsUIForCell:(UITableViewCell *)cell atIndexPath:(NSIndexPath *)indexPath
{
  if (indexPath.row == [[BKFont all] count]) {
    cell.textLabel.text = @"Add a new font";
    cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
  } else {
    if (_selectedFontIndexPath == indexPath) {
      [cell setAccessoryType:UITableViewCellAccessoryCheckmark];
    } else {
      [cell setAccessoryType:UITableViewCellAccessoryNone];
    }
    cell.textLabel.text = [[[BKFont all] objectAtIndex:indexPath.row] name];
  }
}

- (void)setThemesUIForCell:(UITableViewCell *)cell atIndexPath:(NSIndexPath *)indexPath
{
  if (indexPath.row == [[BKTheme all] count]) {
    cell.textLabel.text = @"Add a new theme";
    cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
  } else {
    if (_selectedThemeIndexPath == indexPath) {
      [cell setAccessoryType:UITableViewCellAccessoryCheckmark];
    } else {
      [cell setAccessoryType:UITableViewCellAccessoryNone];
    }
    cell.textLabel.text = [[[BKTheme all] objectAtIndex:indexPath.row] name];
  }
}

- (void)attachTestTerminalToView:(UIView *)view
{
  _testTerminal = [[TerminalView alloc] initWithFrame:CGRectMake(0, 0, view.frame.size.width, view.frame.size.height)];
  _testTerminal.delegate = self;
  _testTerminal.backgroundColor = [UIColor blackColor];
  [_testTerminal setInputEnabled:NO];

  if (!view.subviews.count) {
    [view addSubview:_testTerminal];
  }
  [_testTerminal loadTerminal];
}

- (NSString *)cellIdentifierForSection:(NSInteger)section
{
  static NSString *cellIdentifier;
  if (section == BKAppearance_Terminal) {
    cellIdentifier = @"testTerminalCell";
  } else if (section == BKAppearance_Themes || section == BKAppearance_Fonts) {
    cellIdentifier = @"themeFontCell";
  } else if (section == BKAppearance_FontSize) {
    cellIdentifier = @"fontSizeCell";
  }
  return cellIdentifier;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
  UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:[self cellIdentifierForSection:indexPath.section]];
  return cell.bounds.size.height;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
  NSString *cellIdentifier = [self cellIdentifierForSection:indexPath.section];
  if (indexPath.section == BKAppearance_Terminal) {
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:cellIdentifier forIndexPath:indexPath];
    [self attachTestTerminalToView:cell.contentView];
    return cell;
  } else if (indexPath.section == BKAppearance_Themes || indexPath.section == BKAppearance_Fonts) {
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:cellIdentifier forIndexPath:indexPath];
    if (indexPath.section == BKAppearance_Themes) {
      [self setThemesUIForCell:cell atIndexPath:indexPath];
    } else {
      [self setFontsUIForCell:cell atIndexPath:indexPath];
    }
    return cell;
  } else if(indexPath.section == BKAppearance_FontSize) {
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:cellIdentifier forIndexPath:indexPath];
    _fontSizeField = [cell viewWithTag:FONT_SIZE_FIELD_TAG];
    _fontSizeStepper = [cell viewWithTag:FONT_SIZE_STEPPER_TAG];
    if ([BKDefaults selectedFontSize] != nil) {
      _fontSizeStepper.value = [BKDefaults selectedFontSize].integerValue;
      _fontSizeField.text = [NSString stringWithFormat:@"%@ px", [BKDefaults selectedFontSize]];
    } else {
      _fontSizeField.placeholder = @"10 px";
    }
    return cell;
  }
  return nil;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
  if (indexPath.section == BKAppearance_Themes) {
    if (indexPath.row == [[BKTheme all] count]) {
      [self performSegueWithIdentifier:@"addTheme" sender:self];
    } else {
      if (_selectedThemeIndexPath != nil) {
        // When in selectable mode, do not show details.
        [[tableView cellForRowAtIndexPath:_selectedThemeIndexPath] setAccessoryType:UITableViewCellAccessoryNone];
      }
      _selectedThemeIndexPath = indexPath;
      [tableView deselectRowAtIndexPath:indexPath animated:YES];
      [[tableView cellForRowAtIndexPath:indexPath] setAccessoryType:UITableViewCellAccessoryCheckmark];
      
      [self showcaseTheme:[[BKTheme all] objectAtIndex:_selectedThemeIndexPath.row]];
    }
  } else if (indexPath.section == BKAppearance_Fonts) {
    if (indexPath.row == [[BKFont all] count]) {
      [self performSegueWithIdentifier:@"addFont" sender:self];
    } else {
      if (_selectedFontIndexPath != nil) {
        // When in selectable mode, do not show details.
        [[tableView cellForRowAtIndexPath:_selectedFontIndexPath] setAccessoryType:UITableViewCellAccessoryNone];
      }
      _selectedFontIndexPath = indexPath;
      [tableView deselectRowAtIndexPath:indexPath animated:YES];
      [[tableView cellForRowAtIndexPath:indexPath] setAccessoryType:UITableViewCellAccessoryCheckmark];
      [self showcaseFont:[[BKFont all] objectAtIndex:_selectedFontIndexPath.row]];
    }
  }
}


- (IBAction)unwindFromAddFont:(UIStoryboardSegue *)sender
{
  int lastIndex = (int)[BKFont count];
  if (![self.tableView cellForRowAtIndexPath:[NSIndexPath indexPathForRow:lastIndex inSection:1]]) {
    [self.tableView insertRowsAtIndexPaths:@[ [NSIndexPath indexPathForRow:lastIndex - 1 inSection:1] ] withRowAnimation:UITableViewRowAnimationBottom];
  }
}

- (IBAction)unwindFromAddTheme:(UIStoryboardSegue *)sender
{
  int lastIndex = (int)[BKTheme count];
  if (![self.tableView cellForRowAtIndexPath:[NSIndexPath indexPathForRow:lastIndex inSection:0]]) {
    [self.tableView insertRowsAtIndexPaths:@[ [NSIndexPath indexPathForRow:lastIndex - 1 inSection:0] ] withRowAnimation:UITableViewRowAnimationBottom];
  }
}

// Override to support conditional editing of the table view.
- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath
{
  // Return NO if you do not want the specified item to be editable.
  if ((indexPath.section == BKAppearance_Themes && indexPath.row >= [BKTheme defaultResourcesCount] && indexPath.row < [BKTheme count]) ||
      (indexPath.section == BKAppearance_Fonts && indexPath.row >= [BKFont defaultResourcesCount] && indexPath.row < [BKFont count])) {
    return YES;
  } else {
    return NO;
  }
}

// Override to support editing the table view.
- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath
{
  if (editingStyle == UITableViewCellEditingStyleDelete) {
    // Delete the row from the data source
    if (indexPath.section == BKAppearance_Themes) {
      [BKTheme removeResourceAtIndex:(int)indexPath.row];

      if (indexPath.row < _selectedThemeIndexPath.row) {
        _selectedThemeIndexPath = [NSIndexPath indexPathForRow:_selectedThemeIndexPath.row - 1 inSection:0];
      } else if (indexPath.row == _selectedThemeIndexPath.row) {
        _selectedThemeIndexPath = nil;
      }

    } else if (indexPath.section == BKAppearance_Fonts) {
      [BKFont removeResourceAtIndex:(int)indexPath.row];

      if (indexPath.row < _selectedFontIndexPath.row) {
        _selectedFontIndexPath = [NSIndexPath indexPathForRow:_selectedFontIndexPath.row - 1 inSection:0];
      } else if (indexPath.row == _selectedFontIndexPath.row) {
        _selectedFontIndexPath = nil;
      }
    }
    [tableView deleteRowsAtIndexPaths:@[ indexPath ] withRowAnimation:UITableViewRowAnimationFade];
  } else if (editingStyle == UITableViewCellEditingStyleInsert) {
    // Create a new instance of the appropriate class, insert it into the array, and add a new row to the table view
  }
}

- (IBAction)stepperButtonPressed:(id)sender
{
  NSNumber *newSize = [NSNumber numberWithInteger:(int)[_fontSizeStepper value]];
  _fontSizeField.text = [NSString stringWithFormat:@"%@ px", newSize];
  [_testTerminal setFontSize:newSize];
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


#pragma mark - Navigation

// In a storyboard-based application, you will often want to do a little preparation before navigation
//- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
//  // Get the new view controller using [segue destinationViewController].
//  // Pass the selected object to the new view controller.
//}

#pragma mark - Terminal

- (void)terminalIsReady
{
  [_testTerminal setColumnNumber:60];
// Write content
  NSMutableArray *lines = [[NSMutableArray alloc] init];
  NSArray *fgs = @[@"    m",@"   1m",@"  30m",@"1;30m",@"  31m",@"1;31m",@"  32m",@"1;32m",@"  33m",@"1;33m",@"  34m",@"1;34m",@"  35m",@"1;35m",@"  36m",@"1;36m",@"  37m",@"1;37m"];
  NSArray *bgs = @[@"40m",@"41m",@"42m",@"43m",@"44m",@"45m",@"46m",@"47m"];
  for (NSString *fg in fgs) {
    NSMutableArray *line = [[NSMutableArray alloc] init];
    for (NSString *bg in bgs) {
      [line addObject:[NSString stringWithFormat:@" \033[%@\033[%@  gYw \033[0m", fg, bg]];
    }
    [lines addObject:[line componentsJoinedByString:@""]];
  }
  NSString *showcase = [lines componentsJoinedByString:@"\r\n"];
  [_testTerminal write:showcase];

  BKTheme *selectedTheme = [BKTheme withName:[BKDefaults selectedThemeName]];
  if (selectedTheme) {
    [self showcaseTheme:selectedTheme];
  }

  BKFont *selectedFont = [BKFont withName:[BKDefaults selectedFontName]];
  if (selectedFont) {
    [self showcaseFont:selectedFont];
  }

  [_testTerminal setFontSize:[BKDefaults selectedFontSize]];
}

- (void)fontSizeChanged:(NSNumber *)size
{
  _fontSizeStepper.value = size.integerValue;
  _fontSizeField.text = [NSString stringWithFormat:@"%@ px", size];
}

- (void)write:(NSString *)input
{
  // Nothing
}

- (void)showcaseTheme:(BKTheme *)theme
{
  [_testTerminal loadTerminalThemeJS:theme.content];
}

- (void)showcaseFont:(BKFont *)font
{
  [_testTerminal loadTerminalFont:font.name fromCSS:font.fullPath];
}

@end
