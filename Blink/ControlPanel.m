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
  UIStackView *_vStackView;
  
  UIToolbar *_closeToolbar;
  UIToolbar *_clipboardToolbar;
}

- (instancetype)initWithFrame:(CGRect)frame
{
  self = [super initWithFrame:frame];
  if (self) {
    _vStackView =[[UIStackView alloc] initWithFrame:self.bounds];
    _vStackView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [self addSubview:_vStackView];
    
    _vStackView.axis = UILayoutConstraintAxisVertical;
    _vStackView.alignment = UIStackViewAlignmentCenter;
    _vStackView.distribution = UIStackViewDistributionEqualSpacing;
    
    _stackView =[[UIStackView alloc] initWithFrame:self.bounds];
    
    _stackView.axis = UILayoutConstraintAxisHorizontal;
    _stackView.alignment = UIStackViewAlignmentCenter;
    _stackView.distribution = UIStackViewDistributionEqualSpacing;
    _stackView.spacing = 12;
    
    _clipboardToolbar = [[RoundedToolbar alloc] initWithFrame:CGRectZero];
    
    UIButton *pasteBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    [pasteBtn setTitle:@"Paste" forState:UIControlStateNormal];
    pasteBtn.tintColor = [UIColor whiteColor];
    [pasteBtn addTarget:self action:@selector(_paste) forControlEvents:UIControlEventTouchUpInside];
    
    UIBarButtonItem * pasteButton = [[UIBarButtonItem alloc] initWithCustomView:pasteBtn];
    
    [_clipboardToolbar setItems:@[pasteButton]];
    
    _closeToolbar = [[RoundedToolbar alloc] initWithFrame:CGRectZero];
    
    UIBarButtonItem * closeButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemTrash target:self action:@selector(_close)];
    
    [_closeToolbar setItems:@[closeButton]];
    
    [_stackView addArrangedSubview:[[MusicManager shared] controlPanelView]];
    [_stackView addArrangedSubview:_closeToolbar];
    [_stackView addArrangedSubview:_clipboardToolbar];
    
    [_stackView setContentCompressionResistancePriority:UILayoutPriorityDefaultLow forAxis:UILayoutConstraintAxisHorizontal];
    
    [_vStackView addArrangedSubview:_stackView];
    
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
