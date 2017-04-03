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

#import <CommonCrypto/CommonDigest.h>

#import "BKPubKey.h"
#import "BKPubKeyCreateViewController.h"
#import "BKPubKeyDetailsViewController.h"
#import "BKPubKeyViewController.h"
#import "BKPubKeyQRScanViewController.h"

@interface BKPubKeyViewController ()

@end

@implementation BKPubKeyViewController {
  NSString *_clipboardPassphrase;
  SshRsa *_clipboardKey;
  BOOL _selectable;
}

- (void)viewDidLoad
{
  [super viewDidLoad];
}

- (void)viewWillDisappear:(BOOL)animated
{
  if ([self.navigationController.viewControllers indexOfObject:self] == NSNotFound) {
    [self performSegueWithIdentifier:@"unwindFromKeys" sender:self];
  }
  [super viewWillDisappear:animated];
}

- (void)didReceiveMemoryWarning
{
  [super didReceiveMemoryWarning];
  // Dispose of any resources that can be recreated.
}

#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
  return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
  return _selectable ? BKPubKey.count + 1 : BKPubKey.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
  UITableViewCell *cell;

  if (_selectable && indexPath.row == 0) {
    cell = [tableView dequeueReusableCellWithIdentifier:@"None" forIndexPath:indexPath];
  } else {
    NSInteger pkIdx = _selectable ? indexPath.row - 1 : indexPath.row;
    cell = [tableView dequeueReusableCellWithIdentifier:@"Cell" forIndexPath:indexPath];
    BKPubKey *pk = [BKPubKey.all objectAtIndex:pkIdx];

    // Configure the cell...
    cell.textLabel.text = pk.ID;
    if ([cell.textLabel.text isEqual:@"id_rsa"]) {
      cell.detailTextLabel.text = [NSString stringWithFormat:@"Default Key - %@", [self fingerprint:pk.publicKey]];
    } else {
      cell.detailTextLabel.text = [self fingerprint:pk.publicKey];
    }
  }

  if (_selectable) {
    if (_currentSelectionIdx == indexPath) {
      [cell setAccessoryType:UITableViewCellAccessoryCheckmark];
    } else {
      [cell setAccessoryType:UITableViewCellAccessoryNone];
    }
  }

  return cell;
}

- (NSString *)fingerprint:(NSString *)publicKey
{
  const char *str = [publicKey UTF8String];
  unsigned char result[CC_MD5_DIGEST_LENGTH];
  CC_MD5(str, (CC_LONG)strlen(str), result);

  NSMutableString *ret = [NSMutableString stringWithCapacity:CC_MD5_DIGEST_LENGTH * 2];
  for (int i = 0; i < CC_MD5_DIGEST_LENGTH; i++) {
    [ret appendFormat:@"%02x:", result[i]];
  }
  [ret deleteCharactersInRange:NSMakeRange([ret length] - 1, 1)];
  return ret;
}

- (UITableViewCellEditingStyle)tableView:(UITableView *)tableView editingStyleForRowAtIndexPath:(NSIndexPath *)indexPath
{
  return _selectable ? UITableViewCellEditingStyleNone : UITableViewCellEditingStyleDelete;
}

- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath
{
  if (editingStyle == UITableViewCellEditingStyleDelete) {
    // Remove BKPubKey
    [BKPubKey.all removeObjectAtIndex:indexPath.row];
    [self.tableView deleteRowsAtIndexPaths:@[ indexPath ] withRowAnimation:true];
    [BKPubKey saveIDS];
    [self.tableView reloadData];
  }
}

