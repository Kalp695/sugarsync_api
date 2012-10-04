//
//  SugarSyncInterface.m
//  HindiReader
//
//  Created by Daniele Poggi on 13/07/12.
//  Copyright (c) 2012 Toodev. All rights reserved.
//

#import "SugarSyncInterface.h"
#import "TBXML.h"

#define API_USER_AGENT @"HindiReader/1.0"

// login
#define APP_AUTH_REFRESH_TOKEN_API_URL @"https://api.sugarsync.com/app-authorization"
// access token
#define AUTH_ACCESS_TOKEN_API_URL @"https://api.sugarsync.com/authorization"
// user info
#define USER_INFO_API_URL @"https://api.sugarsync.com/user"
// other requests
#define SUGARSYNC_API_URL @"https://api.sugarsync.com"

#define ACCESS_TOKEN_AUTH_REQUEST_TEMPLATE @"<?xml version=\"1.0\" encoding=\"UTF-8\" standalone=\"yes\"?><tokenAuthRequest><accessKeyId>%@</accessKeyId><privateAccessKey>%@</privateAccessKey><refreshToken>%@</refreshToken></tokenAuthRequest>"

#define APP_AUTH_REQUEST_TEMPLATE @"<?xml version=\"1.0\" encoding=\"UTF-8\" standalone=\"yes\"?><appAuthorization><username>%@</username><password>%@</password><application>%@</application><accessKeyId>%@</accessKeyId><privateAccessKey>%@</privateAccessKey></appAuthorization>"

@implementation SugarSyncInterface

@synthesize appId, accessKeyId, privateAccessKey, refreshToken, accessToken;

static SugarSyncInterface* INSTANCE;

- (id)init
{
    self = [super init];
    if (self) {
        
    }
    return self;
}

+ (SugarSyncInterface*) sharedInterface {
    if (INSTANCE == nil) {                
        static dispatch_once_t onceToken;
        dispatch_once(&onceToken, ^{
            INSTANCE = [SugarSyncInterface new];
        });
    }    
    return INSTANCE;
}

- (BOOL) isLoggedIn {
    return [[NSUserDefaults standardUserDefaults] objectForKey:SUGAR_SYNC_USER] != nil;
}

- (void) requestToken {
    
    NSString *requestData = [NSString stringWithFormat:ACCESS_TOKEN_AUTH_REQUEST_TEMPLATE,self.accessKeyId,self.privateAccessKey,self.refreshToken];
    ASIHTTPRequest *request = [ASIHTTPRequest requestWithURL:[NSURL URLWithString:AUTH_ACCESS_TOKEN_API_URL]];
    [request appendPostData:[requestData dataUsingEncoding:NSUTF8StringEncoding]];
    [request addRequestHeader:@"Accept" value:@"application/xml"];
    [request addRequestHeader:@"User-Agent" value:API_USER_AGENT];
    [request startSynchronous];
    
    // receiving response...
    if (request.responseStatusCode > 299) {
        NSLog(@"ERROR: %@", request.responseStatusMessage);
        return;
    }
    
    NSLog(@"response headers: %@",request.responseHeaders);
    NSLog(@"");
    self.accessToken = [request.responseHeaders objectForKey:@"Location"];
}

