/* Copyright (c) 2010 Google Inc.
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

// GTMOAuthWindowController
//
// This window controller for Mac handles sign-in via OAuth.
//
// This controller is not reusable; create a new instance of this controller
// every time the user will sign in.
//
// Sample usage:
//
//  static NSString *const kAppServiceName = @”My Application: Service API”;
//  NSString *scope = @"read/write";
//
//  GTMOAuthAuthentication *auth =
//    [[[GTMOAuthAuthentication alloc] initWithSignatureMethod:kGTMOAuthSignatureMethodHMAC_SHA1
//                                                 consumerKey:myConsumerKey
//                                                  privateKey:myConsumerSecret] autorelease];
//
//  [auth setCallback:@"http://www.example.com/OAuthCallback"];
//
//  GTMOAuthWindowController *controller =
//      [[[GTMOAuthWindowController alloc] initWithScope:scope
//                                              language:nil
//                                       requestTokenURL:requestURL
//                                     authorizeTokenURL:authorizeURL
//                                        accessTokenURL:accessURL
//                                        authentication:auth
//                                        appServiceName:kKeychainItemName
//                                        resourceBundle:nil] autorelease];
//  [controller signInSheetModalForWindow:currentWindow
//                               delegate:self
//                       finishedSelector:@selector(windowController:finishedWithAuth:error:)];
//
// The finished selector should have a signature matching this:
//
//  - (void)windowController:(GTMOAuthWindowController *)windowController
//          finishedWithAuth:(GTMOAuthAuthentication *)auth
//                     error:(NSError *)error {
//    if (error != nil) {
//     // sign in failed
//    } else {
//     // sign in succeeded
//     //
//     // with the GTL library, pass the authentication to the service object,
//     // like
//     //   [[self contactService] setAuthorizer:auth];
//     //
//     // or use it to sign a request directly, like
//     //    [auth authorizeRequest:myNSURLMutableRequest]
//    }
//  }
//
// If the network connection is lost for more than 30 seconds while the sign-in
// html is displayed, the notification kGTLOAuthNetworkLost will be sent.

#include <Foundation/Foundation.h>

#if !TARGET_OS_IPHONE

#import <Cocoa/Cocoa.h>
#import <WebKit/WebKit.h>

#ifdef GTL_TARGET_NAMESPACE
  #import "GTLDefines.h"
#endif

#import "GTMOAuthAuthentication.h"
#import "GTMHTTPFetchHistory.h" // for GTMCookieStorage

@class GTMOAuthSignIn;

@interface GTMOAuthWindowController : NSWindowController {
 @private
  // IBOutlets
  NSButton *keychainCheckbox_;
  WebView *webView_;
  NSButton *webCloseButton_;
  NSButton *webBackButton_;

  // the object responsible for the sign-in networking sequence; it holds
  // onto the authentication object as well
  GTMOAuthSignIn *signIn_;

  // the page request to load when awakeFromNib occurs
  NSURLRequest *initialRequest_;

  // local storage for WebKit cookies so they're not shared with Safari
  GTMCookieStorage *cookieStorage_;

  // the user we're calling back
  //
  // the delegate is retained only until the callback is invoked
  // or the sign-in is canceled
  id delegate_;
  SEL finishedSelector_;

#if NS_BLOCKS_AVAILABLE
  void (^completionBlock_)(GTMOAuthAuthentication *, NSError *);
#elif !__LP64__
  // placeholders: for 32-bit builds, keep the size of the object's ivar section
  // the same with and without blocks
  id completionPlaceholder_;
#endif

  // delegate method for handling URLs to be opened in external windows
  SEL externalRequestSelector_;

  BOOL isWindowShown_;

  // paranoid flag to ensure we only close once during the sign-in sequence
  BOOL hasDoneFinalRedirect_;

  // paranoid flag to ensure we only call the user back once
  BOOL hasCalledFinished_;

  // if non-nil, we display as a sheet on the specified window
  NSWindow *sheetModalForWindow_;

  // if non-empty, the name of the application and service used for the
  // keychain item
  NSString *keychainApplicationServiceName_;

  // if non-nil, the html string to be displayed immediately upon opening
  // of the web view
  NSString *initialHTMLString_;

  // user-defined data
  id userData_;
}

// user interface elements
@property (nonatomic, assign) IBOutlet NSButton *keychainCheckbox;
@property (nonatomic, assign) IBOutlet WebView *webView;
@property (nonatomic, assign) IBOutlet NSButton *webCloseButton;
@property (nonatomic, assign) IBOutlet NSButton *webBackButton;

// the application and service name to use for saving the auth tokens
// to the keychain
@property (nonatomic, copy)   NSString *keychainApplicationServiceName;

// the application name to be displayed during sign-in
@property (nonatomic, copy)   NSString *displayName;

// optional html string displayed immediately upon opening the web view
//
// This string is visible just until the sign-in web page loads, and
// may be used for a "Loading..." type of message
@property (nonatomic, copy)   NSString *initialHTMLString;

// the default timeout for an unreachable network during display of the
// sign-in page is 30 seconds, after which the notification
// kGTLOAuthNetworkLost is sent; set this to 0 to have no timeout
@property (nonatomic, assign) NSTimeInterval networkLossTimeoutInterval;

// Selector for a delegate method to handle requests sent to an external
// browser.
//
// Selector should have a signature matching
// - (void)windowController:(GTMOAuthWindowController *)controller
//             opensRequest:(NSURLRequest *)request;
//
// The controller's default behavior is to use NSWorkspace's openURL:
@property (nonatomic, assign) SEL externalRequestSelector;

// the underlying object to hold authentication tokens and authorize http
// requests
@property (nonatomic, retain, readonly) GTMOAuthAuthentication *authentication;

// the underlying object which performs the sign-in networking sequence
@property (nonatomic, retain, readonly) GTMOAuthSignIn *signIn;

// any arbitrary data object the user would like the controller to retain
@property (nonatomic, retain) id userData;

- (IBAction)closeWindow:(id)sender;

// init method
//
// this is the designated initializer
- (id)initWithScope:(NSString *)scope
           language:(NSString *)language
    requestTokenURL:(NSURL *)requestURL
  authorizeTokenURL:(NSURL *)authorizeURL
     accessTokenURL:(NSURL *)accessURL
     authentication:(GTMOAuthAuthentication *)auth
     appServiceName:(NSString *)keychainAppServiceName
     resourceBundle:(NSBundle *)bundle;

// entry point to begin displaying the sign-in window
//
// the finished selector should have a signature matching
//  - (void)windowController:(GTMOAuthWindowController *)windowController
//          finishedWithAuth:(GTMOAuthAuthentication *)auth
//                     error:(NSError *)error {
//
// once the finished method has been invoked with no error, the auth object
// may be used to authorize requests (adding and signing the auth header) like:
//
//     [authorizer authorizeRequest:myNSMutableURLRequest];
//
// or can be stored in a GTMHTTPFetcher like
//   [fetcher setAuthorizer:auth];
//
// the delegate is retained only until the finished selector is invoked or
//   the sign-in is canceled
- (void)signInSheetModalForWindow:(NSWindow *)parentWindowOrNil
                         delegate:(id)delegate
                 finishedSelector:(SEL)finishedSelector;

#if NS_BLOCKS_AVAILABLE
- (void)signInSheetModalForWindow:(NSWindow *)parentWindowOrNil
                completionHandler:(void (^)(GTMOAuthAuthentication *auth, NSError *error))handler;
#endif

- (void)cancelSigningIn;

// subclasses may override authNibName to specify a custom name
+ (NSString *)authNibName;

// keychain
//
// The keychain checkbox is shown if the keychain application service
// name (typically set in the initWithScope: method) is non-empty
//

// Add tokens from the keychain, if available, to an authentication
// object.  The authentication object must have previously been created.
//
// Returns YES if the authentication object was authorized from the keychain
+ (BOOL)authorizeFromKeychainForName:(NSString *)appServiceName
                      authentication:(GTMOAuthAuthentication *)auth;

// Delete the stored access token and secret, useful for "signing
// out"
+ (BOOL)removeParamsFromKeychainForName:(NSString *)appServiceName;

// Store the access token and secret, typically used immediately after
// signing in
+ (BOOL)saveParamsToKeychainForName:(NSString *)appServiceName
                     authentication:(GTMOAuthAuthentication *)auth;
@end

#endif // #if !TARGET_OS_IPHONE
