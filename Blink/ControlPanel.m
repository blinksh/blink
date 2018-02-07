//
//  ControlPanel.m
//  Blink
//
//  Created by Yury  Korolev on 1/29/18.
//  Copyright © 2018 Carlos Cabañero Projects SL. All rights reserved.
//

#import "ControlPanel.h"
#import "MusicManager.h"
#import "RoundedToolbar.h"

@implementation ControlPanel {
  UIStackView *_stackView;
  
  UIToolbar *_closeToolbar;
  UIToolbar *_clipboardToolbar;
}

- (instancetype)initWithFrame:(CGRect)frame
{
  self = [super initWithFrame:frame];
  if (self) {
    
    // Vertical stack to keep all centered
    UIStackView *vStackView = [[UIStackView alloc] initWithFrame:self.bounds];
    vStackView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    vStackView.axis = UILayoutConstraintAxisVertical;
    vStackView.alignment = UIStackViewAlignmentCenter;
    vStackView.distribution = UIStackViewDistributionEqualSpacing;
    [self addSubview:vStackView];
    
    // Horizontal stack of toolbars
    _stackView = [[UIStackView alloc] initWithFrame:self.bounds];
    _stackView.axis = UILayoutConstraintAxisHorizontal;
    _stackView.alignment = UIStackViewAlignmentCenter;
    _stackView.distribution = UIStackViewDistributionEqualSpacing;
    _stackView.spacing = 12;
    [_stackView setContentCompressionResistancePriority:UILayoutPriorityDefaultLow
                                                forAxis:UILayoutConstraintAxisHorizontal];
    
    _clipboardToolbar = [[RoundedToolbar alloc] initWithFrame:CGRectZero];
    
    UIButton *pasteBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    [pasteBtn setTitle:@"Paste" forState:UIControlStateNormal];
    pasteBtn.tintColor = [UIColor whiteColor];
    [pasteBtn addTarget:self action:@selector(_paste) forControlEvents:UIControlEventTouchUpInside];
    [pasteBtn sizeToFit];
    
    UIBarButtonItem * pasteButton = [[UIBarButtonItem alloc] initWithCustomView:pasteBtn];
    
    [_clipboardToolbar setItems:@[pasteButton]];
    
    _closeToolbar = [[RoundedToolbar alloc] initWithFrame:CGRectZero];
    
    UIBarButtonItem * closeButton = [[UIBarButtonItem alloc]
                                     initWithBarButtonSystemItem:UIBarButtonSystemItemTrash
                                     target:self action:@selector(_close)];
    closeButton.tintColor = [UIColor colorWithRed:253/255.0f green:67/255.0f blue:85/255.0f alpha:1];

    
    [_closeToolbar setItems:@[closeButton]];
    
    [_stackView addArrangedSubview:[[MusicManager shared] controlPanelView]];
    [_stackView addArrangedSubview:_closeToolbar];
    [_stackView addArrangedSubview:_clipboardToolbar];
    
    
    [vStackView addArrangedSubview:_stackView];
  }
  return self;
}


-(void)_close
{
  [_controlPanelDelegate controlPanelOnClose];
}

- (void)_paste
{
  [_controlPanelDelegate controlPanelOnPaste];
}

@end