- (void) loginWithUsername:(NSString*)username password:(NSString*)password remember:(BOOL)remember callback:(SugarSyncLoginHandler)callback {
    
    if (remember) {
        [[NSUserDefaults standardUserDefaults] setObject:password forKey:SUGAR_SYNC_USER_PWD];
        [[NSUserDefaults standardUserDefaults] synchronize];
    }
    
    dispatch_block_t block = ^{
        
        NSString *requestData = [NSString stringWithFormat:APP_AUTH_REQUEST_TEMPLATE,username,password,self.appId,self.accessKeyId,self.privateAccessKey];
        NSLog(@"request xml: %@",requestData);
        ASIHTTPRequest *request = [ASIHTTPRequest requestWithURL:[NSURL URLWithString:APP_AUTH_REFRESH_TOKEN_API_URL]];
        [request appendPostData:[requestData dataUsingEncoding:NSUTF8StringEncoding]];
        [request setRequestMethod:@"POST"];
        [request addRequestHeader:@"Content-Type" value:@"application/xml"];
        [request addRequestHeader:@"Accept" value:@"application/xml"];
        [request addRequestHeader:@"User-Agent" value:API_USER_AGENT];
        [request startSynchronous];
        
        // receiving response...
        
        NSLog(@"status: %i",request.responseStatusCode);
        
        if (request.responseStatusCode > 299) {
            NSLog(@"ERROR: %@", request.responseStatusMessage);
            callback(NO, nil);
            return;
        }
        NSLog(@"response headers: %@",request.responseHeaders);
        self.refreshToken = [request.responseHeaders objectForKey:@"Location"];
        
        [self requestToken];
        
        if (self.accessToken == nil || self.accessToken.length == 0) {
            callback(NO, nil);
            return;
        }
        
        [self requestUserInfo];
        
        
        if (!remember)
        {
            [[NSUserDefaults standardUserDefaults] removeObjectForKey:SUGAR_SYNC_USER];
            [[NSUserDefaults standardUserDefaults] removeObjectForKey:SUGAR_SYNC_USER_PWD];
            [[NSUserDefaults standardUserDefaults] synchronize];
        }
    };
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0), block);
}

- (void) autoLoginIfAvailable {
    NSDictionary *user = [[NSUserDefaults standardUserDefaults] objectForKey:SUGAR_SYNC_USER];
    if (user) {
        NSString *pwd = [[NSUserDefaults standardUserDefaults] objectForKey:SUGAR_SYNC_USER_PWD];
        [self loginWithUsername:[user objectForKey:@"username"] password:pwd remember:YES callback:NULL];
    }
}

