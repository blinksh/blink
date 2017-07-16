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

#import "BKThemeCreateViewController.h"
#import "BKSettingsFileDownloader.h"
#import "BKTheme.h"
#import "BKLinkActions.h"


@interface BKThemeCreateViewController ()

@property (weak, nonatomic) IBOutlet UIButton *importButton;
@property (weak, nonatomic) IBOutlet UITextField *urlTextField;
@property (weak, nonatomic) IBOutlet UITextField *nameTextField;
@property (weak, nonatomic) IBOutlet UITableViewCell *galleryLinkCell;
@property (strong, nonatomic) NSData *tempFileData;
@property (assign, nonatomic) BOOL downloadCompleted;

@end

@implementation BKThemeCreateViewController

- (void)viewDidLoad
{
  [super viewDidLoad];

  // Uncomment the following line to preserve selection between presentations.
  // self.clearsSelectionOnViewWillAppear = NO;

  // Uncomment the following line to display an Edit button in the navigation bar for this view controller.
  // self.navigationItem.rightBarButtonItem = self.editButtonItem;
}

- (void)viewWillDisappear:(BOOL)animated
{
  if ([self.navigationController.viewControllers indexOfObject:self] == NSNotFound) {
    [self performSegueWithIdentifier:@"unwindFromAddTheme" sender:self];
    [BKSettingsFileDownloader cancelRunningDownloads];
    [UIApplication sharedApplication].networkActivityIndicatorVisible = NO;
  }
  [super viewWillDisappear:animated];
}

- (void)didReceiveMemoryWarning
{
  [super didReceiveMemoryWarning];
  // Dispose of any resources that can be recreated.
}

#pragma mark - Validations

- (IBAction)urlTextDidChange:(id)sender
{
  NSURL *url = [NSURL URLWithString:_urlTextField.text];
  if (url && url.scheme && url.host) {
    self.importButton.enabled = YES;
  } else {
    self.importButton.enabled = NO;
  }
}

- (IBAction)nameFieldDidChange:(id)sender
{
  if (self.nameTextField.text.length > 0 && _downloadCompleted) {
    self.navigationItem.rightBarButtonItem.enabled = YES;
  } else {
    self.navigationItem.rightBarButtonItem.enabled = NO;
  }
}


- (IBAction)importButtonClicked:(id)sender
{
  NSString *themeUrl = _urlTextField.text;
  if (themeUrl.length > 4 && [[themeUrl substringFromIndex:[themeUrl length] - 3] isEqualToString:@".js"]) {
    if ([themeUrl rangeOfString:@"github.com"].location != NSNotFound && [themeUrl rangeOfString:@"/raw/"].location == NSNotFound) {
      // Replace HTML versions of themes with the raw version
      themeUrl = [themeUrl stringByReplacingOccurrencesOfString:@"/blob/" withString:@"/raw/"];
    }
    [UIApplication sharedApplication].networkActivityIndicatorVisible = YES;
    self.urlTextField.enabled = NO;
    [self configureImportButtonForCancel];
    [BKSettingsFileDownloader downloadFileAtUrl:themeUrl
			       expectedMIMETypes:@[@"application/javascript", @"text/plain"]
                          withCompletionHandler:^(NSData *fileData, NSError *error) {
                            if (error == nil) {
                              [self performSelectorOnMainThread:@selector(downloadCompletedWithFilePath:) withObject:fileData waitUntilDone:NO];
                            } else {
                              UIAlertController *alertController = [UIAlertController alertControllerWithTitle:@"Download error" message:error.localizedDescription preferredStyle:UIAlertControllerStyleAlert];
                              UIAlertAction *ok = [UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil];
                              [alertController addAction:ok];
                              dispatch_async(dispatch_get_main_queue(), ^{
                                [self presentViewController:alertController animated:YES completion:nil];
                                [UIApplication sharedApplication].networkActivityIndicatorVisible = NO;
                                self.urlTextField.enabled = YES;
                                [self reconfigureImportButton];
                              });
                            }
                          }];
  } else {
    UIAlertController *alertController = [UIAlertController alertControllerWithTitle:@"URL error" message:@"Themes must be .JS configuration files. Please open the gallery for more information." preferredStyle:UIAlertControllerStyleAlert];
    UIAlertAction *ok = [UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil];
    [alertController addAction:ok];
    [self presentViewController:alertController animated:YES completion:nil];
  }
}

- (void)downloadCompletedWithFilePath:(NSData *)fileData
{
  [UIApplication sharedApplication].networkActivityIndicatorVisible = NO;
  [self.importButton setTitle:@"Download Complete" forState:UIControlStateNormal];
  self.importButton.enabled = NO;
  _downloadCompleted = YES;
  _tempFileData = fileData;
  [self nameFieldDidChange:self.nameTextField];
}

- (IBAction)didTapOnSave:(id)sender
{
  if ([BKTheme withName:self.nameTextField.text]) {
    [self showErrorMsg:@"Cannot have two themes with the same name"];
  } else {
    NSError *error;
    [BKTheme saveResource:self.nameTextField.text withContent:_tempFileData error:&error];
    
    if (error) {
      [self showErrorMsg:error.localizedDescription];
    }
    [self.navigationController popViewControllerAnimated:YES];
  }
}

- (IBAction)cancelButtonTapped:(id)sender
{
  [BKSettingsFileDownloader cancelRunningDownloads];
  [UIApplication sharedApplication].networkActivityIndicatorVisible = NO;
  self.urlTextField.enabled = YES;
  [self reconfigureImportButton];
}


- (void)configureImportButtonForCancel
{
  [self.importButton setTitle:@"Cancel download" forState:UIControlStateNormal];
  [self.importButton setTintColor:[UIColor redColor]];
  [self.importButton addTarget:self action:@selector(cancelButtonTapped:) forControlEvents:UIControlEventTouchUpInside];
}

- (void)reconfigureImportButton
{
  [self.importButton setTitle:@"Import" forState:UIControlStateNormal];
  [self.importButton setTintColor:[UIColor blueColor]];
  [self.importButton addTarget:self action:@selector(importButtonClicked:) forControlEvents:UIControlEventTouchUpInside];
}

- (void)showErrorMsg:(NSString *)errorMsg
{
  UIAlertController *alertController = [UIAlertController alertControllerWithTitle:@"Themes error" message:errorMsg preferredStyle:UIAlertControllerStyleAlert];
  UIAlertAction *ok = [UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil];
  [alertController addAction:ok];
  [self presentViewController:alertController animated:YES completion:nil];
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
  UITableViewCell *clickedCell = [self.tableView cellForRowAtIndexPath:indexPath];

  if ([clickedCell isEqual:self.galleryLinkCell]) {
    [BKLinkActions sendToGitHub:@"themes"];
  } 
}

@end
