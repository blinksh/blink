//
//  FileProvider.h
//  BlinkFilesFileProvider
//
//  Created by Nicolas Holzschuch on 29/06/2017.
//  Copyright © 2017 Carlos Cabañero Projects SL. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface FileProvider : NSFileProviderExtension
- (void)startProvidingItemAtURL:(NSURL *)url completionHandler:(void (^)(NSError *))completionHandler;
- (void)stopProvidingItemAtURL:(NSURL *)url;
@end
