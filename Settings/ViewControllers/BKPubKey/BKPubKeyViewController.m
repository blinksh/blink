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

#import <CommonCrypto/CommonDigest.h>
#import <MobileCoreServices/MobileCoreServices.h>

#import "BKPubKey.h"
#import "BKPubKeyCreateViewController.h"
#import "BKPubKeyDetailsViewController.h"
#import "BKPubKeyViewController.h"
#import "Blink-Swift.h"


@interface BKPubKeyViewController () <BKPubKeyCreateViewControllerDelegate, UIDocumentPickerDelegate>

@end

enum SshKeyImportOrigin {
  FROM_CLIPBOARD,
  FROM_FILE,
};


@implementation BKPubKeyViewController {
  BOOL _selectable;
}

/*!
 @brief Given a NSString import the key in the secure enclave
 @param keyString NSString containing the key to import
 @param importOrigin SshKeyImportOrigin origin of they key that's being imported
*/
- (void) _importKeyFromString: (NSString *)keyString importOrigin:(enum SshKeyImportOrigin) importOrigin {
  
  NSString *errorImportingKeyMessage = @"%origin% content couldn't be validated as a key";
  
  switch (importOrigin) {
    
    case FROM_CLIPBOARD:
      errorImportingKeyMessage = [errorImportingKeyMessage stringByReplacingOccurrencesOfString:@"%origin%" withString:@"Clipboard"];
      break;
    case FROM_FILE:
      errorImportingKeyMessage = [errorImportingKeyMessage stringByReplacingOccurrencesOfString:@"%origin%" withString:@"File"];
      break;
  }
  
  if ([keyString length] == 0) {
    UIAlertController *alertCtrl = [UIAlertController
                                    alertControllerWithTitle:@"Invalid key"
                                    message: errorImportingKeyMessage
                                    preferredStyle:UIAlertControllerStyleAlert];
    [alertCtrl addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];
    
    [self presentViewController:alertCtrl animated:YES completion:nil];
    return;
  }
  
  if (![keyString hasSuffix:@"\n"]) {
    keyString = [keyString stringByAppendingString:@"\n"];
  }
  
  [Pki importPrivateKey:keyString controller:self andCallback:^(Pki *key, NSString *comment) {
    if (key == nil) {
      UIAlertController *alertCtrl = [UIAlertController
                                      alertControllerWithTitle:@"Invalid key"
                                      message:errorImportingKeyMessage
                                      preferredStyle:UIAlertControllerStyleAlert];
      [alertCtrl addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];
      
      [self presentViewController:alertCtrl animated:YES completion:nil];
      return;
    }
    
    BKPubKeyCreateViewController *ctrl = [[BKPubKeyCreateViewController alloc] initWithStyle:UITableViewStyleGrouped];
    ctrl.importMode = YES;
    ctrl.key = key;
    ctrl.comment = comment;
    ctrl.createKeyDelegate = self;
    [self.navigationController pushViewController:ctrl animated:YES];
  }];
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
    [[LocalAuth shared] authenticateWithCallback:^(BOOL success) {
      if (success) {
        // Remove BKPubKey
        [BKPubKey.all removeObjectAtIndex:indexPath.row];
        [self.tableView deleteRowsAtIndexPaths:@[ indexPath ] withRowAnimation:true];
        [BKPubKey saveIDS];
        [self.tableView reloadData];
      }
    } reason:@"to delete key."];
  }
}

- (IBAction)addKey:(id)sender
{
  UIAlertController *keySourceController = [UIAlertController alertControllerWithTitle:@"" message:@"" preferredStyle:UIAlertControllerStyleActionSheet];
  UIAlertAction *generate = [UIAlertAction actionWithTitle:@"Create New"
                                                     style:UIAlertActionStyleDefault
                                                   handler:^(UIAlertAction *_Nonnull action) {
                                                     [self createKey];
                                                   }];
  UIAlertAction *importFromClipboard = [UIAlertAction actionWithTitle:@"Import from clipboard"
                                                   style:UIAlertActionStyleDefault
                                                 handler:^(UIAlertAction *_Nonnull action) {
                                                   // ImportKey flow
                                                   [self importKeyFromClipboard];
                                                 }];
  
  UIAlertAction *importFromFiles = [UIAlertAction actionWithTitle:@"Import from a file"
                                                   style:UIAlertActionStyleDefault
                                                 handler:^(UIAlertAction *_Nonnull action) {
                                                   // ImportKey flow
    [self importKeyFromFile];
    
                                                 }];
  
  
  UIAlertAction *cancel = [UIAlertAction actionWithTitle:@"Cancel"
                                                   style:UIAlertActionStyleCancel
                                                 handler:^(UIAlertAction *_Nonnull action){
                                                   //
                                                 }];

  [keySourceController addAction:generate];
  [keySourceController addAction:importFromClipboard];
  [keySourceController addAction:importFromFiles];
  [keySourceController addAction:cancel];
  [[keySourceController popoverPresentationController] setBarButtonItem:sender];
  [self presentViewController:keySourceController animated:YES completion:nil];
}

- (void)createKey {
  BKPubKeyCreateViewController *ctrl = [[BKPubKeyCreateViewController alloc] initWithStyle:UITableViewStyleGrouped];
  ctrl.createKeyDelegate = self;
  [self.navigationController pushViewController:ctrl animated:YES];
}

/*!
 @brief Call to open UIDocumentPicker so the user select the file that contains a key to be imported into the Secure Enclave
*/
- (void) importKeyFromFile {
  
  UIDocumentPickerViewController *documentPicker = [[UIDocumentPickerViewController alloc] initWithDocumentTypes:@[@"public.data", @"public.item", (NSString *)kUTTypeText] inMode:UIDocumentPickerModeOpen];
  documentPicker.allowsMultipleSelection = true;
  documentPicker.delegate = self;
  
  [self presentViewController:documentPicker animated:true completion:nil];
  
}

/*!
 @brief Import a key into the Secure Enclave getting the content from the clipboard
*/
- (void)importKeyFromClipboard {
  
  NSString *keyString = [UIPasteboard generalPasteboard].string;
  
  [self _importKeyFromString:keyString importOrigin:(FROM_CLIPBOARD)];
}

- (void)viewControllerDidCreateKey:(BKPubKeyCreateViewController *)controller {
  [self.navigationController popViewControllerAnimated:YES];
  NSIndexPath *newIdx;
  if (_selectable) {
    newIdx = [NSIndexPath indexPathForRow:BKPubKey.count inSection:0];
  } else {
    newIdx = [NSIndexPath indexPathForRow:(BKPubKey.count - 1) inSection:0];
  }
  [self.tableView insertRowsAtIndexPaths:@[ newIdx ] withRowAnimation:UITableViewRowAnimationBottom];
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

#pragma mark - UIDocumentPickerDelegate

- (void)documentPickerWasCancelled:(UIDocumentPickerViewController *)controller {
  
  
}

- (void)documentPicker:(UIDocumentPickerViewController *)controller didPickDocumentsAtURLs:(NSArray<NSURL *> *)urls {
  
  for (NSURL *fileUrl in urls) {
    
    NSString *keyString = [NSString stringWithContentsOfURL:fileUrl encoding:NSUTF8StringEncoding error:NULL];

    [self _importKeyFromString:keyString importOrigin:(FROM_FILE)];
  }
}

@end
