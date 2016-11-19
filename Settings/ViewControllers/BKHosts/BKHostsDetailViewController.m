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

#import "BKHostsDetailViewController.h"
#import "BKHosts.h"
#import "BKPredictionViewController.h"
#import "BKPubKey.h"
#import "BKPubKeyViewController.h"
#import "BKDefaults.h"
#import "BKiCloudSyncHandler.h"

@interface BKHostsDetailViewController () <UITextFieldDelegate>

- (IBAction)textFieldDidChange:(id)sender;


@property (weak, nonatomic) IBOutlet UILabel *hostKeyDetail;
@property (weak, nonatomic) IBOutlet UILabel *predictionDetail;
@property (weak, nonatomic) IBOutlet UITextField *hostField;
@property (weak, nonatomic) IBOutlet UITextField *hostNameField;
@property (weak, nonatomic) IBOutlet UITextField *sshPortField;
@property (weak, nonatomic) IBOutlet UITextField *userField;
@property (weak, nonatomic) IBOutlet UITextField *passwordField;
@property (weak, nonatomic) IBOutlet UITextField *moshServerField;
@property (weak, nonatomic) IBOutlet UITextField *moshPortField;
@property (weak, nonatomic) IBOutlet UITextField *startUpCmdField;
@property (weak, nonatomic) IBOutlet UIBarButtonItem *saveButton;

@end

@implementation BKHostsDetailViewController

- (void)viewDidLoad
{
  [super viewDidLoad];

  self.saveButton.enabled = NO;
  if (_bkHost != nil) {
    _hostField.text = _bkHost.host;
    _hostNameField.text = _bkHost.hostName;
    if (_bkHost.port != nil) {
      _sshPortField.text = [NSString stringWithFormat:@"%@", _bkHost.port];
    }
    if(_bkHost.user != nil){
      _userField.text = _bkHost.user;
    }
    _passwordField.text = _bkHost.password;
    _hostKeyDetail.text = _bkHost.key;
    _predictionDetail.text = [BKHosts predictionStringForRawValue:_bkHost.prediction.intValue];
    _moshServerField.text = _bkHost.moshServer;
    if (_bkHost.moshPort != nil) {
      _moshPortField.text = [NSString stringWithFormat:@"%@", _bkHost.moshPort];
    }
    _startUpCmdField.text = _bkHost.moshStartup;
  }else{
    _userField.text = [BKDefaults defaultUserName];
  }

  [self.hostKeyDetail addObserver:self forKeyPath:@"text" options:0 context:nil];
  [self.predictionDetail addObserver:self forKeyPath:@"text" options:0 context:nil];

  // Uncomment the following line to preserve selection between presentations.
  // self.clearsSelectionOnViewWillAppear = NO;

  // Uncomment the following line to display an Edit button in the navigation bar for this view controller.
  // self.navigationItem.rightBarButtonItem = self.editButtonItem;
}

- (void)didReceiveMemoryWarning
{
  [super didReceiveMemoryWarning];
  // Dispose of any resources that can be recreated.
}

#pragma mark - Navigation

// In a storyboard-based application, you will often want to do a little preparation before navigation
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender
{
  // Get the new view controller using [segue destinationViewController].
  // Pass the selected object to the new view controller.
  // if ([[segue identifier] isEqualToString:@"predictionModeSegue"]) {
  //   UITableView *predictionMode = (UITableView *)segue.destinationViewController.view;
  //   [predictionMode setDelegate:self];
  // }
  if ([[segue identifier] isEqualToString:@"keysSegue"]) {
    // TODO: Name as "enableMarkOnSelect"
    BKPubKeyViewController *keys = segue.destinationViewController;
    // The host understands the ID, because it is its domain, what it saves.
    [keys makeSelectable:YES initialSelection:self.hostKeyDetail.text];
  } else if ([[segue identifier] isEqualToString:@"predictionModeSegue"]) {
    BKPredictionViewController *prediction = segue.destinationViewController;
    [prediction performInitialSelection:_predictionDetail.text];
  }
}

