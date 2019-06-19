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

#import "BKPubKeyCreateViewController.h"
#import "BKDefaults.h"
#import "UIDevice+DeviceName.h"

@interface BKPubKeyCreateViewController () <UITextFieldDelegate>
@end

@implementation BKPubKeyCreateViewController {
  UITextField *_nameTextField;
  UITextField *_commentsTextField;
  UIBarButtonItem *_saveBarButtonItem;
  UISegmentedControl *_bitsSegmentedControl;
  UISegmentedControl *_keyTypeSegmentedControl;
  
  NSArray *_sections;
  NSDictionary *_nameSection;
  NSDictionary *_typeSection;
  NSDictionary *_commentsSection;
  NSDictionary *_infoSection;
  
  NSMutableString *_nameFooterText;
  NSArray<NSNumber *> *_bitsValues;
  NSMutableString *_typeFooterText;
  NSArray *_types;
  NSString *_currentType;
}

typedef NS_ENUM(NSInteger, ROW_ID) {
  ROW_ID_NONE,
  ROW_ID_NAME,
  ROW_ID_KEYTYPE,
  ROW_ID_BITS,
  ROW_ID_COMMENTS
};

#define HEADER @"HEADER"
#define FOOTER @"FOOTER"
#define ROWS @"ROWS"

- (void)viewDidLoad
{
  [super viewDidLoad];
  
  _types = [Pki supportedKeyTypes];
  
  _nameFooterText = [[NSMutableString alloc] init];
  _typeFooterText = [[NSMutableString alloc] init];
  
  _nameSection = @{
    HEADER: @"NAME",
    ROWS: @[@(ROW_ID_NAME)],
    FOOTER: _nameFooterText
  };
  _typeSection = @{
    HEADER: @"KEY",
    ROWS: [@[@(ROW_ID_KEYTYPE), @(ROW_ID_BITS)] mutableCopy],
    FOOTER: _typeFooterText
  };
  _commentsSection = @{
    HEADER: @"COMMENTS (OPTIONAL)",
    ROWS: @[@(ROW_ID_COMMENTS)],
    FOOTER: @""
  };
  _infoSection = @{
    HEADER: @"INFORMATION",
    ROWS: @[],
    FOOTER: @"Blink creates PKCS#8 public and private keys, with AES 256 bit encryption. Use \"ssh-copy-id [name]\" to copy the public key to the server."
  };
  
  _keyTypeSegmentedControl = [[UISegmentedControl alloc] initWithItems:_types];
  [_keyTypeSegmentedControl addTarget:self action:@selector(_keyTypeChanged:) forControlEvents:UIControlEventValueChanged];
  _bitsSegmentedControl = [[UISegmentedControl alloc] initWithItems:@[]];

  if (_importMode) {
    _sections = @[_nameSection, _commentsSection, _infoSection];
    [self setKeyType:_key.keyTypeName];
  } else {
    _sections = @[_nameSection, _typeSection, _commentsSection, _infoSection];
    [self setKeyType:BK_KEYTYPE_RSA];
  }
  
  _nameTextField = [[UITextField alloc ] init];
  _nameTextField.placeholder = @"Enter a name for the key";
  _nameTextField.delegate = self;
  [_nameTextField addTarget:self action:@selector(_nameTextFieldChanged:) forControlEvents:UIControlEventEditingChanged];
  _nameTextField.autocorrectionType = UITextAutocorrectionTypeNo;
  _nameTextField.autocapitalizationType = UITextAutocapitalizationTypeNone;
  
  _commentsTextField = [[UITextField alloc] init];
  _commentsTextField.placeholder = @"Comments for you key";
  _commentsTextField.text = _comment ?: [NSString stringWithFormat:@"%@@%@", [BKDefaults defaultUserName] , [UIDevice getInfoTypeFromDeviceName:BKDeviceInfoTypeDeviceName]];

  _saveBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemSave
                                                                     target:self
                                                                     action:@selector(_saveBarButtonAction:)];
  self.navigationItem.rightBarButtonItem = _saveBarButtonItem;
  
  _saveBarButtonItem.enabled = NO;
}

- (void)_saveBarButtonAction:(UIBarButtonItem *)sender {
  NSString *errorMsg;

  if ([BKPubKey withID:_nameTextField.text]) {
    errorMsg = @"Cannot have two keys with the same name.";
  } else {
    if (!_importMode) {
      int bits = 0;
      if (_bitsSegmentedControl.selectedSegmentIndex != NSNotFound) {
        if (_bitsSegmentedControl.selectedSegmentIndex >= 0) {
          bits = [_bitsValues[_bitsSegmentedControl.selectedSegmentIndex] intValue];
        }
      }
      _key = [[Pki alloc] initWithType:_currentType andBits:bits];
    }
    
    _pubkey = [BKPubKey saveCard:_nameTextField.text privateKey:_key.privateKey publicKey:[_key publicKeyWithComment:_commentsTextField.text]];
    
    if (!_pubkey) {
      errorMsg = @"OpenSSL error. Could not create Public Key.";
    }
  }

  if (errorMsg) {
    UIAlertController *alertController = [UIAlertController alertControllerWithTitle:@"Key error" message:errorMsg preferredStyle:UIAlertControllerStyleAlert];
    UIAlertAction *ok = [UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil];
    [alertController addAction:ok];
    [self presentViewController:alertController animated:YES completion:nil];
    return;
  }

  [_createKeyDelegate viewControllerDidCreateKey:self];
}

