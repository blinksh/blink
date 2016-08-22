//
//  PKHost.m
//  settings
//
//  Created by Atul M on 11/08/16.
//  Copyright © 2016 CARLOS CABANERO. All rights reserved.
//

#import "PKHosts.h"

NSMutableArray *Hosts;

static NSURL *DocumentsDirectory = nil;
static NSURL *HostsURL = nil;

@implementation PKHosts

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

- (id)initWithHost:(NSString*)host hostName:(NSString*)hostName sshPort:(NSString*)sshPort user:(NSString*)user password:(NSString*)password hostKey:(NSString*)hostKey moshPort:(NSString*)moshPort startUpCmd:(NSString*)startUpCmd prediction:(enum PKPrediction)prediction
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
    [PKHosts loadHosts];
}

+ (instancetype)withHost:(NSString *)aHost
{
    for (PKHosts *host in Hosts) {
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

+ (instancetype)saveHost:(NSString*)host  withNewHost:(NSString*)newHost hostName:(NSString*)hostName sshPort:(NSString*)sshPort user:(NSString*)user password:(NSString*)password hostKey:(NSString*)hostKey moshPort:(NSString*)moshPort startUpCmd:(NSString*)startUpCmd prediction:(enum PKPrediction)prediction
{
    PKHosts *pkHost = [PKHosts withHost:host];
    if(!pkHost){
        pkHost = [[PKHosts alloc]initWithHost:newHost hostName:hostName sshPort:sshPort user:user password:password hostKey:hostKey moshPort:moshPort startUpCmd:startUpCmd prediction:prediction];
        [Hosts addObject:pkHost];
    } else {
        pkHost.host = newHost;
        pkHost.hostName = hostName;
        if(![sshPort isEqualToString:@""]){
            pkHost.port = [NSNumber numberWithInt:sshPort.intValue];
        }
        pkHost.user = user;
        pkHost.password = password;
        pkHost.key = hostKey;
        if(![moshPort isEqualToString:@""]){
            pkHost.moshPort = [NSNumber numberWithInt:moshPort.intValue];
        }
        pkHost.moshStartup = startUpCmd;
        pkHost.prediction = [NSNumber numberWithInt:prediction];
    }
    
    if(![PKHosts saveHosts]){
        return nil;
    }
    return pkHost;
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
        case PKPredictionAdaptive:
            predictionString = @"Adaptive";
            break;
        case PKPredictionAlways:
            predictionString = @"Always";
            break;
        case PKPredictionNever:
            predictionString = @"Never";
            break;
        case PKPredictionExperimental:
            predictionString = @"Experimental";
            break;
            
        default:
            break;
    }
    return predictionString;
}

+ (enum PKPrediction)predictionValueForString:(NSString*)predictionString
{
    enum PKPrediction value = PKPredictionUnknown;
    if([predictionString isEqualToString:@"Adaptive"]){
        value = PKPredictionAdaptive;
    } else if([predictionString isEqualToString:@"Always"]){
        value = PKPredictionAlways;
    } else if([predictionString isEqualToString:@"Never"]){
        value = PKPredictionNever;
    } else if([predictionString isEqualToString:@"Experimental"]){
        value = PKPredictionExperimental;
    }
    return value;
}

+ (NSMutableArray*)predictionStringList{
    return [NSMutableArray arrayWithObjects:@"Adaptive", @"Always", @"Never", @"Experimental", nil];
}
@end
