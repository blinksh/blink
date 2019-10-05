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

#import "BKAppearanceViewController.h"
#import "BKDefaults.h"
#import "BKFont.h"
#import "BKTheme.h"
#import "TermView.h"
#import "TermDevice.h"

#define FONT_SIZE_FIELD_TAG 2001
#define FONT_SIZE_STEPPER_TAG 2002
#define CURSOR_BLINK_TAG 2003
#define BOLD_AS_BRIGHT_TAG 2004
#define ENABLE_BOLD_TAG 2006
#define APP_ICON_ALTERNATE_TAG 2007
#define LAYOUT_MODE_TAG 2008
#define OVERSCAN_COMPENSATION_TAG 2009
#define KEYBOARDSTYLE_TAG 2010

typedef NS_ENUM(NSInteger, BKAppearanceSections) {
  BKAppearance_Terminal = 0,
    BKAppearance_Themes,
    BKAppearance_Fonts,
    BKAppearance_FontSize,
    BKAppearance_KeyboardAppearance,
    BKAppearance_AppIcon,
    BKAppearance_Layout,
};

NSString *const BKAppearanceChanged = @"BKAppearanceChanged";

@interface BKAppearanceViewController () <TermViewDeviceProtocol>

@property (nonatomic, strong) NSIndexPath *selectedFontIndexPath;
@property (nonatomic, strong) NSIndexPath *selectedThemeIndexPath;
@property (weak, nonatomic) UITextField *fontSizeField;
@property (weak, nonatomic) UIStepper *fontSizeStepper;
@property (strong, nonatomic) TermView *termView;

@end

@implementation BKAppearanceViewController {
  UISwitch *_cursorBlinkSwitch;
  BOOL _cursorBlinkValue;
  
  UISwitch *_boldAsBrightSwitch;
  BOOL _boldAsBrightValue;
  
  UISwitch *_lightKeyboardSwitch;
  BOOL _lightKeyboardValue;
  
  UISegmentedControl *_enableBoldSegmentedControl;
  NSUInteger _enableBoldValue;
  
  UISwitch *_alternateAppIconSwitch;
  BOOL _alternateAppIconValue;
  
  UISegmentedControl *_defaultLayoutModeSegmentedControl;
  BKLayoutMode _defaultLayoutModeValue;
  
  UISegmentedControl *_overscanCompensationSegmentedControl;
  BKOverscanCompensation _overscanCompensationValue;
  
  UISegmentedControl *_keyboardStyleSegmentedControl;
  BKKeyboardStyle _keyboardStyleValue;
}

- (void)viewDidLoad
{
  [self loadDefaultValues];
  [super viewDidLoad];
  
  _termView = [[TermView alloc] initWithFrame:self.view.bounds];
  _termView.backgroundColor = UIColor.systemGroupedBackgroundColor;
  _termView.device = self;
  [_termView loadWith:nil];
}

- (void)viewWillDisappear:(BOOL)animated
{
  if (self.isMovingFromParentViewController) {
    [self saveDefaultValues];
  }
  [super viewWillDisappear:animated];
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
    NSInteger row = [[BKFont all] indexOfObject:selectedFont];
    // User have deleted the font, so we set it back to default
    if (row == NSNotFound) {
      [BKDefaults setFontName:@"Source Code Pro"]; // TODO get it right
      selectedFontName = [BKDefaults selectedFontName];
      selectedFont = [BKFont withName:selectedFontName];
      row = [[BKFont all] indexOfObject:selectedFont];
    }
    _selectedFontIndexPath = [NSIndexPath indexPathForRow:row inSection:BKAppearance_Fonts];
  }
  _cursorBlinkValue = [BKDefaults isCursorBlink];
  _boldAsBrightValue = [BKDefaults isBoldAsBright];
  _enableBoldValue = [BKDefaults enableBold];
  _alternateAppIconValue = [BKDefaults isAlternateAppIcon];
  _defaultLayoutModeValue = BKDefaults.layoutMode;
  _overscanCompensationValue = BKDefaults.overscanCompensation;
  _keyboardStyleValue = BKDefaults.keyboardStyle;
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
  
  _keyboardStyleValue = [self _keyboardStyleFromIndex:_keyboardStyleSegmentedControl.selectedSegmentIndex];
  
  [BKDefaults setCursorBlink:_cursorBlinkValue];
  [BKDefaults setBoldAsBright:_boldAsBrightValue];
  [BKDefaults setAlternateAppIcon:_alternateAppIconValue];
  [BKDefaults setEnableBold: _enableBoldValue];
  [BKDefaults setLayoutMode:_defaultLayoutModeValue];
  [BKDefaults setOversanCompensation:_overscanCompensationValue];
  [BKDefaults setKeyboardStyle:_keyboardStyleValue];

  [BKDefaults saveDefaults];
  [[NSNotificationCenter defaultCenter]
    postNotificationName:BKAppearanceChanged
                  object:self];
}

