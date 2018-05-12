//
//  FileProvider.m
//  BlinkFilesFileProvider
//
//  Created by Nicolas Holzschuch on 29/06/2017.
//  Copyright © 2017 Carlos Cabañero Projects SL. All rights reserved.
//

#import "FileProvider.h"
#import <UIKit/UIKit.h>

@interface FileProvider ()

@end

@implementation FileProvider

- (NSFileCoordinator *)fileCoordinator {
    NSFileCoordinator *fileCoordinator = [[NSFileCoordinator alloc] init];
    [fileCoordinator setPurposeIdentifier:[self providerIdentifier]];
    return fileCoordinator;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        [self.fileCoordinator coordinateWritingItemAtURL:[self documentStorageURL] options:0 error:nil byAccessor:^(NSURL *newURL) {
            // ensure the documentStorageURL actually exists
            NSError *error = nil;
            [[NSFileManager defaultManager] createDirectoryAtURL:newURL withIntermediateDirectories:YES attributes:nil error:&error];
        }];
    }
    return self;
}

- (void)providePlaceholderAtURL:(NSURL *)url completionHandler:(void (^)(NSError *error))completionHandler {
    // Should call + writePlaceholderAtURL:withMetadata:error: with the placeholder URL, then call the completion handler with the error if applicable.
    NSString *fileName = [url lastPathComponent];
    
    NSURL *placeholderURL = [NSFileProviderExtension placeholderURLForURL:[self.documentStorageURL URLByAppendingPathComponent:fileName]];
    
    // TODO: get file size for file at <url> from model
    NSUInteger fileSize = 0;
    NSDictionary* metadata = @{ NSURLFileSizeKey : @(fileSize)};
    [NSFileProviderExtension writePlaceholderAtURL:placeholderURL withMetadata:metadata error:NULL];
    
    if (completionHandler) {
        completionHandler(nil);
    }
}

- (void)startProvidingItemAtURL:(NSURL *)url completionHandler:(void (^)(NSError *))completionHandler {
    // Should ensure that the actual file is in the position returned by URLForItemWithIdentifier:, then call the completion handler
    NSError *fileError = nil;
  
#if 0
    // TODO: get the contents of file at <url> from model
    NSData *fileData = [NSData data];
    
    [fileData writeToURL:url options:0 error:&fileError];
#endif
  
    if (completionHandler) {
        completionHandler(nil);
    }
}


- (void)itemChangedAtURL:(NSURL *)url {
    // Called at some point after the file has changed; the provider may then trigger an upload
    
    // TODO: mark file at <url> as needing an update in the model; kick off update process
    NSLog(@"Item changed at URL %@", url);
}

- (void)stopProvidingItemAtURL:(NSURL *)url {
    // Called after the last claim to the file has been released. At this point, it is safe for the file provider to remove the content file.
    // Care should be taken that the corresponding placeholder file stays behind after the content file has been deleted.
    
    [[NSFileManager defaultManager] removeItemAtURL:url error:NULL];
    [self providePlaceholderAtURL:url completionHandler:^(NSError * __nullable error) {
        // TODO: handle any error, do any necessary cleanup
    }];
}

@end
