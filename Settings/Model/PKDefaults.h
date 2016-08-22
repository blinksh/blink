//
//  PKDefaults.h
//  settings
//
//  Created by Atul M on 11/08/16.
//  Copyright © 2016 CARLOS CABANERO. All rights reserved.
//

#import <Foundation/Foundation.h>

enum PKKeyBoardModifiers{
    PKKeyBoardModifierNone,
    PKKeyBoardModifierCtrl,
    PKKeyBoardModifierMeta,
    PKKeyBoardModifierEsc
};

@interface PKDefaults : NSObject <NSCoding>

@property (nonatomic, strong) NSMutableDictionary *keyboardMaps;
@property (nonatomic, strong) NSString *themeName;
@property (nonatomic, strong) NSString *fontName;
@property (nonatomic, strong) NSNumber *fontSize;
@property (nonatomic, strong) NSString *defaultUser;


+ (void)initialize;
+ (BOOL)saveDefaults;
+ (void)setModifer:(NSString*)modifier forKey:(NSString*)key;
+ (void)setFontName:(NSString*)fontName;
+ (void)setThemeName:(NSString*)themeName;
+ (void)setFontSize:(NSNumber*)fontSize;
+ (NSString*)selectedFontName;
+ (NSString*)selectedThemeName;
+ (NSNumber*)selectedFontSize;
+ (NSMutableArray*)keyboardModifierList;
+ (NSMutableArray*)keyBoardKeyList;
+ (NSMutableDictionary*)keyBoardMapping;
@end
