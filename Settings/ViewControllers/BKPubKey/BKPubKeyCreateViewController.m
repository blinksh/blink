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

#import "BKPubKeyCreateViewController.h"

@interface BKPubKeyCreateViewController () <UITextFieldDelegate>

@property (weak, nonatomic) IBOutlet UITextField *nameField;
@property (weak, nonatomic) IBOutlet UISegmentedControl *sizeField;
@property (weak, nonatomic) IBOutlet UITextField *passphraseField;
@property (weak, nonatomic) IBOutlet UITextField *repassphraseField;
@property (weak, nonatomic) IBOutlet UIBarButtonItem *createButton;

@end

@implementation BKPubKeyCreateViewController

- (void)viewDidLoad
{
  [super viewDidLoad];
  _nameField.delegate = self;
  if (_key) {
    _nameField.text = @"Name your key";
    _passphraseField.text = _passphrase;
    _repassphraseField.text = _passphrase;
    _sizeField.userInteractionEnabled = NO;
  }
}

- (IBAction)editChanged:(id)sender
{
  if (_nameField.text.length) {
    _createButton.enabled = YES;
  } else {
    _createButton.enabled = NO;
  }
}

- (void)didReceiveMemoryWarning
{
  [super didReceiveMemoryWarning];
  // Dispose of any resources that can be recreated.
}

- (BOOL)textField:(UITextField *)textField shouldChangeCharactersInRange:(NSRange)range replacementString:(NSString *)string
{
  if (textField == _nameField) {
    if ([string isEqualToString:@" "]) {
      return NO;
    }
  }

  return YES;
}

#pragma mark - Navigation

- (BOOL)shouldPerformSegueWithIdentifier:(NSString *)identifier sender:(id)sender
{
  NSString *errorMsg;
  if ([identifier isEqualToString:@"unwindFromCreate"]) {
    if ([BKPubKey withID:_nameField.text]) {
      errorMsg = @"Cannot have two keys with the same name.";
    } else if ([_nameField.text rangeOfCharacterFromSet:[NSCharacterSet whitespaceCharacterSet]].location != NSNotFound) {
      errorMsg = @"Spaces are not permitted in the name.";
    } else if (_passphraseField.text.length && ![_passphraseField.text isEqualToString:_repassphraseField.text]) {
      errorMsg = @"Passphrases do not match";
    } else {
      // Try to create the key
      NSInteger selectedIndex = [_sizeField selectedSegmentIndex];
      int length = [[_sizeField titleForSegmentAtIndex:selectedIndex] intValue];
      // Create and return
      SshRsa *key = _key ? _key : [[SshRsa alloc] initWithLength:length];
      _pubkey = [BKPubKey saveCard:_nameField.text privateKey:[key privateKeyWithPassphrase:_passphraseField.text] publicKey:[key publicKey]];
      if (!_pubkey) {
        errorMsg = @"OpenSSL error. Could not create Public Key.";
      }
    }

    if (errorMsg) {
      UIAlertController *alertController = [UIAlertController alertControllerWithTitle:@"Key error" message:errorMsg preferredStyle:UIAlertControllerStyleAlert];
      UIAlertAction *ok = [UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil];
      [alertController addAction:ok];
      [self presentViewController:alertController animated:YES completion:nil];
      return NO;
    }
  }
  return YES;
}

@end