- (void)setKeyType:(const NSString *)type {
  _currentType = [type copy];
  [_nameFooterText replaceCharactersInRange:NSMakeRange(0, _nameFooterText.length)
                                 withString:[NSString stringWithFormat:@"Default key must be named 'id_%@'", [type lowercaseString]]];
  
  NSMutableArray *rows = _typeSection[ROWS];
  [rows removeAllObjects];
  [rows addObject:@(ROW_ID_KEYTYPE)];
  
  NSString *footerText = @"";
  if ([BK_KEYTYPE_RSA isEqual:type]) {
    _bitsValues = @[@(2048), @(4096)];
    [rows addObject:@(ROW_ID_BITS)];
    footerText = @"Generally, 2048 bits is considered sufficient.";
  } else if ([BK_KEYTYPE_DSA isEqual:type]) {
    _bitsValues = @[@(1024)];
    footerText = @"DSA keys must be exactly 1024 bits as specified by FIPS 186-2.";
  } else if ([BK_KEYTYPE_ECDSA isEqual:type]) {
    _bitsValues = @[@(256), @(384), @(521)];
    [rows addObject:@(ROW_ID_BITS)];
    footerText = @"For ECDSA keys size determines key length by selecting from one of three elliptic curve sizes: 256, 384 or 521 bits.";
  } else if ([BK_KEYTYPE_Ed25519 isEqual:type]) {
    _bitsValues = @[];
    footerText = @"Ed25519 keys have a fixed length.";
  }
  
  [_typeFooterText replaceCharactersInRange:NSMakeRange(0, _typeFooterText.length)
                                 withString:footerText];
  _keyTypeSegmentedControl.selectedSegmentIndex = [_types indexOfObject:type];
  [self setupBitsControl];
  
  self.title = [NSString stringWithFormat:@"%@ %@ Key", _importMode ? @"Import" : @"New", type];
}

- (void)_keyTypeChanged: (UISegmentedControl *)control {
  NSString *type = _types[control.selectedSegmentIndex];
  if ([type isEqualToString:_currentType]) {
    return;
  }
  [self setKeyType:type];
  NSMutableIndexSet *indexSet = [[NSMutableIndexSet alloc] init];
  [indexSet addIndex:0];
  [indexSet addIndex:1];
  
  [self.tableView reloadData];
}

- (void)setupBitsControl {
  [_bitsSegmentedControl removeAllSegments];
  int n = 0;
  for (NSNumber *bits in _bitsValues) {
    [_bitsSegmentedControl insertSegmentWithTitle:[bits stringValue] atIndex:n++ animated:YES];
  }
  _bitsSegmentedControl.selectedSegmentIndex = _bitsValues.count - 1;
}


- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
  NSDictionary *section = _sections[indexPath.section];
  
  NSArray *rows = section[ROWS];
  if (!rows) {
    return [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@""];
  }
  
  NSNumber *nsRowId = rows[indexPath.row];
  NSString *cellId = [nsRowId.stringValue stringByAppendingString:@"_cell_id"];

  UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:cellId];
  
  if (cell == nil) {
    cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:cellId];
  }
  
  ROW_ID rowID = nsRowId.integerValue;
  
  switch (rowID) {
    case ROW_ID_NAME:
      [cell.contentView addSubview:_nameTextField];
      break;
    case ROW_ID_KEYTYPE:
      cell.textLabel.text = @"Type";
      cell.accessoryView = _keyTypeSegmentedControl;
      break;
    case ROW_ID_BITS:
      cell.textLabel.text = @"Bits";
      cell.accessoryView = _bitsSegmentedControl;
      break;
    case ROW_ID_COMMENTS:
      [cell.contentView addSubview:_commentsTextField];
      break;
    default:
      break;
  }
  
  return cell;
}

- (void)viewDidLayoutSubviews {
  [super viewDidLayoutSubviews];
  [self _positionTextField:_nameTextField];
  [self _positionTextField:_commentsTextField];
}

- (void)_positionTextField:(UITextField *)textField {
  
  UITableViewCell *cell = (UITableViewCell *)textField.superview.superview;
  CGRect rect = cell.bounds;
  rect = UIEdgeInsetsInsetRect(rect, cell.layoutMargins);
  
  textField.frame = rect;
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
  return [_sections count];
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
  NSDictionary *sectionInfo = _sections[section];
  return [sectionInfo[ROWS] count];
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
  return _sections[section][HEADER];
}

- (NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section {
  return _sections[section][FOOTER];
}

- (void)_nameTextFieldChanged:(id)sender
{
  _saveBarButtonItem.enabled = _nameTextField.text.length > 0;
}

- (BOOL)textField:(UITextField *)textField shouldChangeCharactersInRange:(NSRange)range replacementString:(NSString *)string
{
  if (_nameTextField == textField) {
    if ([string isEqualToString:@" "]) {
      return NO;
    }
  }

  return YES;
}

- (BOOL)tableView:(UITableView *)tableView shouldHighlightRowAtIndexPath:(NSIndexPath *)indexPath {
  return NO;
}

@end