- (void) logout {
    [[NSUserDefaults standardUserDefaults] removeObjectForKey:SUGAR_SYNC_USER];
    [[NSUserDefaults standardUserDefaults] removeObjectForKey:SUGAR_SYNC_USER_PWD];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

- (void) requestUserInfo {
    
    if (!self.accessToken) {
        NSLog(@"ERROR: access tocken is nil.");
        return;
    }
    
    ASIHTTPRequest *request = [ASIHTTPRequest requestWithURL:[NSURL URLWithString:USER_INFO_API_URL]];
    [request addRequestHeader:@"Authorization" value:self.accessToken];
    [request addRequestHeader:@"Content-Type" value:@"application/xml"];    
    [request addRequestHeader:@"Accept" value:@"application/xml"];
    [request addRequestHeader:@"User-Agent" value:API_USER_AGENT];
    [request startSynchronous];
    
    // receiving response...
    
    if (request.responseStatusCode > 299) {
        NSLog(@"ERROR: %@", request.responseStatusMessage);
        return;
    }
    NSLog(@"response headers: %@",request.responseHeaders);
    
    NSString *response = [request responseString];
    NSLog(@"response: %@",response);
    NSLog(@"");
    
    // parsing xml del risultato   
    NSError *error = nil;
    TBXML *parser = [TBXML newTBXMLWithXMLData:request.responseData error:&error];     
    if (parser == nil) {
        NSLog(@"parse error: %@",error);
        return;
    }
    TBXMLElement *usernameElement = [TBXML childElementNamed:@"username" parentElement:parser.rootXMLElement];
    TBXMLElement *nicknameElement = [TBXML childElementNamed:@"nickname" parentElement:parser.rootXMLElement];
    TBXMLElement *quotaElement = [TBXML childElementNamed:@"quota" parentElement:parser.rootXMLElement];
    TBXMLElement *limitElement = [TBXML childElementNamed:@"limit" parentElement:quotaElement];
    TBXMLElement *usageElement = [TBXML childElementNamed:@"usage" parentElement:quotaElement];
    TBXMLElement *workspacesElement = [TBXML childElementNamed:@"workspaces" parentElement:parser.rootXMLElement];
    TBXMLElement *syncfoldersElement = [TBXML childElementNamed:@"syncfolders" parentElement:parser.rootXMLElement];    
    TBXMLElement *magicBriefcaseElement = [TBXML childElementNamed:@"magicBriefcase" parentElement:parser.rootXMLElement];
    
    NSDictionary *user = [NSDictionary dictionaryWithObjectsAndKeys:
                          [TBXML textForElement:usernameElement],@"username",
                          [TBXML textForElement:nicknameElement],@"nickname",
                          [NSDictionary dictionaryWithObjectsAndKeys:
                           [TBXML textForElement:limitElement],@"limit",
                           [TBXML textForElement:usageElement],@"usage", nil],@"quota",
                          [TBXML textForElement:workspacesElement],@"workspaces",
                          [TBXML textForElement:syncfoldersElement],@"syncfolders",
                          [TBXML textForElement:magicBriefcaseElement],@"magicBriefcase",
                          nil];
    
    NSLog(@"user: %@",user);
    
    [[NSUserDefaults standardUserDefaults] setObject:user forKey:SUGAR_SYNC_USER];
    [[NSUserDefaults standardUserDefaults] setObject:user forKey:@"SugarSync"];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

- (NSArray*) filesOfFolderWithPath:(NSString*)folderPath {
    
    ASIHTTPRequest *request = [ASIHTTPRequest requestWithURL:[NSURL URLWithString:folderPath]];
    [request setRequestMethod:@"GET"];
    [request addRequestHeader:@"Authorization" value:self.accessToken];
    [request addRequestHeader:@"Content-Type" value:@"application/xml"];    
    [request addRequestHeader:@"Accept" value:@"application/xml"];
    [request addRequestHeader:@"User-Agent" value:API_USER_AGENT];
    [request startSynchronous];
    
    // receiving response...
    if (request.responseStatusCode > 299) {
        NSLog(@"ERROR: %@", request.responseStatusMessage);
        return [NSArray array];
    }
    NSLog(@"response headers: %@",request.responseHeaders);
    
    NSString *response = [request responseString];
    NSLog(@"response: %@",response);
    NSLog(@"");
    
    // parsing xml del risultato   
    NSError *error = nil;
    TBXML *parser = [TBXML newTBXMLWithXMLData:request.responseData error:&error];     
    if (parser == nil) {
        NSLog(@"parse error: %@",error);
        return [NSArray array];
    }
    NSMutableArray *files = [NSMutableArray array];
    
    [TBXML iterateElementsForQuery:@"file" fromElement:parser.rootXMLElement withBlock:^(TBXMLElement *element) {
       
        TBXMLElement *displayNameElement = [TBXML childElementNamed:@"displayName" parentElement:element];
        TBXMLElement *refElement = [TBXML childElementNamed:@"ref" parentElement:element];
        TBXMLElement *sizeElement = [TBXML childElementNamed:@"size" parentElement:element];
        TBXMLElement *lastModifiedElement = [TBXML childElementNamed:@"lastModified" parentElement:element];
        TBXMLElement *mediaTypeElement = [TBXML childElementNamed:@"mediaType" parentElement:element];
        TBXMLElement *presentOnServerElement = [TBXML childElementNamed:@"presentOnServer" parentElement:element];
        TBXMLElement *fileDataElement = [TBXML childElementNamed:@"fileData" parentElement:element];
        
        [files addObject:[NSDictionary dictionaryWithObjectsAndKeys:
                          [TBXML textForElement:displayNameElement],@"displayName",
                          [TBXML textForElement:refElement],@"ref",
                          [TBXML textForElement:sizeElement],@"size",
                          [TBXML textForElement:lastModifiedElement],@"lastModified",
                          [TBXML textForElement:mediaTypeElement],@"mediaType",
                          [TBXML textForElement:presentOnServerElement],@"presentOnServer",
                          [TBXML textForElement:fileDataElement],@"fileData",                          
                          nil]];        
   }];
    
    /*
     <?xml version="1.0" encoding="UTF-8" standalone="yes"?><collectionContents start="0" hasMore="false" end="1"><file><displayName>What is Magic Briefcase.pdf</displayName><ref>https://api.sugarsync.com/file/:sc:3523487:12597501_11189</ref><size>94055</size><lastModified>2012-07-13T01:43:40.000-07:00</lastModified><mediaType>application/octet-stream</mediaType><presentOnServer>true</presentOnServer><fileData>https://api.sugarsync.com/file/:sc:3523487:12597501_11189/data</fileData></file><file><displayName>SugarSync test 1.pdf</displayName><ref>https://api.sugarsync.com/file/:sc:3523487:12597501_11270</ref><size>10677</size><lastModified>2012-07-13T01:45:24.000-07:00</lastModified><mediaType>application/octet-stream</mediaType><presentOnServer>true</presentOnServer><fileData>https://api.sugarsync.com/file/:sc:3523487:12597501_11270/data</fileData></file></collectionContents>
     */
    
    return files;
}

- (void) contentsOfMagicBriefcase:(SugarSyncGetFolderCompletionHandler)callback {
    
    NSDictionary *user = [[NSUserDefaults standardUserDefaults] objectForKey:SUGAR_SYNC_USER];
    if (!user) {
        NSLog(@"ERROR: user not found");
        callback(NO, [NSArray array]);
        return;
    }
    if (!self.accessToken || self.accessToken.length == 0) {
        NSLog(@"ERROR: access token is nil or 0 length.");
        callback(NO, [NSArray array]);
        return;
    }
    
    dispatch_block_t block = ^{
        
        NSString *magicBriefcasePath = [user objectForKey:@"magicBriefcase"];
        
        ASIHTTPRequest *request = [ASIHTTPRequest requestWithURL:[NSURL URLWithString:magicBriefcasePath]];
        [request setRequestMethod:@"GET"];
        [request addRequestHeader:@"Authorization" value:self.accessToken];
        [request addRequestHeader:@"Content-Type" value:@"application/xml"];    
        [request addRequestHeader:@"Accept" value:@"application/xml"];
        [request addRequestHeader:@"User-Agent" value:API_USER_AGENT];
        [request startSynchronous];
        
        // receiving response...
        
        if (request.responseStatusCode > 299) {
            NSLog(@"ERROR: %@", request.responseStatusMessage);
            dispatch_sync(dispatch_get_main_queue(), ^{
                callback(NO,nil);
            });
        }
        NSLog(@"response headers: %@",request.responseHeaders);
        
        NSString *response = [request responseString];
        NSLog(@"response: %@",response);
        NSLog(@"");
        
        // parsing xml del risultato   
        NSError *error = nil;
        TBXML *parser = [TBXML newTBXMLWithXMLData:request.responseData error:&error];     
        if (parser == nil) {
            NSLog(@"parse error: %@",error);
            return;
        }
        TBXMLElement *filesElement = [TBXML childElementNamed:@"files" parentElement:parser.rootXMLElement];
        NSString *filesPath = [TBXML textForElement:filesElement];
        
        NSArray *files = [self filesOfFolderWithPath:filesPath];                                
        
        dispatch_sync(dispatch_get_main_queue(), ^{
            callback(YES,files);
        });
    };
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0),block);
}

- (void) downloadFileWithID:(NSString*)fileId toPath:(NSString*)localPath 
           progressDelegate:(id <ASIProgressDelegate>)delegate  
                   callback:(SugarSyncDownloadFileCompletionHandler)callback {
    NSDictionary *user = [[NSUserDefaults standardUserDefaults] objectForKey:SUGAR_SYNC_USER];
    if (!user) {
        NSLog(@"ERROR: user not found");
        callback(NO);
    }
    
    dispatch_block_t block = ^{
        ASIHTTPRequest *request = [ASIHTTPRequest requestWithURL:[NSURL URLWithString:fileId]];
        [request addRequestHeader:@"Authorization" value:self.accessToken];
        [request setDownloadDestinationPath:localPath];
        if (delegate) request.downloadProgressDelegate = delegate;
        [request startSynchronous];
        if (request.responseStatusCode > 299) {
            NSLog(@"ERROR: %@", request.responseStatusMessage);
            callback(NO);
        }
        NSData *data = [NSData dataWithContentsOfFile:localPath];
        NSLog(@"downloaded file of length: %i",data.length);
        callback(YES);
    };
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0),block);
}

@end