#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
  return 7;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
  if (section == BKAppearance_Terminal) {
    return 1;
  } else if (section == BKAppearance_Themes) {
    return [[BKTheme all] count] + 1;
  } else if (section == BKAppearance_Fonts) {
    return [[BKFont all] count] + 1;
  } else if (section == BKAppearance_KeyboardAppearance) {
    return 1;
  } else if (section == BKAppearance_AppIcon) {
    return 1;
  } else if (section == BKAppearance_Layout) {
    return 2;
  } else {
    return 4;
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
  [view addSubview:_termView];
  _termView.frame = view.bounds;
}

- (NSString *)cellIdentifierForIndexPath:(NSIndexPath *)indexPath
{
  NSInteger section = indexPath.section;
  static NSString *cellIdentifier;
  if (section == BKAppearance_Terminal) {
    cellIdentifier = @"testTerminalCell";
  } else if (section == BKAppearance_Themes || section == BKAppearance_Fonts) {
    cellIdentifier = @"themeFontCell";
  } else if (section == BKAppearance_FontSize) {
    if (indexPath.row == 0) {
      cellIdentifier = @"fontSizeCell";
    } else if (indexPath.row == 1) {
      cellIdentifier = @"enableBoldCell";
    } else if (indexPath.row == 2) {
      cellIdentifier = @"boldAsBrightCell";
    } else {
      cellIdentifier = @"cursorBlinkCell";
    }
  } else if (section == BKAppearance_KeyboardAppearance) {
    cellIdentifier = @"keyboardStyleCell";
  } else if (section == BKAppearance_AppIcon) {
    cellIdentifier = @"alternateAppIconCell";
  } else if (section == BKAppearance_Layout) {
    if (indexPath.row == 0) {
      cellIdentifier = @"defaultLayoutCell";
    } else {
      cellIdentifier = @"overscanCompensationCell";
    }
  }
  
  
  return cellIdentifier;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
  UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:[self cellIdentifierForIndexPath:indexPath]];
  return cell.bounds.size.height;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section
{
  switch(section) {
  case BKAppearance_Terminal:
    return @"PREVIEW";
  case BKAppearance_Themes:
    return @"THEMES";
  case BKAppearance_Fonts:
    return @"FONTS";
  case BKAppearance_KeyboardAppearance:
    return @"Keyboard Appearance";
  case BKAppearance_AppIcon:
    return @"APP ICON";
    case BKAppearance_Layout:
      return @"Layout";
  default:
    return nil;
  }
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
  NSString *cellIdentifier = [self cellIdentifierForIndexPath:indexPath];
  UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:cellIdentifier forIndexPath:indexPath];
  
  if (indexPath.section == BKAppearance_Terminal) {
    [self attachTestTerminalToView:cell.contentView];
  } else if (indexPath.section == BKAppearance_Themes || indexPath.section == BKAppearance_Fonts) {
    if (indexPath.section == BKAppearance_Themes) {
      [self setThemesUIForCell:cell atIndexPath:indexPath];
    } else {
      [self setFontsUIForCell:cell atIndexPath:indexPath];
    }
    return cell;
  } else if(indexPath.section == BKAppearance_FontSize && indexPath.row == 0) {
    _fontSizeField = [cell viewWithTag:FONT_SIZE_FIELD_TAG];
    _fontSizeStepper = [cell viewWithTag:FONT_SIZE_STEPPER_TAG];
    if ([BKDefaults selectedFontSize] != nil) {
      [_fontSizeStepper setValue:[BKDefaults selectedFontSize].integerValue];
      _fontSizeField.text = [NSString stringWithFormat:@"%@ px", [BKDefaults selectedFontSize]];
    } else {
      _fontSizeField.placeholder = @"";
    }
  } else if (indexPath.section == BKAppearance_FontSize && indexPath.row == 1) {
    _enableBoldSegmentedControl = [cell viewWithTag:ENABLE_BOLD_TAG];
    _enableBoldSegmentedControl.selectedSegmentIndex = _enableBoldValue;
  } else if (indexPath.section == BKAppearance_FontSize && indexPath.row == 2) {
    _boldAsBrightSwitch = [cell viewWithTag:BOLD_AS_BRIGHT_TAG];
    _boldAsBrightSwitch.on = _boldAsBrightValue;
  } else if (indexPath.section == BKAppearance_FontSize && indexPath.row == 3) {
    _cursorBlinkSwitch = [cell viewWithTag:CURSOR_BLINK_TAG];
    _cursorBlinkSwitch.on = _cursorBlinkValue;
  } else if (indexPath.section == BKAppearance_KeyboardAppearance && indexPath.row == 0) {
    _keyboardStyleSegmentedControl = [cell viewWithTag:KEYBOARDSTYLE_TAG];
    _keyboardStyleSegmentedControl.selectedSegmentIndex = [self _keyboardStyleToIndex: _keyboardStyleValue];
  } else if (indexPath.section == BKAppearance_AppIcon && indexPath.row == 0) {
    _alternateAppIconSwitch = [cell viewWithTag:APP_ICON_ALTERNATE_TAG];
    _alternateAppIconSwitch.on = _alternateAppIconValue;
  } else if (indexPath.section == BKAppearance_Layout && indexPath.row == 0) {
    _defaultLayoutModeSegmentedControl = [cell viewWithTag:LAYOUT_MODE_TAG];
    _defaultLayoutModeSegmentedControl.selectedSegmentIndex = [self _layoutModeToIndex:_defaultLayoutModeValue];
  } else if (indexPath.section == BKAppearance_Layout && indexPath.row == 1) {
    _overscanCompensationSegmentedControl = [cell viewWithTag:OVERSCAN_COMPENSATION_TAG];
    _overscanCompensationSegmentedControl.selectedSegmentIndex = [self _overscanCompensationToIndex:_overscanCompensationValue];
  }
  return cell;
}

