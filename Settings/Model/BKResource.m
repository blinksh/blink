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

#import <objc/runtime.h>

#import "BKResource.h"

static char defaultKey;
static char customKey;

static NSURL *DocumentsDirectory = nil;


@implementation BKResource {
  NSURL *_fileURL;
}

- (instancetype)initWithName:(NSString *)name andFileName:(NSString *)fileName onURL:(NSURL *)fileURL
{
  self = [super init];
  if (self) {
    self.name = name;
    self.filename = fileName;
    _fileURL = fileURL;
  }
  return self;
}

- (id)initWithCoder:(NSCoder *)coder
{
  _name = [coder decodeObjectForKey:@"title"];
  _filename = [coder decodeObjectForKey:@"filename"];
  // Only Custom is initialized with URL
  _fileURL = [[self class] customResourcesLocation];
  return self;
}

- (void)encodeWithCoder:(NSCoder *)encoder
{
  [encoder encodeObject:_name forKey:@"title"];
  [encoder encodeObject:_filename forKey:@"filename"];
}

- (BOOL)isCustom
{
  if (_fileURL) {
    return YES;
  }

  return NO;
}

- (NSString *)content
{
  return [NSString stringWithContentsOfFile:self.fullPath encoding:NSUTF8StringEncoding error:nil];
}

- (NSString *)fullPath
{
  return [[_fileURL URLByAppendingPathComponent:self.filename] path];
}

+ (void)initialize
{
  DocumentsDirectory = [[[NSFileManager defaultManager] URLsForDirectory:NSDocumentDirectory inDomains:NSUserDomainMask] firstObject];
}

+ (instancetype)withName:(NSString *)name
{
  for (BKResource *res in [self all]) {
    if ([res->_name isEqualToString:name]) {
      return res;
    }
  }
  return nil;
}

+ (NSURL *)resourcesURL
{
  return DocumentsDirectory;
}

+ (NSMutableArray *)defaultResources
{
  NSMutableArray *rscs = objc_getAssociatedObject(self, &defaultKey);
  if (!rscs) {
    // Load Default resources
    rscs = [[NSMutableArray alloc] init];
    NSError *error = nil;
    NSArray *properties = [NSArray arrayWithObjects:NSURLLocalizedNameKey, nil];

    NSArray *resourceFiles = [[NSFileManager defaultManager]
	contentsOfDirectoryAtURL:self.defaultResourcesLocation
      includingPropertiesForKeys:properties
			 options:(NSDirectoryEnumerationSkipsHiddenFiles)
			   error:&error];
    NSString *fileExt = [NSString stringWithFormat:@".%@", self.resourcesExtension];

    if (resourceFiles != nil) {
      for (NSURL *file in resourceFiles) {
	NSString *fileName = [file lastPathComponent];
	BKResource *res = [[self alloc] initWithName:[fileName stringByReplacingOccurrencesOfString:fileExt withString:@""]
					 andFileName:fileName
					       onURL:self.defaultResourcesLocation];
	[rscs addObject:res];
      }
    }
    objc_setAssociatedObject(self, &defaultKey, rscs, OBJC_ASSOCIATION_RETAIN);
  }
  return rscs;
}

+ (NSMutableArray *)customResources
{
  NSMutableArray *rscs = objc_getAssociatedObject(self, &customKey);
  if (!rscs) {
    if ((rscs = [NSKeyedUnarchiver unarchiveObjectWithFile:self.customResourcesListLocation.path]) == nil) {
      rscs = [[NSMutableArray alloc] init];
    }
    objc_setAssociatedObject(self, &customKey, rscs, OBJC_ASSOCIATION_RETAIN);
  }
  return rscs;
}

+ (NSMutableArray *)associatedResource:(char *)key
{
  NSMutableArray *rscs = objc_getAssociatedObject(self, &customKey);
  if (!rscs) {
    rscs = [[NSMutableArray alloc] init];
    objc_setAssociatedObject(self, &customKey, rscs, OBJC_ASSOCIATION_RETAIN);
  }
  return rscs;
}

+ (NSURL *)defaultResourcesLocation
{
  return [[[NSBundle mainBundle] resourceURL] URLByAppendingPathComponent:[self resourcesPathName]];
}

+ (NSURL *)customResourcesLocation
{
  return [DocumentsDirectory URLByAppendingPathComponent:[self resourcesPathName]];
}

+ (NSURL *)customResourcesListLocation
{
  NSString *listFileName = [[self resourcesPathName] stringByAppendingString:@"List"];
  return [DocumentsDirectory URLByAppendingPathComponent:listFileName];
}

+ (NSString *)resourcesPathName
{
  NSAssert(NO, @"The method %@ in %@ must be overridden.",
	   NSStringFromSelector(_cmd), NSStringFromClass([self class]));
  return nil;
}

+ (NSString *)resourcesExtension
{
  NSAssert(NO, @"The method %@ in %@ must be overridden.",
	   NSStringFromSelector(_cmd), NSStringFromClass([self class]));
  return nil;
}

+ (NSArray *)all
{
  return [self.defaultResources arrayByAddingObjectsFromArray:self.customResources];
}

+ (NSInteger)count
{
  return [self.all count];
}

+ (NSInteger)defaultResourcesCount
{
  return self.all.count - self.customResources.count;
}

+ (BOOL)saveAll
{
  // Save IDs to file
  return [NSKeyedArchiver archiveRootObject:self.customResources toFile:self.customResourcesListLocation.path];
}

+ (instancetype)saveResource:(NSString *)name withContent:(NSData *)content error:(NSError *__autoreleasing *)error
{
  NSString *fileName = [[NSUUID UUID] UUIDString];

  NSURL *filePath = [self.customResourcesLocation URLByAppendingPathComponent:fileName];
  [[NSFileManager defaultManager] createDirectoryAtURL:self.customResourcesLocation withIntermediateDirectories:YES attributes:nil error:nil];

  [content writeToURL:filePath options:NSDataWritingAtomic error:error];

  if (*error) {
    return nil;
  }

  BKResource *res = [[self alloc] initWithName:name andFileName:fileName onURL:self.customResourcesLocation];
  [self.customResources addObject:res];

  [self saveAll];
  return res;
}

+ (void)removeResourceAtIndex:(int)index
{
  [self.customResources removeObjectAtIndex:index - [self defaultResourcesCount]];
  [self saveAll];
}

@end
