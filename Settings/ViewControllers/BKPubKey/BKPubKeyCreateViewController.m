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
  NSDictionary *_footerSection;
  
  NSMutableString *_nameFooterText;
  NSArray<NSNumber *> *_bitsValues;
  NSMutableString *_typeFooterText;
  NSArray *_types;
  NSString *_currentType;
}

- (void)viewDidLoad
{
  [super viewDidLoad];
  
  _types = @[@"RSA", @"ECDSA", @"Ed25519"];
  
  _nameFooterText = [[NSMutableString alloc] init];
  _typeFooterText = [[NSMutableString alloc] init];
  
  _nameSection = @{@"header": @"NAME", @"footer":_nameFooterText, @"rows": @[@"_nameTextField"]};
  _typeSection = @{@"header": @"KEY", @"footer":_typeFooterText, @"rows": [@[@"_keyTypeSegmentedControl", @"_bitsSegmentedControl"] mutableCopy]};
  _commentsSection = @{@"header": @"COMMENTS (OPTIONAL)", @"footer":@"", @"rows": @[@"_commentsTextField"]};
  _footerSection = @{@"header": @"INFORMATION", @"footer":@"Blink creates PKCS#8 public and private keys, with AES 256 bit encryption. Use \"ssh-copy-id [name]\" to copy the public key to the server.", @"rows": @[]};
  
  _keyTypeSegmentedControl = [[UISegmentedControl alloc] initWithItems:_types];
  [_keyTypeSegmentedControl addTarget:self action:@selector(_keyTypeChanged:) forControlEvents:UIControlEventValueChanged];
  _bitsSegmentedControl = [[UISegmentedControl alloc] initWithItems:@[]];

  if (_importMode) {
    _sections = @[_nameSection, _commentsSection, _footerSection];
    [self setKeyType:_key.keyTypeName];
  } else {
    _sections = @[_nameSection, _typeSection, _commentsSection, _footerSection];
    [self setKeyType:@"RSA"];
  }
  
  _nameTextField = [[UITextField alloc ] init];
  _nameTextField.placeholder = @"Enter a name for the key";
  _nameTextField.delegate = self;
  [_nameTextField addTarget:self action:@selector(_nameTextFieldChanged:) forControlEvents:UIControlEventEditingChanged];
  
  _commentsTextField = [[UITextField alloc] init];
  _commentsTextField.placeholder = @"Comments for you key";
  _commentsTextField.text = [NSString stringWithFormat:@"%@@%@", [BKDefaults defaultUserName] , [UIDevice getInfoTypeFromDeviceName:BKDeviceInfoTypeDeviceName]];

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

- (void)setKeyType:(NSString *)type {
  _currentType = type;
  [_nameFooterText replaceCharactersInRange:NSMakeRange(0, _nameFooterText.length)
                                 withString:[NSString stringWithFormat:@"Default key must be named 'id_%@'", [type lowercaseString]]];
  
  NSMutableArray *rows = _typeSection[@"rows"];
  [rows removeAllObjects];
  [rows addObject:@"_keyTypeSegmentedControl"];
  
  if ([type isEqualToString:@"RSA"]) {
    _bitsValues = @[@(2048), @(4096)];
    [rows addObject:@"_bitsSegmentedControl"];
    [_typeFooterText replaceCharactersInRange:NSMakeRange(0, _typeFooterText.length)
                                   withString:@"Generally, 2048 bits is considered sufficient."];
  } else if ([type isEqualToString:@"ECDSA"]) {
    _bitsValues = @[@(256), @(384), @(521)];
    [rows addObject:@"_bitsSegmentedControl"];
    [_typeFooterText replaceCharactersInRange:NSMakeRange(0, _typeFooterText.length)
                                   withString:@"For ECDSA keys size determines key length by selecting from one of three elliptic curve sizes: 256, 384 or 521 bits."];
  } else if ([type isEqualToString:@"Ed25519"]) {
    _bitsValues = @[];
    [_typeFooterText replaceCharactersInRange:NSMakeRange(0, _typeFooterText.length)
                                   withString:@"Ed25519 keys have a fixed length."];
  }
  
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
  
  NSArray *rows = section[@"rows"];
  if (!rows) {
    return [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@""];
  }
  
  NSString *row = rows[indexPath.row];

  UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:row];
  
  if (cell == nil) {
    cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:row];
  }
  
  if ([row isEqualToString:@"_nameTextField"]) {
    [cell.contentView addSubview:_nameTextField];
  } else if ([row isEqualToString:@"_keyTypeSegmentedControl"]) {
    cell.textLabel.text = @"Type";
    cell.accessoryView = _keyTypeSegmentedControl;
  } else if ([row isEqualToString:@"_bitsSegmentedControl"]) {
    cell.textLabel.text = @"Bits";
    cell.accessoryView = _bitsSegmentedControl;
  } else if ([row isEqualToString:@"_commentsTextField"]) {
    [cell.contentView addSubview:_commentsTextField];
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
  return [sectionInfo[@"rows"] count];
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
  return _sections[section][@"header"];
}

- (NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section {
  return _sections[section][@"footer"];
}

- (void)_nameTextFieldChanged:(id)sender
{
  _saveBarButtonItem.enabled = _nameTextField.text.length > 0;
}


- (void)editChanged:(id)sender
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

- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath {
  return NO;
}

#pragma mark - Navigation

- (BOOL)shouldPerformSegueWithIdentifier:(NSString *)identifier sender:(id)sender
{
  NSString *errorMsg;
  if ([identifier isEqualToString:@"unwindFromCreate"]) {
//    if ([BKPubKey withID:_nameField.text]) {
//      errorMsg = @"Cannot have two keys with the same name.";
//    } else if ([_nameField.text rangeOfCharacterFromSet:[NSCharacterSet whitespaceCharacterSet]].location != NSNotFound) {
//      errorMsg = @"Spaces are not permitted in the name.";
//    } else if (_passphraseField.text.length && ![_passphraseField.text isEqualToString:_repassphraseField.text]) {
//      errorMsg = @"Passphrases do not match";
//    } else {
//      // Try to create the key
//      NSInteger selectedIndex = [_sizeField selectedSegmentIndex];
//      int length = [[_sizeField titleForSegmentAtIndex:selectedIndex] intValue];
//      // Create and return
//      Pki *key = _key ? _key : [[Pki alloc] initRSAWithLength:length];
//      // saves the key into iOS keychain
//      _pubkey = [BKPubKey saveCard:_nameField.text privateKey:key.privateKey publicKey:[key publicKeyWithComment:_commentsField.text]];
//      if (!_pubkey) {
//        errorMsg = @"OpenSSL error. Could not create Public Key.";
//      }
//    }
//
//    if (errorMsg) {
//      UIAlertController *alertController = [UIAlertController alertControllerWithTitle:@"Key error" message:errorMsg preferredStyle:UIAlertControllerStyleAlert];
//      UIAlertAction *ok = [UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil];
//      [alertController addAction:ok];
//      [self presentViewController:alertController animated:YES completion:nil];
//      return NO;
//    }
  }
  return YES;
}

@end
