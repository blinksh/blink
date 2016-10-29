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

#import "SmartKeysView.h"
#import "SKNonModifierButton.h"

NSString *const KbdLeftArrowKey = @"←";
NSString *const KbdRightArrowKey = @"→";
NSString *const KbdUpArrowKey = @"↑";
NSString *const KbdDownArrowKey = @"↓";
NSString *const KbdEscKey = @"esc";
NSString *const KbdTabKey = @"⇥";
int const kNonModifierCount = 7;


@implementation SmartKey  

-(id)initWithName:(NSString *)name symbol:(NSString *)symbol
{
  self = [super init];
  if (self) {
    _name = name;
    _symbol = symbol;
  }
  return self;
}

@end

//@interface DarkKeyButton : UIButton
//@end
//
//@implementation DarkKeyButton
//- (id)initWithCoder:(NSCoder *)aDecoder {
//    self = [super initWithCoder:aDecoder];
//    if (self) {
//        self.backgroundColor = [UIColor darkGrayColor];
//    }
//    return self;
//}
//
//- (void) setSelected:(BOOL)selected {
//    [super setSelected:selected];
//    
//    if (selected) {
//        self.backgroundColor = UIColorFromRGB(255, 130, 0);
//    }
//    else {
//        self.backgroundColor = [UIColor darkGrayColor];
//    }
//}
//
//@end

@implementation SmartKeysView {
  NSTimer *_timer;
  __weak IBOutlet UIButton *_ctrlButton;
  __weak IBOutlet UIButton *_altButton;
  __weak IBOutlet UIStackView *_stack;
  __weak IBOutlet UIScrollView *_nonModifierScrollView;
    IBOutlet UIStackView *_arrowButtonStackView;
    IBOutlet UIStackView *_cursorButtonStackView;
    //__weak IBOutlet UIView *_rightContainerView;

    
  BOOL isLongPress;
  UIStackView *_nonModifiersStack;
  NSArray <SmartKey *> *_nonModifiersKeys;
    
  UIStackView *_alternateKeysStack;
  NSArray <SmartKey *> *_alternateKeys;

}


- (void)awakeFromNib {
  [super awakeFromNib];
  self.translatesAutoresizingMaskIntoConstraints = NO;
  _nonModifierScrollView.translatesAutoresizingMaskIntoConstraints = NO;
  [self setupModifierButtons];
}

- (void)setupModifierButtons {

  UITapGestureRecognizer *ctrlTapGesture = [[UITapGestureRecognizer alloc]
      initWithTarget:self
              action:@selector(modifierButtonTapped:)];
  ctrlTapGesture.numberOfTapsRequired = 1;
  UILongPressGestureRecognizer *ctrlLongPressGesture =
      [[UILongPressGestureRecognizer alloc]
          initWithTarget:self
                  action:@selector(longPressOnModifierButton:)];
  ctrlLongPressGesture.minimumPressDuration = 0.3;

  [_ctrlButton addGestureRecognizer:ctrlTapGesture];
  [_ctrlButton addGestureRecognizer:ctrlLongPressGesture];

  UITapGestureRecognizer *altTapGesture = [[UITapGestureRecognizer alloc]
      initWithTarget:self
              action:@selector(modifierButtonTapped:)];
  altTapGesture.numberOfTapsRequired = 1;
  UILongPressGestureRecognizer *altLongPressGesture =
      [[UILongPressGestureRecognizer alloc]
          initWithTarget:self
                  action:@selector(longPressOnModifierButton:)];
  altLongPressGesture.minimumPressDuration = 0.3;

  [_altButton addGestureRecognizer:altTapGesture];
  [_altButton addGestureRecognizer:altLongPressGesture];
    [_altButton addObserver:self forKeyPath:@"selected" options:NSKeyValueObservingOptionOld|NSKeyValueObservingOptionNew context:nil];
    
    //[_rightContainerView addSubview:_arrowButtonStackView];
}

- (NSUInteger)modifiers {
  // No need to use the tag, as modifiers are predefined.
  NSUInteger modifiers = 0;
  if (_ctrlButton.selected) {
    modifiers |= KbdCtrlModifier;
    if (!isLongPress) {
      _ctrlButton.selected = NO;
    }
  }
  if (_altButton.selected) {
    modifiers |= KbdAltModifier;
    if (!isLongPress) {
      _altButton.selected = NO;
    }
  }

  return modifiers;
}

- (void)show {
  self.hidden = NO;
}

