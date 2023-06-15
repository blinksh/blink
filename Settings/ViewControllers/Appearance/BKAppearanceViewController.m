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
#import "BLKDefaults.h"
#import "BKFont.h"
#import "BKTheme.h"
#import "DeviceInfo.h"
#import "TermView.h"
#import "TermDevice.h"
#import <UserNotifications/UserNotifications.h>

#define FONT_SIZE_FIELD_TAG 2001
#define FONT_SIZE_STEPPER_TAG 2002
#define EXTERNAL_DISPLAY_FONT_SIZE_FIELD_TAG 2021
#define EXTERNAL_DISPLAY_FONT_SIZE_STEPPER_TAG 2022

#define CURSOR_BLINK_TAG 2003
#define BOLD_AS_BRIGHT_TAG 2004
#define ENABLE_BOLD_TAG 2006
#define APP_ICON_ALTERNATE_TAG 2007
#define LAYOUT_MODE_TAG 2008
#define OVERSCAN_COMPENSATION_TAG 2009
#define KEYBOARDSTYLE_TAG 2010
#define KEYCASTS_TAG 2011

typedef NS_ENUM(NSInteger, BKAppearanceSections) {
  BKAppearance_Terminal = 0,
    BKAppearance_Themes,
    BKAppearance_Fonts,
    BKAppearance_FontSize,
    BKAppearance_KeyboardAppearance,
    BKAppearance_AppIcon,
    BKAppearance_Layout
};

@interface BKAppearanceViewController () <TermViewDeviceProtocol>

@property (nonatomic, strong) NSIndexPath *selectedFontIndexPath;
@property (nonatomic, strong) NSIndexPath *selectedThemeIndexPath;
@property (weak, nonatomic) UITextField *fontSizeField;
@property (weak, nonatomic) UIStepper *fontSizeStepper;

@property (weak, nonatomic) UITextField *externalDisplayFontSizeField;
@property (weak, nonatomic) UIStepper *externalDisplayFontSizeStepper;

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
  
  UISwitch *_keyCastsSwitch;
  BOOL _keyCastsValue;
  
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
  _termView.userInteractionEnabled = NO;
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
  NSString *selectedThemeName = [BLKDefaults selectedThemeName];
  BKTheme *selectedTheme = [BKTheme withName:selectedThemeName];
  if (selectedTheme != nil) {
    _selectedThemeIndexPath = [NSIndexPath indexPathForRow:[[BKTheme all] indexOfObject:selectedTheme] inSection:BKAppearance_Themes];
  }
  NSString *selectedFontName = [BLKDefaults selectedFontName];
  BKFont *selectedFont = [BKFont withName:selectedFontName];
  if (selectedFont != nil) {
    NSInteger row = [[BKFont all] indexOfObject:selectedFont];
    // User have deleted the font, so we set it back to default
    if (row == NSNotFound) {
      [BLKDefaults setFontName:@"Source Code Pro"]; // TODO get it right
      selectedFontName = [BLKDefaults selectedFontName];
      selectedFont = [BKFont withName:selectedFontName];
      row = [[BKFont all] indexOfObject:selectedFont];
    }
    _selectedFontIndexPath = [NSIndexPath indexPathForRow:row inSection:BKAppearance_Fonts];
  }
  _cursorBlinkValue = [BLKDefaults isCursorBlink];
  _boldAsBrightValue = [BLKDefaults isBoldAsBright];
  _enableBoldValue = [BLKDefaults enableBold];
  _alternateAppIconValue = [BLKDefaults isAlternateAppIcon];
  _defaultLayoutModeValue = BLKDefaults.layoutMode;
  _overscanCompensationValue = BLKDefaults.overscanCompensation;
  _keyboardStyleValue = BLKDefaults.keyboardStyle;
  _keyCastsValue = [BLKDefaults isKeyCastsOn];
}

