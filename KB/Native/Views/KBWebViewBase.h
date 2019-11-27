//
//  BWebView.h
//  SwiftKB
//
//  Created by Yury Korolev on 11/15/19.
//  Copyright © 2019 AnjLab. All rights reserved.
//

#import <WebKit/WebKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface KBWebViewBase : WKWebView

- (void)report:(NSString *)cmd arg:(NSObject *)arg;
- (void)ready;

@end

NS_ASSUME_NONNULL_END