- (NSInteger)_layoutModeToIndex:(BKLayoutMode) mode {
  switch (mode) {
    case BKLayoutModeCover:
      return 0;
    case BKLayoutModeSafeFit:
      return 1;
    case BKLayoutModeFill:
      return 2;
    default:
      return UISegmentedControlNoSegment;
  }
}

- (BKLayoutMode)_layoutModeFromIndex:(NSInteger) index {
  if (index == 0) {
    return BKLayoutModeCover;
  }
  if (index == 1) {
    return BKLayoutModeSafeFit;
  }
  if (index == 2) {
    return BKLayoutModeFill;
  }
  
  return BKLayoutModeDefault;
}

- (NSInteger)_overscanCompensationToIndex:(BKOverscanCompensation) value {
  switch (value) {
    case BKBKOverscanCompensationScale:
      return 0;
    case BKBKOverscanCompensationInsetBounds:
      return 1;
    case BKBKOverscanCompensationNone:
      return 2;
    default:
      return UISegmentedControlNoSegment;
  }
}

- (BKOverscanCompensation)_overscanCompensationFromIndex:(NSInteger) index {
  if (index == 0) {
    return BKBKOverscanCompensationScale;
  }
  if (index == 1) {
    return BKBKOverscanCompensationInsetBounds;
  }
  if (index == 2) {
    return BKBKOverscanCompensationNone;
  }
  
  return BKBKOverscanCompensationScale;
}

- (NSInteger)_keyboardStyleToIndex:(BKKeyboardStyle) value {
  switch (value) {
    case BKKeyboardStyleSystem: return 0;
    case BKKeyboardStyleLight: return 1;
    case BKKeyboardStyleDark: return 2;
    default: return 0;
  }
}

- (BKKeyboardStyle)_keyboardStyleFromIndex:(NSInteger) index {
  if (index == 0) {
    return BKKeyboardStyleSystem;
  }
  if (index == 1) {
    return BKKeyboardStyleLight;
  }
  if (index == 2) {
    return BKKeyboardStyleDark;
  }
  
  return BKKeyboardStyleSystem;
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
      BKTheme *theme = [[BKTheme all] objectAtIndex:_selectedThemeIndexPath.row];
      [BKDefaults setThemeName:[theme name]];
      [_termView reloadWith:nil];
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
      BKFont *font = [[BKFont all] objectAtIndex:_selectedFontIndexPath.row];
      [BKDefaults setFontName:[font name]];
      [_termView reloadWith:nil];
    }
  }
}

