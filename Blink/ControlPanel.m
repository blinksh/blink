////////////////////////////////////////////////////////////////////////////////
//
// B L I N K
//
// Copyright (C) 2016-2018 Blink Mobile Shell Project
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
