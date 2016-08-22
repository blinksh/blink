//
//  PKSettingsDownloader.m
//  settings
//
//  Created by Atul M on 14/08/16.
//  Copyright © 2016 CARLOS CABANERO. All rights reserved.
//

#import "PKSettingsFileDownloader.h"
static NSURLSessionDownloadTask *downloadTask;
@implementation PKSettingsFileDownloader

+ (void)downloadFileAtUrl:(NSString*)urlString withCompletionHandler:(void(^)(NSData *fileData, NSError *error))completionHandler
{
    if(downloadTask != nil || downloadTask.state == NSURLSessionTaskStateRunning){
        [downloadTask cancel];
        downloadTask = nil;
    }
    
    NSURL *url = [NSURL URLWithString:urlString];
    NSURLSessionDownloadTask *downloadTask = [[NSURLSession sharedSession]
                                                   downloadTaskWithURL:url completionHandler:^(NSURL *location, NSURLResponse *response, NSError *error)
                                                   {
                                                       completionHandler([NSData dataWithContentsOfURL:location], error);
                                                   }];
    
    [downloadTask resume];
}

@end