- (IBAction)unwindFromAddFont:(UIStoryboardSegue *)sender
{
  int lastIndex = (int)[BKFont count];
  if (![self.tableView cellForRowAtIndexPath:[NSIndexPath indexPathForRow:lastIndex inSection:BKAppearance_Fonts]]) {
    [self.tableView insertRowsAtIndexPaths:@[ [NSIndexPath indexPathForRow:lastIndex - 1 inSection:BKAppearance_Fonts] ] withRowAnimation:UITableViewRowAnimationBottom];
  }
}

- (IBAction)unwindFromAddTheme:(UIStoryboardSegue *)sender
{
  int lastIndex = (int)[BKTheme count];
  if (![self.tableView cellForRowAtIndexPath:[NSIndexPath indexPathForRow:lastIndex inSection:BKAppearance_Themes]]) {
    [self.tableView insertRowsAtIndexPaths:@[ [NSIndexPath indexPathForRow:lastIndex - 1 inSection:BKAppearance_Themes] ] withRowAnimation:UITableViewRowAnimationBottom];
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

- (BOOL)tableView:(UITableView *)tableView shouldHighlightRowAtIndexPath:(NSIndexPath *)indexPath
{
  if (indexPath.section == BKAppearance_AppIcon
      || indexPath.section == BKAppearance_KeyboardAppearance
      || indexPath.section == BKAppearance_Layout) {
    return NO;
  }
  return indexPath.section != BKAppearance_FontSize;
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

- (IBAction)stepperValueChanged:(id)sender
{
  NSNumber *newSize = [NSNumber numberWithInteger:(int)[_fontSizeStepper value]];
  [_termView setFontSize:newSize];
  [_termView setWidth:60];
}

- (IBAction)cursorBlinkSwitchChanged:(id)sender
{
  _cursorBlinkValue = _cursorBlinkSwitch.on;
  [_termView setCursorBlink:_cursorBlinkValue];
}

- (IBAction)boldAsBrightSwitchChanged:(id)sender
{
  _boldAsBrightValue = _boldAsBrightSwitch.on;
  [_termView setBoldAsBright:_boldAsBrightValue];
}

- (IBAction)enableBoldChanged:(UISegmentedControl *)sender
{
  _enableBoldValue = sender.selectedSegmentIndex;
  [_termView setBoldEnabled:_enableBoldValue];
}

- (IBAction)defaultLayoutChanged:(UISegmentedControl *)sender
{
  _defaultLayoutModeValue = [self _layoutModeFromIndex:sender.selectedSegmentIndex];
}

- (IBAction)overscanCompensationChanged:(UISegmentedControl *)sender
{
  _overscanCompensationValue = [self _overscanCompensationFromIndex:sender.selectedSegmentIndex];
  
  [BKDefaults applyExternalScreenCompensation:_overscanCompensationValue];
}


- (IBAction)alternateAppIconSwitchChanged:(id)sender
{
  _alternateAppIconValue = _alternateAppIconSwitch.on;
  NSString *appIcon = nil;
  if (_alternateAppIconValue) {
    appIcon = @"DarkAppIcon";
  }
  [[UIApplication sharedApplication] setAlternateIconName:appIcon completionHandler:nil];
}

#pragma mark - TermViewDeviceProtocol

- (void)viewIsReady
{
  [_termView setCursorBlink:_cursorBlinkValue];
  [_termView setBoldAsBright:_boldAsBrightValue];
  [_termView setWidth:60];
  [self _writeColorShowcase];
}

- (void)viewFontSizeChanged:(NSInteger)size
{
  [BKDefaults setFontSize:@(size)];
  _fontSizeStepper.value = size;
  [_fontSizeField setText:[NSString stringWithFormat:@"%@ px", @(size)]];
}

- (void)viewWinSizeChanged:(struct winsize)win
{
  
}

- (void)viewSendString:(NSString *)data
{
  
}

- (void)viewCopyString:(NSString *)text
{
  
}

- (BOOL)handleControl:(NSString *)control
{
  return NO;
}

- (void)viewShowAlert:(NSString *)title andMessage:(NSString *)message {
  UIAlertController *alertController = [UIAlertController alertControllerWithTitle:title
                                                                           message:message
                                                                    preferredStyle:UIAlertControllerStyleAlert];
  __weak UIAlertController *weakAlertController = alertController;
  [alertController addAction:[UIAlertAction actionWithTitle:@"Ok" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
    [weakAlertController dismissViewControllerAnimated:YES completion:nil];
  }]];
  
  [self presentViewController:alertController animated:YES completion:nil];
}

- (void)_writeColorShowcase
{
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
  [_termView write:showcase];
}


@end