- (void)showNonModifierKeySection:(SKNonModifierButtonType)type{
    [_nonModifiersStack removeFromSuperview];
    [_alternateKeysStack removeFromSuperview];
    
    UIStackView *selectedStackView = nil;
    
    if(type == SKNonModifierButtonTypeNormal){        
        _cursorButtonStackView.hidden = YES;
        _arrowButtonStackView.hidden = NO;

        selectedStackView = _nonModifiersStack;
        [_nonModifierScrollView addSubview:_nonModifiersStack];
    }else{
        _cursorButtonStackView.hidden = NO;
        _arrowButtonStackView.hidden = YES;
        
        selectedStackView = _alternateKeysStack;
        [_nonModifierScrollView addSubview:_alternateKeysStack];
    }
    
    // Constraints
    selectedStackView.translatesAutoresizingMaskIntoConstraints = NO;

    [selectedStackView.topAnchor constraintEqualToAnchor:_nonModifierScrollView.topAnchor].active = YES;
    [selectedStackView.leadingAnchor constraintEqualToAnchor:_nonModifierScrollView.leadingAnchor].active = YES;
    [selectedStackView.trailingAnchor constraintEqualToAnchor:_nonModifierScrollView.trailingAnchor].active = YES;
    [selectedStackView.bottomAnchor constraintEqualToAnchor:_nonModifierScrollView.bottomAnchor].active = YES;
    [selectedStackView.arrangedSubviews[0].widthAnchor constraintGreaterThanOrEqualToAnchor:_ctrlButton.widthAnchor multiplier:0.8].active = YES;
}

- (void)setNonModifiers:(NSArray <SmartKey *> *)keys
{
  // TODO: Detach previous (if any)
  // Reattach new one
  _nonModifiersStack = [self smartKeysStackWith:keys];
  _nonModifiersKeys = keys;
}

- (void)setAlternateKeys:(NSArray <SmartKey *> *)keys
{
    // TODO: Detach previous (if any)
    // Reattach new one
    _alternateKeysStack = [self smartKeysStackWith:keys];
    _alternateKeys = keys;
}

- (UIStackView *)smartKeysStackWith:(NSArray <SmartKey *> *)keys
{
  // Configure Stack
  UIStackView *stack = [[UIStackView alloc] init];

  stack.axis = UILayoutConstraintAxisHorizontal;
  stack.distribution = UIStackViewDistributionFillEqually;

  for (SmartKey *key in keys) {
    SKNonModifierButton *button = [SKNonModifierButton buttonWithType:UIButtonTypeCustom];
    button.backgroundColor = [UIColor grayColor];
    [button setTitle:key.name forState:UIControlStateNormal];
    [stack addArrangedSubview:button];
    [button addTarget:nil action:@selector(nonModifierUp:) forControlEvents:UIControlEventTouchUpInside];
    [button addTarget:nil action:@selector(nonModifierUp:) forControlEvents:UIControlEventTouchUpOutside];
    [button addTarget:nil action:@selector(nonModifierUp:) forControlEvents:UIControlEventTouchDragExit];
    [button addTarget:nil action:@selector(nonModifierDown:) forControlEvents:UIControlEventTouchDown];
  }
  
  return stack;
}

- (IBAction)nonModifierUp:(UIButton *)sender
{
  [self.delegate symbolUp:sender.currentTitle];
}

- (IBAction)nonModifierDown:(UIButton *)sender
{
  [self.delegate symbolDown:sender.currentTitle];
}

- (UIInputViewStyle)inputViewStyle {
  return UIInputViewStyleDefault;
}

- (void)modifierButtonTapped:(UITapGestureRecognizer *)gesture {
  //[self modifiers];
  UIButton *selectedButton = (UIButton *)gesture.view;
  [selectedButton setSelected:!selectedButton.isSelected];
}

- (void)longPressOnModifierButton:(UILongPressGestureRecognizer *)gesture {
  UIButton *selectedButton = (UIButton *)gesture.view;
  if (gesture.state == UIGestureRecognizerStateBegan) {
    [selectedButton setSelected:YES];
    isLongPress = YES;
  } else if (gesture.state == UIGestureRecognizerStateEnded) {
    [selectedButton setSelected:NO];
    isLongPress = NO;
  }
}

- (void)scrollViewDidScroll:(UIScrollView *)scrollView {
}

# pragma mark - Alt Button Methods

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary<NSKeyValueChangeKey,id> *)change context:(void *)context{
    if(object == _altButton){
        if([keyPath isEqualToString:@"selected"]){
            if([change objectForKey:@"new"]){
                int newValue = [[change objectForKey:@"new"]intValue];
                if(newValue == 1){
                    [self showNonModifierKeySection:SKNonModifierButtonTypeAlternate];
                }else{
                    [self showNonModifierKeySection:SKNonModifierButtonTypeNormal];
                }
            }
        }
    }
}


@end

// Button behaviors and view. view configuration.
// Modifier buttons
// Non-modifier buttons
// "Alternative" / "More" button -> Allows the delegate to decide how to show the other possible interfaces it has
