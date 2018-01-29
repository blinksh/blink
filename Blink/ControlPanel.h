//
//  ControlPanel.h
//  Blink
//
//  Created by Yury  Korolev on 1/29/18.
//  Copyright © 2018 Carlos Cabañero Projects SL. All rights reserved.
//

#import <UIKit/UIKit.h>

@protocol ControlPanelDelegate

- (void)controlPanelOnClose;
- (void)controlPanelOnPaste;

@end

@interface ControlPanel : UIView

@property (weak) id<ControlPanelDelegate> controlPanelDelegate;

@end