- (void)saveDefaultValues
{
  if (_fontSizeField.text != nil && ![_fontSizeField.text isEqualToString:@""]) {
    [BLKDefaults setFontSize:[NSNumber numberWithInt:_fontSizeField.text.intValue]];
  }
  if (_selectedFontIndexPath != nil) {
    [BLKDefaults setFontName:[[[BKFont all] objectAtIndex:_selectedFontIndexPath.row] name]];
  }
  if (_selectedThemeIndexPath != nil) {
    [BLKDefaults setThemeName:[[[BKTheme all] objectAtIndex:_selectedThemeIndexPath.row] name]];
  }
  
  _keyboardStyleValue = [self _keyboardStyleFromIndex:_keyboardStyleSegmentedControl.selectedSegmentIndex];
  
  [BLKDefaults setCursorBlink:_cursorBlinkValue];
  [BLKDefaults setBoldAsBright:_boldAsBrightValue];
  [BLKDefaults setAlternateAppIcon:_alternateAppIconValue];
  [BLKDefaults setEnableBold: _enableBoldValue];
  [BLKDefaults setLayoutMode:_defaultLayoutModeValue];
  [BLKDefaults setOversanCompensation:_overscanCompensationValue];
  [BLKDefaults setKeyboardStyle:_keyboardStyleValue];
  [BLKDefaults setKeycasts:_keyCastsValue];

  [BLKDefaults saveDefaults];
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
    return 2;
  } else if (section == BKAppearance_AppIcon) {
    return 1;
  } else if (section == BKAppearance_Layout) {
    return 2;
  } else if (section == BKAppearance_FontSize) {
    return 5;
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
      cellIdentifier = @"externalDisplayFontSizeCell";
    } else if (indexPath.row == 2) {
      cellIdentifier = @"enableBoldCell";
    } else if (indexPath.row == 3) {
      cellIdentifier = @"boldAsBrightCell";
    } else {
      cellIdentifier = @"cursorBlinkCell";
    }
  } else if (section == BKAppearance_KeyboardAppearance) {
    if (indexPath.row == 0) {
      cellIdentifier = @"keyboardStyleCell";
    } else {
      cellIdentifier = @"keycastsCell";
    }
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

- (NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section {
  switch(section) {
  case BKAppearance_Terminal:
    return @"Configuration will be applied to new terminal sessions.";
  case BKAppearance_Layout:
    return @"Configuration will be applied after display reconnect.";
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
  } else if (indexPath.section == BKAppearance_FontSize && indexPath.row == 0) {
    _fontSizeField = [cell viewWithTag:FONT_SIZE_FIELD_TAG];
    _fontSizeStepper = [cell viewWithTag:FONT_SIZE_STEPPER_TAG];
    if ([BLKDefaults selectedFontSize] != nil) {
      [_fontSizeStepper setValue:[BLKDefaults selectedFontSize].integerValue];
      _fontSizeField.text = [NSString stringWithFormat:@"%@ px", [BLKDefaults selectedFontSize]];
    } else {
      _fontSizeField.placeholder = @"";
    }
  } else if (indexPath.section == BKAppearance_FontSize && indexPath.row == 1) {
    _externalDisplayFontSizeField = [cell viewWithTag:EXTERNAL_DISPLAY_FONT_SIZE_FIELD_TAG];
    _externalDisplayFontSizeStepper = [cell viewWithTag:EXTERNAL_DISPLAY_FONT_SIZE_STEPPER_TAG];
    NSNumber *fontSize = [BLKDefaults selectedExternalDisplayFontSize];
    if (fontSize != nil) {
      [_externalDisplayFontSizeStepper setValue:fontSize.integerValue];
      _externalDisplayFontSizeField.text = [NSString stringWithFormat:@"%@ px", fontSize];
    } else {
      _externalDisplayFontSizeField.placeholder = @"";
    }
  } else if (indexPath.section == BKAppearance_FontSize && indexPath.row == 2) {
    _enableBoldSegmentedControl = [cell viewWithTag:ENABLE_BOLD_TAG];
    _enableBoldSegmentedControl.selectedSegmentIndex = _enableBoldValue;
  } else if (indexPath.section == BKAppearance_FontSize && indexPath.row == 3) {
    _boldAsBrightSwitch = [cell viewWithTag:BOLD_AS_BRIGHT_TAG];
    _boldAsBrightSwitch.on = _boldAsBrightValue;
  } else if (indexPath.section == BKAppearance_FontSize && indexPath.row == 4) {
    _cursorBlinkSwitch = [cell viewWithTag:CURSOR_BLINK_TAG];
    _cursorBlinkSwitch.on = _cursorBlinkValue;
  } else if (indexPath.section == BKAppearance_KeyboardAppearance && indexPath.row == 0) {
    _keyboardStyleSegmentedControl = [cell viewWithTag:KEYBOARDSTYLE_TAG];
    _keyboardStyleSegmentedControl.selectedSegmentIndex = [self _keyboardStyleToIndex: _keyboardStyleValue];
  } else if (indexPath.section == BKAppearance_KeyboardAppearance && indexPath.row == 1) {
    _keyCastsSwitch = [cell viewWithTag:KEYCASTS_TAG];
    _keyCastsSwitch.on = _keyCastsValue;
  } else if (indexPath.section == BKAppearance_AppIcon && indexPath.row == 0) {
    _alternateAppIconSwitch = [cell viewWithTag:APP_ICON_ALTERNATE_TAG];
    _alternateAppIconSwitch.on = _alternateAppIconValue;
  } else if (indexPath.section == BKAppearance_Layout && indexPath.row == 0) {
    _defaultLayoutModeSegmentedControl = [cell viewWithTag:LAYOUT_MODE_TAG];
    _defaultLayoutModeSegmentedControl.selectedSegmentIndex = [self _layoutModeToIndex:_defaultLayoutModeValue];
  } else if (indexPath.section == BKAppearance_Layout && indexPath.row == 1) {
    _overscanCompensationSegmentedControl = [cell viewWithTag:OVERSCAN_COMPENSATION_TAG];
    _overscanCompensationSegmentedControl.selectedSegmentIndex = [self _overscanCompensationToIndex:_overscanCompensationValue];
    if ([[DeviceInfo shared] hasAppleSilicon]) {
      [_overscanCompensationSegmentedControl setTitle:@"Stage" forSegmentAtIndex:3];
    }
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
    case BKBKOverscanCompensationMirror:
      return 3;
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
  if (index == 3) {
    return BKBKOverscanCompensationMirror;
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
      [BLKDefaults setThemeName:[theme name]];
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
      [BLKDefaults setFontName:[font name]];
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
  if (sender == _fontSizeStepper) {
    NSNumber *newSize = [NSNumber numberWithInteger:(int)[_fontSizeStepper value]];
    [_termView setFontSize:newSize];
    [_termView setWidth:60];
  } else if (sender == _externalDisplayFontSizeStepper) {
    NSInteger size = (NSInteger)_externalDisplayFontSizeStepper.value;
    [BLKDefaults setExternalDisplayFontSize:@(size)];
    [_externalDisplayFontSizeField setText:[NSString stringWithFormat:@"%@ px", @(size)]];
  }
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
  
  [BLKDefaults applyExternalScreenCompensation:_overscanCompensationValue];
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

- (IBAction)keycastsSwitchChanged:(id)sender
{
  _keyCastsValue = _keyCastsSwitch.on;
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
  [BLKDefaults setFontSize:@(size)];
  _fontSizeStepper.value = size;
  [_fontSizeField setText:[NSString stringWithFormat:@"%@ px", @(size)]];
}

- (void)viewSelectionChanged
{
  
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
