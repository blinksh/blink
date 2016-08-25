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

#import "BKFontCreateViewController.h"
#import "BKFont.h"
#import "BKSettingsFileDownloader.h"

@interface BKFontCreateViewController ()

@property (weak, nonatomic) IBOutlet UIButton *importButton;
@property (weak, nonatomic) IBOutlet UITextField *urlTextField;
@property (weak, nonatomic) IBOutlet UITextField *nameTextField;
@property (strong, nonatomic) NSData *tempFileData;
@property (assign, nonatomic) BOOL downloadCompleted;

@end

@implementation BKFontCreateViewController

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
    [self performSegueWithIdentifier:@"unwindFromAddFont" sender:self];
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
  if (_urlTextField.text.length > 4 && [[_urlTextField.text substringFromIndex:[_urlTextField.text length] - 4] isEqualToString:@".css"]) {
    [UIApplication sharedApplication].networkActivityIndicatorVisible = YES;
    [self configureImportButtonForCancel];
    self.urlTextField.enabled = NO;
    [BKSettingsFileDownloader downloadFileAtUrl:_urlTextField.text
                          withCompletionHandler:^(NSData *fileData, NSError *error) {
                            if (error == nil) {
                              [self performSelectorOnMainThread:@selector(downloadCompletedWithFilePath:) withObject:fileData waitUntilDone:NO];
                            } else {
                              UIAlertController *alertController = [UIAlertController alertControllerWithTitle:@"Network error" message:error.localizedDescription preferredStyle:UIAlertControllerStyleAlert];
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
    UIAlertController *alertController = [UIAlertController alertControllerWithTitle:@"URL error" message:@"Please enter valid .css URL" preferredStyle:UIAlertControllerStyleAlert];
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
  if ([BKFont withFont:self.nameTextField.text]) {
    //Error
  } else {
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *documentsDirectory = [paths objectAtIndex:0];
    NSString *folderPath = [NSString stringWithFormat:@"%@/FontsDir/", documentsDirectory];
    NSString *filePath = [NSString stringWithFormat:@"%@/%@.css", folderPath, self.nameTextField.text];
    [[NSFileManager defaultManager] createDirectoryAtPath:folderPath withIntermediateDirectories:YES attributes:nil error:nil];
    NSError *error;
    [_tempFileData writeToURL:[NSURL fileURLWithPath:filePath] options:NSDataWritingAtomic error:&error];
    [BKFont saveFont:self.nameTextField.text withFilePath:filePath];
    [BKFont saveFonts];
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
@end