- (IBAction)addKey:(id)sender
{
  UIAlertController *keySourceController = [UIAlertController alertControllerWithTitle:@"" message:@"" preferredStyle:UIAlertControllerStyleActionSheet];
  UIAlertAction *generate = [UIAlertAction actionWithTitle:@"Create New"
                                                     style:UIAlertActionStyleDefault
                                                   handler:^(UIAlertAction *_Nonnull action) {
                                                     _clipboardKey = nil;
                                                     [self performSegueWithIdentifier:@"createKeySegue" sender:sender];
                                                   }];
  UIAlertAction *import = [UIAlertAction actionWithTitle:@"Import from clipboard"
                                                   style:UIAlertActionStyleDefault
                                                 handler:^(UIAlertAction *_Nonnull action) {
                                                   // ImportKey flow
                                                   [self importKeyFromClipboard];

                                                   if (_clipboardKey) {
                                                     [self performSegueWithIdentifier:@"createKeySegue" sender:sender];
                                                   }
                                                 }];
  UIAlertAction *scanQR = [UIAlertAction actionWithTitle:@"Scan QR code"
                                                     style:UIAlertActionStyleDefault
                                                   handler:^(UIAlertAction *_Nonnull action) {
                                                       // ImportKey flow
                                                       NSLog(@"Scan QR!");
//                                                       [self importKey];
                                                       [self performSegueWithIdentifier:@"scanQRKeySegue" sender:sender];
                                                   }];
  UIAlertAction *cancel = [UIAlertAction actionWithTitle:@"Cancel"
                                                   style:UIAlertActionStyleCancel
                                                 handler:^(UIAlertAction *_Nonnull action){
                                                   //
                                                 }];

  [keySourceController addAction:generate];
  [keySourceController addAction:import];
  [keySourceController addAction:scanQR];
  [keySourceController addAction:cancel];
  [[keySourceController popoverPresentationController] setBarButtonItem:sender];
  [self presentViewController:keySourceController animated:YES completion:nil];
}

- (void)importKeyFromClipboard
{
    // Check if key is encrypted.
    UIPasteboard *pb = [UIPasteboard generalPasteboard];
    NSString *pbkey = pb.string;
    [self importKey:pbkey];
}

- (void)importKey:(NSString *)pbkey
{

  // Ask for passphrase if it is encrypted.
  if (([pbkey rangeOfString:@"ENCRYPTED"
                    options:NSRegularExpressionSearch]
         .location != NSNotFound)) {
    UIAlertController *passphraseRequest = [UIAlertController alertControllerWithTitle:@"Encrypted key"
                                                                               message:@"Please insert passphrase"
                                                                        preferredStyle:UIAlertControllerStyleAlert];
    [passphraseRequest addTextFieldWithConfigurationHandler:^(UITextField *textField) {
      textField.placeholder = NSLocalizedString(@"Enter passphrase", @"Passphrase");
      textField.secureTextEntry = YES;
    }];
    UIAlertAction *ok = [UIAlertAction actionWithTitle:@"OK"
                                                 style:UIAlertActionStyleDefault
                                               handler:^(UIAlertAction *_Nonnull action) {
                                                 // Create a key
                                                 UITextField *passphrase = passphraseRequest.textFields.lastObject;
                                                 SshRsa *key = [[SshRsa alloc] initFromPrivateKey:pbkey passphrase:passphrase.text];
                                                 if (key == nil) {
                                                   // Retry
                                                     [self importKey:pbkey];
                                                 } else {
                                                   _clipboardKey = key;
                                                   _clipboardPassphrase = passphrase.text;
                                                   [self performSegueWithIdentifier:@"createKeySegue" sender:passphraseRequest];
                                                 }
                                               }];
    UIAlertAction *cancel = [UIAlertAction actionWithTitle:@"Cancel"
                                                     style:UIAlertActionStyleCancel
                                                   handler:^(UIAlertAction *_Nonnull action){
                                                   }];
    [passphraseRequest addAction:ok];
    [passphraseRequest addAction:cancel];
    [self presentViewController:passphraseRequest animated:YES completion:nil];

  } else {
    // If the key isn't encrypted, then try to generate it and go to the create key dialog to complete
    SshRsa *key = [[SshRsa alloc] initFromPrivateKey:pbkey passphrase:nil];

    if (key == nil) {
      UIAlertView *errorAlert = [[UIAlertView alloc]
            initWithTitle:@"Invalid Key"
                  message:@"Clipboard content couldn't be validated as a key"
                 delegate:nil
        cancelButtonTitle:@"OK"
        otherButtonTitles:nil];
      [errorAlert show];
    } else {
      _clipboardKey = key;
      _clipboardPassphrase = nil;
    }
  }
}

