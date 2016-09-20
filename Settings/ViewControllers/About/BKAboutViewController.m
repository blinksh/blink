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

#import <WebKit/WebKit.h>

#import "BKAboutViewController.h"

@interface BKAboutViewController ()
@end

@implementation BKAboutViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
  WKWebViewConfiguration *theConfiguration = [[WKWebViewConfiguration alloc] init];
  WKWebView *webView = [[WKWebView alloc] initWithFrame:self.view.frame configuration:theConfiguration];
  NSString *path = [[NSBundle mainBundle] pathForResource:@"about" ofType:@"html"];
  NSURL *nsurl = [NSURL fileURLWithPath:path];
  NSURLRequest *nsrequest=[NSURLRequest requestWithURL:nsurl];
  [webView loadRequest:nsrequest];
  [self.view addSubview:webView];
  webView.translatesAutoresizingMaskIntoConstraints = NO;
  [webView.topAnchor constraintEqualToAnchor:self.view.topAnchor].active = YES;
  [webView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor].active = YES;
  [webView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor].active = YES;
  [webView.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor].active = YES;
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

/*
#pragma mark - Navigation

// In a storyboard-based application, you will often want to do a little preparation before navigation
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    // Get the new view controller using [segue destinationViewController].
    // Pass the selected object to the new view controller.
}
*/

@end
