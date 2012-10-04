Sugarsync API
=============

An easy-to-use client library for the official SugarSync API 

These are the actual functions:

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