- (IBAction)unwindFromKeys:(UIStoryboardSegue *)sender
{
  BKPubKeyViewController *controller = sender.sourceViewController;
  BKPubKey *pk = [controller selectedObject];
  if (pk == nil) {
    self.hostKeyDetail.text = @"None";
  } else {
    self.hostKeyDetail.text = pk.ID;
  }
}

- (IBAction)unwindFromPrediction:(UIStoryboardSegue *)sender
{
  BKPredictionViewController *controller = sender.sourceViewController;
  self.predictionDetail.text = [controller selectedObject];
}

- (BOOL)shouldPerformSegueWithIdentifier:(NSString *)identifier sender:(id)sender
{
  if(_bkHost.iCloudConflictDetected.boolValue){
    return NO;
  }
  NSString *errorMsg;
  if ([identifier isEqualToString:@"unwindFromCreate"]) {
    //An existing host with same name should not exist, but while editing an existing Host, it should not show error
    if ([BKHosts withHost:_hostField.text] && ![_hostField.text isEqualToString:_bkHost.host]) {
      errorMsg = @"Cannot have two hosts with the same name.";
    } else if ([_hostField.text rangeOfCharacterFromSet:[NSCharacterSet whitespaceCharacterSet]].location != NSNotFound) {
      errorMsg = @"Spaces are not permitted in the host.";
    } else if ([_hostNameField.text rangeOfCharacterFromSet:[NSCharacterSet whitespaceCharacterSet]].location != NSNotFound) {
      errorMsg = @"Spaces are not permitted in the host name.";
    } else if ([_userField.text rangeOfCharacterFromSet:[NSCharacterSet whitespaceCharacterSet]].location != NSNotFound) {
      errorMsg = @"Spaces are not permitted in the User.";
    } else {
      _bkHost = [BKHosts saveHost:self.bkHost.host withNewHost:_hostField.text hostName:_hostNameField.text sshPort:_sshPortField.text user:_userField.text password:_passwordField.text hostKey:_hostKeyDetail.text moshServer:_moshServerField.text moshPort:_moshPortField.text startUpCmd:_startUpCmdField.text prediction:[BKHosts predictionValueForString:_predictionDetail.text]];
      [BKHosts saveHost:_bkHost.host withiCloudId:_bkHost.iCloudRecordId andLastModifiedTime:[NSDate date]];
      [[BKiCloudSyncHandler sharedHandler]fetchFromiCloud];
      
      if (!_bkHost) {
        errorMsg = @"Could not create new host.";
      }
    }
    if (errorMsg) {

      UIAlertController *alertController = [UIAlertController alertControllerWithTitle:@"Hosts error" message:errorMsg preferredStyle:UIAlertControllerStyleAlert];
      UIAlertAction *ok = [UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil];
      [alertController addAction:ok];
      [self presentViewController:alertController animated:YES completion:nil];

      return NO;
    }
  }

  return YES;
}

#pragma mark - Text field validations

- (void)dealloc
{
  [self.hostKeyDetail removeObserver:self forKeyPath:@"text"];
  [self.predictionDetail removeObserver:self forKeyPath:@"text"];
}

- (BOOL)textFieldShouldBeginEditing:(UITextField *)textField{
  if(_bkHost.iCloudConflictDetected.boolValue){
    return NO;
  }
  return YES;
}

- (BOOL)textField:(UITextField *)textField shouldChangeCharactersInRange:(NSRange)range replacementString:(NSString *)string
{
  if (textField == _sshPortField || textField == _moshPortField) {
    NSCharacterSet *nonNumberSet = [[NSCharacterSet decimalDigitCharacterSet] invertedSet];
    return ([string stringByTrimmingCharactersInSet:nonNumberSet].length > 0) || [string isEqualToString:@""];
  } else if (textField == _hostField || textField == _hostNameField || textField == _userField) {
    if ([string isEqualToString:@" "]) {
      return NO;
    }
  }
  return YES;
}

