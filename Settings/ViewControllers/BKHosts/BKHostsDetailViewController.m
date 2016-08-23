//
//  HostsDetailViewController.m
//  Blink
//
//  Created by CARLOS CABANERO on 01/07/16.
//

#import "BKHostsDetailViewController.h"
#import "BKPubKeyViewController.h"
#import "BKPredictionViewController.h"
#import "BKPubKey.h"
#import "BKHosts.h"

@interface BKHostsDetailViewController ()<UITextFieldDelegate>
- (IBAction)textFieldDidChange:(id)sender;


@property (weak, nonatomic) IBOutlet UILabel *hostKeyDetail;
@property (weak, nonatomic) IBOutlet UILabel *predictionDetail;
@property (weak, nonatomic) IBOutlet UITextField *hostField;
@property (weak, nonatomic) IBOutlet UITextField *hostNameField;
@property (weak, nonatomic) IBOutlet UITextField *sshPortField;
@property (weak, nonatomic) IBOutlet UITextField *userField;
@property (weak, nonatomic) IBOutlet UITextField *passwordField;
@property (weak, nonatomic) IBOutlet UITextField *moshPortField;
@property (weak, nonatomic) IBOutlet UITextField *startUpCmdField;
@property (weak, nonatomic) IBOutlet UIBarButtonItem *saveButton;

@end

@implementation BKHostsDetailViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.saveButton.enabled = NO;
    if(_bkHost != nil){
        _hostField.text = _bkHost.host;
        _hostNameField.text = _bkHost.hostName;
        if(_bkHost.port != nil){
            _sshPortField.text = [NSString stringWithFormat:@"%@",_bkHost.port];
        }
        _userField.text = _bkHost.user;
        _passwordField.text = _bkHost.password;
        _hostKeyDetail.text = _bkHost.key;
        _predictionDetail.text = [BKHosts predictionStringForRawValue:_bkHost.prediction.intValue];
        if(_bkHost.moshPort != nil){
            _moshPortField.text = [NSString stringWithFormat:@"%@",_bkHost.moshPort];
        }
        _startUpCmdField.text = _bkHost.moshStartup;
        
    }
    
    [self.hostKeyDetail addObserver:self forKeyPath:@"text" options:0 context:nil];
    [self.predictionDetail addObserver:self forKeyPath:@"text" options:0 context:nil];

    
    // Uncomment the following line to preserve selection between presentations.
    // self.clearsSelectionOnViewWillAppear = NO;
    
    // Uncomment the following line to display an Edit button in the navigation bar for this view controller.
    // self.navigationItem.rightBarButtonItem = self.editButtonItem;
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

#pragma mark - Navigation

// In a storyboard-based application, you will often want to do a little preparation before navigation
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
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
  } else if([[segue identifier]isEqualToString:@"predictionModeSegue"]){
      BKPredictionViewController *prediction = segue.destinationViewController;
      [prediction performInitialSelection:_predictionDetail.text];
  }
}

- (IBAction)unwindFromKeys:(UIStoryboardSegue *)sender
{
  BKPubKeyViewController * controller = sender.sourceViewController;
  BKPubKey *pk = [controller selectedObject];
    if(pk == nil){
        self.hostKeyDetail.text = @"None";
    } else {
        self.hostKeyDetail.text = pk.ID;
    }
}

- (IBAction)unwindFromPrediction:(UIStoryboardSegue *)sender
{
    BKPredictionViewController * controller = sender.sourceViewController;
    self.predictionDetail.text = [controller selectedObject];
}

- (BOOL)shouldPerformSegueWithIdentifier:(NSString *)identifier sender:(id)sender
{
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
            _bkHost = [BKHosts saveHost:self.bkHost.host withNewHost:_hostField.text hostName:_hostNameField.text sshPort:_sshPortField.text user:_userField.text password:_passwordField.text hostKey:_hostKeyDetail.text moshPort:_moshPortField.text startUpCmd:_startUpCmdField.text prediction:[BKHosts predictionValueForString:_predictionDetail.text]];
            if (!_bkHost) {
                errorMsg = @"Could not create new host.";
            }
        }
        if (errorMsg) {
            
            UIAlertController *alertController = [UIAlertController alertControllerWithTitle:@"Hosts error" message:errorMsg preferredStyle:UIAlertControllerStyleAlert];
            UIAlertAction* ok = [UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil];
            [alertController addAction:ok];
            [self presentViewController:alertController animated:YES completion:nil];
            
            return NO;
        }
        
    }
    
    return YES;
}

#pragma mark - Text field validations

- (void)dealloc{
    [self.hostKeyDetail removeObserver:self forKeyPath:@"text"];
    [self.predictionDetail removeObserver:self forKeyPath:@"text"];

}

- (BOOL)textField:(UITextField *)textField shouldChangeCharactersInRange:(NSRange)range replacementString:(NSString *)string
{
    if(textField == _sshPortField || textField == _moshPortField){
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
    if(_hostField.text.length && _hostNameField.text.length && _userField.text.length){
        self.saveButton.enabled = YES;
    } else {
        self.saveButton.enabled = NO;
    }
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary<NSString *,id> *)change context:(void *)context{
    if(object == _hostKeyDetail || object == _predictionDetail){
        if([keyPath isEqualToString:@"text"]){
            [self textFieldDidChange:nil];
        }
    }
}

@end