#pragma mark - Navigation

// In a storyboard-based application, you will often want to do a little preparation before navigation
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender
{
  // Get the new view controller using [segue destinationViewController].
  // Pass the selected object to the new view controller.
  if ([[segue identifier] isEqualToString:@"keyInfoSegue"]) {
    BKPubKeyDetailsViewController *details = segue.destinationViewController;

    BKPubKey *pubkey = [BKPubKey.all objectAtIndex:_currentSelectionIdx.row];
    details.pubkey = pubkey;
    return;
  }
  if ([[segue identifier] isEqualToString:@"createKeySegue"]) {
    BKPubKeyCreateViewController *create = segue.destinationViewController;

    if (_clipboardKey) {
      create.key = _clipboardKey;
      create.passphrase = _clipboardPassphrase;
    }

    return;
  }
  if ([[segue identifier] isEqualToString:@"scanQRKeySegue"]) {
    BKPubKeyQRScanViewController * scan = segue.destinationViewController;
    [scan setDelegate:self];
    return;
  }
}

- (IBAction)unwindFromCreate:(UIStoryboardSegue *)sender
{
  NSIndexPath *newIdx;
  if (_selectable) {
    newIdx = [NSIndexPath indexPathForRow:BKPubKey.count inSection:0];
  } else {
    newIdx = [NSIndexPath indexPathForRow:(BKPubKey.count - 1) inSection:0];
  }
  [self.tableView insertRowsAtIndexPaths:@[ newIdx ] withRowAnimation:UITableViewRowAnimationBottom];
}

- (IBAction)unwindFromDetails:(UIStoryboardSegue *)sender
{
  //NSIndexPath *selection = [self.tableView indexPathForSelectedRow];
  [self.tableView reloadRowsAtIndexPaths:@[ _currentSelectionIdx ] withRowAnimation:UITableViewRowAnimationNone];
}

// TODO: Maybe we should call it "markable", because the selection still exists and it is important.
#pragma mark - Selectable
- (void)makeSelectable:(BOOL)selectable initialSelection:(NSString *)selectionID
{
  _selectable = selectable;

  if (_selectable) {
    // Object as initial selection.
    // Guess the indexPath
    NSInteger pos;
    if (selectionID.length) {
      if ([BKPubKey withID:selectionID]) {
        pos = [BKPubKey.all indexOfObject:[BKPubKey withID:selectionID]];
        pos += 1; //To accomodate "None" value
      } else {
        pos = 0;
      }
    } else {
      pos = 0;
    }
    _currentSelectionIdx = [NSIndexPath indexPathForRow:pos inSection:0];
  }
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
  if (_selectable && _currentSelectionIdx != nil) {
    // When in selectable mode, do not show details.
    [[tableView cellForRowAtIndexPath:_currentSelectionIdx] setAccessoryType:UITableViewCellAccessoryNone];
  }
  _currentSelectionIdx = indexPath;

  [tableView deselectRowAtIndexPath:indexPath animated:YES];

  if (_selectable) {
    [[tableView cellForRowAtIndexPath:indexPath] setAccessoryType:UITableViewCellAccessoryCheckmark];
  } else {
    // Show details if not selectable
    [self showKeyInfo:indexPath];
  }
}

- (id)selectedObject
{
  if (_currentSelectionIdx.row == 0) {
    return 0;
  }
  return _selectable ? BKPubKey.all[_currentSelectionIdx.row - 1] : BKPubKey.all[_currentSelectionIdx.row];
}

- (void)showKeyInfo:(NSIndexPath *)indexPath
{
  [self performSegueWithIdentifier:@"keyInfoSegue" sender:self];
}

@end
