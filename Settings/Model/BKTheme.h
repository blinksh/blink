//
//  BKTheme.h
//  settings
//
//  Created by Atul M on 11/08/16.
//  Copyright © 2016 CARLOS CABANERO. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface BKTheme : NSObject<NSCoding>

@property (nonatomic, strong)NSString *name;
@property (nonatomic, strong)NSString *filepath;

+ (void)initialize;
+ (instancetype)withTheme:(NSString *)themeName;
+ (BOOL)saveThemes;
+ (instancetype)saveTheme:(NSString*)themeName withFilePath:(NSString*)filePath;
+ (void)removeThemeAtIndex:(int)index;
+ (NSMutableArray *)all;
+ (NSInteger)count;

@end
