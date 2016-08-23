//
//  BKHost.m
//  settings
//
//  Created by Atul M on 11/08/16.
//  Copyright © 2016 CARLOS CABANERO. All rights reserved.
//

#import "BKHosts.h"

NSMutableArray *Hosts;

static NSURL *DocumentsDirectory = nil;
static NSURL *HostsURL = nil;

@implementation BKHosts

- (id)initWithCoder:(NSCoder *)coder
{
    _host = [coder decodeObjectForKey:@"host"];
    _hostName = [coder decodeObjectForKey:@"hostName"];
    _port = [coder decodeObjectForKey:@"port"];
    _user = [coder decodeObjectForKey:@"user"];
    _password = [coder decodeObjectForKey:@"password"];
    _key = [coder decodeObjectForKey:@"key"];
    _moshPort = [coder decodeObjectForKey:@"moshPort"];
    _moshStartup = [coder decodeObjectForKey:@"moshStartup"];
    _prediction = [coder decodeObjectForKey:@"prediction"];
    
    return self;
}

- (void)encodeWithCoder:(NSCoder *)encoder
{
    [encoder encodeObject:_host forKey:@"host"];
    [encoder encodeObject:_hostName forKey:@"hostName"];
    [encoder encodeObject:_port forKey:@"port"];
    [encoder encodeObject:_user forKey:@"user"];
    [encoder encodeObject:_password forKey:@"password"];
    [encoder encodeObject:_key forKey:@"key"];
    [encoder encodeObject:_moshPort forKey:@"moshPort"];
    [encoder encodeObject:_moshStartup forKey:@"moshStartup"];
    [encoder encodeObject:_prediction forKey:@"prediction"];
}

- (id)initWithHost:(NSString*)host hostName:(NSString*)hostName sshPort:(NSString*)sshPort user:(NSString*)user password:(NSString*)password hostKey:(NSString*)hostKey moshPort:(NSString*)moshPort startUpCmd:(NSString*)startUpCmd prediction:(enum BKMoshPrediction)prediction
{
    self = [super init];
    if(self){
        _host = host;
        _hostName = hostName;
        if (![sshPort isEqualToString:@""]) {
            _port = [NSNumber numberWithInt:sshPort.intValue];
        }
        _user = user;
        _password = password;
        _key = hostKey;
        if(![moshPort isEqualToString:@""]){
            _moshPort = [NSNumber numberWithInt:moshPort.intValue];
        }
        _moshStartup = startUpCmd;
        _prediction = [NSNumber numberWithInt:prediction];
    }
    return self;
}

+ (void)initialize
{
    [BKHosts loadHosts];
}

+ (instancetype)withHost:(NSString *)aHost
{
    for (BKHosts *host in Hosts) {
        if ([host->_host isEqualToString:aHost]) {
            return host;
        }
    }
    return nil;
}

+ (NSMutableArray *)all
{
    return Hosts;
}

+ (NSInteger)count
{
    return [Hosts count];
}

+ (BOOL)saveHosts
{
    // Save IDs to file
    return [NSKeyedArchiver archiveRootObject:Hosts toFile:HostsURL.path];
}

+ (instancetype)saveHost:(NSString*)host  withNewHost:(NSString*)newHost hostName:(NSString*)hostName sshPort:(NSString*)sshPort user:(NSString*)user password:(NSString*)password hostKey:(NSString*)hostKey moshPort:(NSString*)moshPort startUpCmd:(NSString*)startUpCmd prediction:(enum BKMoshPrediction)prediction
{
    BKHosts *bkHost = [BKHosts withHost:host];
    if(!bkHost){
        bkHost = [[BKHosts alloc]initWithHost:newHost hostName:hostName sshPort:sshPort user:user password:password hostKey:hostKey moshPort:moshPort startUpCmd:startUpCmd prediction:prediction];
        [Hosts addObject:bkHost];
    } else {
        bkHost.host = newHost;
        bkHost.hostName = hostName;
        if(![sshPort isEqualToString:@""]){
            bkHost.port = [NSNumber numberWithInt:sshPort.intValue];
        }
        bkHost.user = user;
        bkHost.password = password;
        bkHost.key = hostKey;
        if(![moshPort isEqualToString:@""]){
            bkHost.moshPort = [NSNumber numberWithInt:moshPort.intValue];
        }
        bkHost.moshStartup = startUpCmd;
        bkHost.prediction = [NSNumber numberWithInt:prediction];
    }
    
    if(![BKHosts saveHosts]){
        return nil;
    }
    return bkHost;
}

+ (void)loadHosts
{
    if (DocumentsDirectory == nil) {
        DocumentsDirectory = [[[NSFileManager defaultManager] URLsForDirectory:NSDocumentDirectory inDomains:NSUserDomainMask] firstObject];
        HostsURL = [DocumentsDirectory URLByAppendingPathComponent:@"hosts"];
    }
    
    // Load IDs from file
    if ((Hosts = [NSKeyedUnarchiver unarchiveObjectWithFile:HostsURL.path]) == nil) {
        // Initialize the structure if it doesn't exist
        Hosts = [[NSMutableArray alloc] init];
    }
}

+ (NSString*)predictionStringForRawValue:(int)rawValue
{
    NSString *predictionString = nil;
    switch (rawValue) {
        case BKMoshPredictionAdaptive:
            predictionString = @"Adaptive";
            break;
        case BKMoshPredictionAlways:
            predictionString = @"Always";
            break;
        case BKMoshPredictionNever:
            predictionString = @"Never";
            break;
        case BKMoshPredictionExperimental:
            predictionString = @"Experimental";
            break;
            
        default:
            break;
    }
    return predictionString;
}

+ (enum BKMoshPrediction)predictionValueForString:(NSString*)predictionString
{
    enum BKMoshPrediction value = BKMoshPredictionUnknown;
    if([predictionString isEqualToString:@"Adaptive"]){
        value = BKMoshPredictionAdaptive;
    } else if([predictionString isEqualToString:@"Always"]){
        value = BKMoshPredictionAlways;
    } else if([predictionString isEqualToString:@"Never"]){
        value = BKMoshPredictionNever;
    } else if([predictionString isEqualToString:@"Experimental"]){
        value = BKMoshPredictionExperimental;
    }
    return value;
}

+ (NSMutableArray*)predictionStringList{
    return [NSMutableArray arrayWithObjects:@"Adaptive", @"Always", @"Never", @"Experimental", nil];
}
@end
