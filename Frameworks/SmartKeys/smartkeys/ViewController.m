//
//  ViewController.m
//  smartkeys
//
//  Created by CARLOS CABANERO on 26/08/16.
//  Copyright © 2016 CARLOS CABANERO. All rights reserved.
//

#import "ViewController.h"
#import "SmartKeys.h"
#import "SmartKeysView.h"



@interface ViewController () <UITextFieldDelegate>

@end

@implementation ViewController {
    SmartKeys *_smartKeys;
    __weak IBOutlet UITextField *sampleTextField;
}
- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
    if (!_smartKeys) {
        _smartKeys = [[SmartKeys alloc] init];
        _smartKeys.textInputDelegate = sampleTextField;
    }
    sampleTextField.delegate = self;
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (UIView *)inputAccessoryView {
    return [_smartKeys view];
}

- (BOOL)textField:(UITextField *)textField shouldChangeCharactersInRange:(NSRange)range replacementString:(NSString *)string
{
    if(![string isEqualToString:@""]){
        NSUInteger modifiers = [(SmartKeysView *)[_smartKeys view] modifiers];
        if (modifiers & KbdCtrlModifier) {
            textField.text = [textField.text stringByReplacingCharactersInRange:range withString:[NSString stringWithFormat:@"^%@", string]];

        } else if (modifiers & KbdAltModifier) {
            textField.text = [textField.text stringByReplacingCharactersInRange:range withString:[NSString stringWithFormat:@"⌥%@", string]];
        } else {
            textField.text = [textField.text stringByReplacingCharactersInRange:range withString:string];
        }
        return NO;
    } else {
        return YES;
    }
}
@end