- (IBAction)textFieldDidChange:(id)sender
{
  if (_hostField.text.length && _hostNameField.text.length && _userField.text.length) {
    self.saveButton.enabled = YES;
  } else {
    self.saveButton.enabled = NO;
  }
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary<NSString *, id> *)change context:(void *)context
{
  if (object == _hostKeyDetail || object == _predictionDetail) {
    if ([keyPath isEqualToString:@"text"]) {
      [self textFieldDidChange:nil];
    }
  }
}

# pragma mark - UITableView Delegates

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath{
  if(indexPath.section == 1){
    if(indexPath.row == 0){
      BKHostsDetailViewController *iCloudCopyViewController = [self.storyboard instantiateViewControllerWithIdentifier:@"createHost"];
      iCloudCopyViewController.bkHost = _bkHost.iCloudConflictCopy;
      [self.navigationController pushViewController:iCloudCopyViewController animated:YES];
    } else if (indexPath.row == 1){
      if(_bkHost.iCloudRecordId){
        [[BKiCloudSyncHandler sharedHandler]deleteRecord:_bkHost.iCloudRecordId ofType:BKiCloudRecordTypeHosts];
      }
      [BKHosts saveHost:_bkHost.host withNewHost:_bkHost.iCloudConflictCopy.host hostName:_bkHost.iCloudConflictCopy.hostName sshPort:_bkHost.iCloudConflictCopy.port.stringValue user:_bkHost.iCloudConflictCopy.user password:_bkHost.iCloudConflictCopy.password hostKey:_bkHost.iCloudConflictCopy.key moshServer:_bkHost.iCloudConflictCopy.moshServer moshPort:_bkHost.iCloudConflictCopy.moshPort.stringValue startUpCmd:_bkHost.iCloudConflictCopy.moshStartup prediction:_bkHost.iCloudConflictCopy.prediction.intValue];
      [BKHosts saveHost:_bkHost.iCloudConflictCopy.host withiCloudId:_bkHost.iCloudConflictCopy.iCloudRecordId andLastModifiedTime:_bkHost.iCloudConflictCopy.lastModifiedTime];
      [BKHosts markHost:_bkHost.iCloudConflictCopy.host forRecord:[BKHosts recordFromHost:_bkHost] withConflict:NO];
      [[BKiCloudSyncHandler sharedHandler]fetchFromiCloud];
      [self.navigationController popViewControllerAnimated:YES];
    }
  }
}

- (BOOL)showConflictSection{
  return (_bkHost.iCloudConflictDetected.boolValue && _bkHost.iCloudConflictCopy);
}

- (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section {
  if (section == 1 && ![self showConflictSection]) {
    //header height for selected section
    return 0.1;
  } else {
    //keeps all other Headers unaltered
    return [super tableView:tableView heightForHeaderInSection:section];
  }
}

-(CGFloat)tableView:(UITableView *)tableView heightForFooterInSection:(NSInteger)section {
  if (section == 1 && ![self showConflictSection]) {
    //header height for selected section
    return 0.1;
  } else {
    // keeps all other footers unaltered
    return [super tableView:tableView heightForFooterInSection:section];
  }
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
  if (section == 1) { //Index number of interested section
    if (![self showConflictSection]) {
      return 0; //number of row in section when you click on hide
    } else {
      return 3; //number of row in section when you click on show (if it's higher than rows in Storyboard, app will crash)
    }
  } else {
    return [super tableView:tableView numberOfRowsInSection:section]; //keeps inalterate all other rows
  }
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section{
  if(section == 1 && ![self showConflictSection]){
    return @"";
  }else{
    return [super tableView:tableView titleForHeaderInSection:section];
  }
}

- (NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section{
  if(section == 1 && ![self showConflictSection]){
    return @"";
  }else{
    return [super tableView:tableView titleForFooterInSection:section];
  }
}

@end
