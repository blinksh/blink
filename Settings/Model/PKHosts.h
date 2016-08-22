//
//  PKHost.h
//  settings
//
//  Created by Atul M on 11/08/16.
//  Copyright © 2016 CARLOS CABANERO. All rights reserved.
//

#import <Foundation/Foundation.h>

enum PKPrediction{
    PKPredictionAdaptive,
    PKPredictionAlways,
    PKPredictionNever,
    PKPredictionExperimental,
    PKPredictionUnknown
};

@interface PKHosts : NSObject<NSCoding>

@property (nonatomic, strong)NSString *host;
@property (nonatomic, strong)NSString *hostName;
@property (nonatomic, strong)NSNumber *port;
@property (nonatomic, strong)NSString *user;
@property (nonatomic, strong)NSString *password;
@property (nonatomic, strong)NSString *key;
@property (nonatomic, strong)NSNumber *moshPort;
@property (nonatomic, strong)NSString *moshStartup;
@property (nonatomic, strong)NSNumber *prediction;

+ (void)initialize;
+ (instancetype)withHost:(NSString *)ID;
+ (BOOL)saveHosts;
+ (instancetype)saveHost:(NSString*)host withNewHost:(NSString*)newHost hostName:(NSString*)hostName sshPort:(NSString*)sshPort user:(NSString*)user password:(NSString*)password hostKey:(NSString*)hostKey moshPort:(NSString*)moshPort startUpCmd:(NSString*)startUpCmd prediction:(enum PKPrediction)prediction;
+ (NSMutableArray *)all;
+ (NSInteger)count;
+ (NSString*)predictionStringForRawValue:(int)rawValue;
+ (enum PKPrediction)predictionValueForString:(NSString*)predictionString;
+ (NSMutableArray*)predictionStringList;
@end
