//
//  SugarSyncInterface.h
//  HindiReader
//
//  Created by Daniele Poggi on 13/07/12.
//  Copyright (c) 2012 Toodev. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "ASIHTTPRequest.h"

#define SUGAR_SYNC_USER @"SUGAR_SYNC_USER"
#define SUGAR_SYNC_USER_PWD @"SUGAR_SYNC_USER_PWD"

typedef void(^SugarSyncLoginHandler)(BOOL success, NSArray *results);
typedef void(^SugarSyncGetFolderCompletionHandler)(BOOL success, NSArray *results);
typedef void(^SugarSyncDownloadFileCompletionHandler)(BOOL success);

@interface SugarSyncInterface : NSObject

// info provided bu developer
@property (strong, nonatomic) NSString *appId;
@property (strong, nonatomic) NSString *accessKeyId; 
@property (strong, nonatomic) NSString *privateAccessKey;

/**
 *	@brief	token received with login, used to retrieve access token
 */
@property (strong, nonatomic) NSString *refreshToken;


/**
 *	@brief	token received with method requestToken
 */
@property (strong, nonatomic) NSString *accessToken;


+ (SugarSyncInterface*) sharedInterface;

- (BOOL) isLoggedIn;
- (void) requestToken;
- (void) loginWithUsername:(NSString*)username password:(NSString*)password remember:(BOOL)remember callback:(SugarSyncLoginHandler)callback;
- (void) autoLoginIfAvailable;
- (void) logout;

- (void) requestUserInfo;

- (void) contentsOfMagicBriefcase:(SugarSyncGetFolderCompletionHandler)callback;

- (void) downloadFileWithID:(NSString*)fileId toPath:(NSString*)localPath 
           progressDelegate:(id<ASIProgressDelegate>)delegate 
                   callback:(SugarSyncDownloadFileCompletionHandler)callback;

@end
