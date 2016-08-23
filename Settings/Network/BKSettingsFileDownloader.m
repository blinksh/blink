//
//  BKSettingsDownloader.m
//  settings
//
//  Created by Atul M on 14/08/16.
//  Copyright © 2016 CARLOS CABANERO. All rights reserved.
//

#import "BKSettingsFileDownloader.h"
static NSURLSessionDownloadTask *downloadTask;
@implementation BKSettingsFileDownloader

static NSURLSessionDownloadTask *downloadTask;

+ (void)downloadFileAtUrl:(NSString*)urlString withCompletionHandler:(void(^)(NSData *fileData, NSError *error))completionHandler
{
    [BKSettingsFileDownloader cancelRunningDownloads];
    
    NSURL *url = [NSURL URLWithString:urlString];
    downloadTask = [[NSURLSession sharedSession]
                                                   downloadTaskWithURL:url completionHandler:^(NSURL *location, NSURLResponse *response, NSError *error)
                                                   {
                                                       if(error.code != -999){
                                                           completionHandler([NSData dataWithContentsOfURL:location], error);
                                                       }
                                                   }];
    
    [downloadTask resume];
}

+ (void)cancelRunningDownloads{
    if(downloadTask != nil || downloadTask.state == NSURLSessionTaskStateRunning){
        [downloadTask cancel];
        downloadTask = nil;
    }
}

@end
