//
//  PKDefaults.m
//  settings
//
//  Created by Atul M on 11/08/16.
//  Copyright © 2016 CARLOS CABANERO. All rights reserved.
//

#import "PKDefaults.h"

static NSURL *DocumentsDirectory = nil;
static NSURL *DefaultsURL = nil;
PKDefaults *defaults;
@implementation PKDefaults


#pragma mark - NSCoding

- (id)initWithCoder:(NSCoder *)coder
{
    _keyboardMaps = [coder decodeObjectForKey:@"keyboardMaps"];
    _themeName = [coder decodeObjectForKey:@"themeName"];
    _fontName = [coder decodeObjectForKey:@"fontName"];
    _fontSize = [coder decodeObjectForKey:@"fontSize"];
    _defaultUser = [coder decodeObjectForKey:@"defaultUser"];
    
    return self;
}

- (void)encodeWithCoder:(NSCoder *)encoder
{
    [encoder encodeObject:_keyboardMaps forKey:@"keyboardMaps"];
    [encoder encodeObject:_themeName forKey:@"themeName"];
    [encoder encodeObject:_fontName forKey:@"fontName"];
    [encoder encodeObject:_fontSize forKey:@"fontSize"];
    [encoder encodeObject:_defaultUser forKey:@"defaultUser"];
}

+ (void)initialize
{
    [PKDefaults loadDefaults];
}
+ (void)loadDefaults
{
    if (DocumentsDirectory == nil) {
        //Hosts = [[NSMutableArray alloc] init];
        DocumentsDirectory = [[[NSFileManager defaultManager] URLsForDirectory:NSDocumentDirectory inDomains:NSUserDomainMask] firstObject];
        DefaultsURL = [DocumentsDirectory URLByAppendingPathComponent:@"defaults"];
    }
    
    // Load IDs from file
    if ((defaults = [NSKeyedUnarchiver unarchiveObjectWithFile:DefaultsURL.path]) == nil) {
        // Initialize the structure if it doesn't exist
        defaults = [[PKDefaults alloc]init];
        defaults.keyboardMaps = [[NSMutableDictionary alloc]init];
        for (NSString *key in [PKDefaults keyBoardKeyList]) {
            [defaults.keyboardMaps setObject:@"None" forKey:key];
        }
    }
}

+ (BOOL)saveDefaults
{
    // Save IDs to file
    return [NSKeyedArchiver archiveRootObject:defaults toFile:DefaultsURL.path];
}

+ (void)setModifer:(NSString*)modifier forKey:(NSString*)key{
    if(modifier != nil) {
        [defaults.keyboardMaps setObject:modifier forKey:key];
    }
}

+ (void)setFontName:(NSString*)fontName{
    defaults.fontName = fontName;
}

+ (void)setThemeName:(NSString*)themeName{
    defaults.themeName = themeName;
}

+ (void)setFontSize:(NSNumber*)fontSize{
    defaults.fontSize = fontSize;
}

+ (NSString*)selectedFontName{
    return defaults.fontName;
}
+ (NSString*)selectedThemeName{
    return defaults.themeName;
}
+ (NSNumber*)selectedFontSize{
    return defaults.fontSize;
}


+ (NSMutableArray*)keyboardModifierList{
    return [NSMutableArray arrayWithObjects:@"None", @"Ctrl", @"Meta", @"Esc", nil];
}

+ (NSMutableArray*)keyBoardKeyList{
    return [NSMutableArray arrayWithObjects:@"⌃ Ctrl", @"⌘ Cmd", @"⌥ Alt", @"⇪ CapsLock", nil];
}

+ (NSMutableDictionary*)keyBoardMapping{
    return defaults.keyboardMaps;
}

@end
