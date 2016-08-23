//
//  BKTheme.m
//  settings
//
//  Created by Atul M on 11/08/16.
//  Copyright © 2016 CARLOS CABANERO. All rights reserved.
//

#import "BKTheme.h"

NSMutableArray *Themes;

static NSURL *DocumentsDirectory = nil;
static NSURL *ThemesURL = nil;

@implementation BKTheme

- (instancetype)initWithName:(NSString*)themeName andFilePath:(NSString*)filePath{
    self = [super init];
    if(self){
        self.name = themeName;
        self.filepath = filePath;
    }
    return self;
}

- (id)initWithCoder:(NSCoder *)coder
{
    _name = [coder decodeObjectForKey:@"name"];
    _filepath = [coder decodeObjectForKey:@"filepath"];
    return self;
}

- (void)encodeWithCoder:(NSCoder *)encoder
{
    [encoder encodeObject:_name forKey:@"name"];
    [encoder encodeObject:_filepath forKey:@"filepath"];
}

+ (void)initialize
{
    [BKTheme loadThemes];
}

+ (instancetype)withTheme:(NSString *)athemeName
{
    for (BKTheme *theme in Themes) {
        if ([theme->_name isEqualToString:athemeName]) {
            return theme;
        }
    }
    return nil;
}

+ (NSMutableArray *)all
{
    return Themes;
}

+ (NSInteger)count
{
    return [Themes count];
}

+ (BOOL)saveThemes
{
    // Save IDs to file
    return [NSKeyedArchiver archiveRootObject:Themes toFile:ThemesURL.path];
}
+ (instancetype)saveTheme:(NSString *)themeName withFilePath:(NSString *)filePath
{
    BKTheme *theme = [BKTheme withTheme:themeName];
    if (!theme) {
        theme = [[BKTheme alloc] initWithName:themeName andFilePath:filePath];
        [Themes addObject:theme];
    } else {
        theme->_name = themeName;
        theme->_filepath = filePath;
    }
    
    if (![BKTheme saveThemes]) {
        // This should never fail, but it is kept for testing purposes.
        return nil;
    }
    return theme;
}

+ (void)removeThemeAtIndex:(int)index{
    [Themes removeObjectAtIndex:index];
}

+ (void)loadThemes
{
    if (DocumentsDirectory == nil) {
        DocumentsDirectory = [[[NSFileManager defaultManager] URLsForDirectory:NSDocumentDirectory inDomains:NSUserDomainMask] firstObject];
        ThemesURL = [DocumentsDirectory URLByAppendingPathComponent:@"themes"];
    }
    
    // Load IDs from file
    if ((Themes = [NSKeyedUnarchiver unarchiveObjectWithFile:ThemesURL.path]) == nil) {
        // Initialize the structure if it doesn't exist
        Themes = [[NSMutableArray alloc] init];
    }
}

@end
