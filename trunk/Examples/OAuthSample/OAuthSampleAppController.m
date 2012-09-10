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

#import "OAuthSampleAppController.h"

@implementation OAuthSampleAppController

static NSString *const kTwitterKeychainItemName = @"OAuth Sample: Twitter";

static NSString *const kTwitterServiceName = @"Twitter";

- (void)awakeFromNib {
  // Get the saved authentication, if any, from the keychain.
  //
  // The window controller supports methods for saving and restoring
  // authentication under arbitrary keychain item names; see the
  // "keychainForName" methods in the interface.  The keychain item
  // names are up to the application, and may reflect multiple accounts for
  // one or more services.
  GTMOAuthAuthentication *auth = [self authForTwitter];
  if (auth) {
    BOOL didAuth = [GTMOAuthWindowController authorizeFromKeychainForName:kTwitterKeychainItemName
                                                           authentication:auth];
    if (didAuth) {
      // select the Twitter radio button
      [mRadioButtons selectCellWithTag:1];
    }
  }

  // save the authentication object, which holds the auth tokens
  [self setAuthentication:auth];

  // this is optional:
  //
  // we'll watch for the "hidden" fetches that occur to obtain tokens
  // during authentication, and start and stop our indeterminate progress
  // indicator during the fetches
  //
  // usually, these fetches are very brief
  NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
  [nc addObserver:self
         selector:@selector(signInFetchStateChanged:)
             name:kGTMOAuthFetchStarted
           object:nil];
  [nc addObserver:self
         selector:@selector(signInFetchStateChanged:)
             name:kGTMOAuthFetchStopped
           object:nil];
  [nc addObserver:self
         selector:@selector(signInNetworkLost:)
             name:kGTMOAuthNetworkLost
           object:nil];

  [self updateUI];
}

- (void)dealloc {
  [mAuth release];
  [super dealloc];
}

#pragma mark -

- (BOOL)isSignedIn {
  BOOL isSignedIn = [mAuth canAuthorize];
  return isSignedIn;
}

- (IBAction)signInOutClicked:(id)sender {
  if (![self isSignedIn]) {
    // sign in
    [self signInToTwitter];
  } else {
    // sign out
    [self signOut];
  }
  [self updateUI];
}

- (void)signOut {
  // remove the stored Twitter authentication from the keychain, if any
  [GTMOAuthWindowController removeParamsFromKeychainForName:kTwitterKeychainItemName];

  // discard our retains authentication object
  [self setAuthentication:nil];

  [self updateUI];
}

- (GTMOAuthAuthentication *)authForTwitter {
  // Note: to use this sample, you need to fill in a valid consumer key and
  // consumer secret provided by Twitter for their API
  //
  // http://twitter.com/apps/
  //
  // The controller requires a URL redirect from the server upon completion,
  // so your application should be registered with Twitter as a "web" app,
  // not a "client" app
  NSString *myConsumerKey = @"";
  NSString *myConsumerSecret = @"";

  if ([myConsumerKey length] == 0 || [myConsumerSecret length] == 0) {
    return nil;
  }

  GTMOAuthAuthentication *auth;
  auth = [[[GTMOAuthAuthentication alloc] initWithSignatureMethod:kGTMOAuthSignatureMethodHMAC_SHA1
                                                        consumerKey:myConsumerKey
                                                         privateKey:myConsumerSecret] autorelease];

  // setting the service name lets us inspect the auth object later to know
  // what service it is for
  [auth setServiceProvider:kTwitterServiceName];
  return auth;
}

- (void)signInToTwitter {

  [self signOut];

  NSURL *requestURL = [NSURL URLWithString:@"http://twitter.com/oauth/request_token"];
  NSURL *accessURL = [NSURL URLWithString:@"http://twitter.com/oauth/access_token"];
  NSURL *authorizeURL = [NSURL URLWithString:@"http://twitter.com/oauth/authorize"];
  NSString *scope = @"http://api.twitter.com/";

  GTMOAuthAuthentication *auth = [self authForTwitter];
  if (!auth) {
    [self displayErrorThatTheCodeNeedsATwitterConsumerKeyAndSecret];
  }

  // set the callback URL to which the site should redirect, and for which
  // the OAuth controller should look to determine when sign-in has
  // finished or been canceled
  //
  // This URL does not need to be for an actual web page
  [auth setCallback:@"http://www.example.com/OAuthCallback"];

  GTMOAuthWindowController *windowController;
  windowController = [[[GTMOAuthWindowController alloc] initWithScope:scope
                                                               language:nil
                                                        requestTokenURL:requestURL
                                                      authorizeTokenURL:authorizeURL
                                                         accessTokenURL:accessURL
                                                         authentication:auth
                                                         appServiceName:kTwitterKeychainItemName
                                                         resourceBundle:nil] autorelease];
  [windowController signInSheetModalForWindow:mMainWindow
                                     delegate:self
                             finishedSelector:@selector(windowController:finishedWithAuth:error:)];
}

- (void)windowController:(GTMOAuthWindowController *)windowController
        finishedWithAuth:(GTMOAuthAuthentication *)auth
                   error:(NSError *)error {
  if (error != nil) {
    // Authentication failed (perhaps the user denied access, or closed the
    // window before granting access)
    NSLog(@"Authentication error: %@", error);
    NSData *responseData = [[error userInfo] objectForKey:@"data"]; // kGTMHTTPFetcherStatusDataKey
    if ([responseData length] > 0) {
      // show the body of the server's authentication failure response
      NSString *str = [[[NSString alloc] initWithData:responseData
                                             encoding:NSUTF8StringEncoding] autorelease];
      NSLog(@"%@", str);
    }

    [self setAuthentication:nil];
  } else {
    // Authentication succeeded
    //
    // At this point, we either use the authentication object to explicitly
    // authorize requests, like
    //
    //   [auth authorizeRequest:myNSURLMutableRequest]
    //
    // or store the authentication object into a GTMHTTPFetcher object like
    //
    //   [fetcher setAuthorizer:auth];

    // save the authentication object
    [self setAuthentication:auth];

    // Just to prove we're signed in, we'll attempt an authenticated fetch for the
    // signed-in user
    [self doAnAuthenticatedAPIFetch];
  }

  [self updateUI];
}

#pragma mark -

- (void)doAnAuthenticatedAPIFetch {
  // Twitter status feed
  NSString *urlStr = @"http://api.twitter.com/1/statuses/home_timeline.json";

  NSURL *url = [NSURL URLWithString:urlStr];
  NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];
  [mAuth authorizeRequest:request];

  // Note that for a request with a body, such as a POST or PUT request, the
  // library will include the body data when signing only if the request has
  // the proper content type header:
  //
  //   [request setValue:@"application/x-www-form-urlencoded"
  //  forHTTPHeaderField:@"Content-Type"];

  // Synchronous fetches like this are a really bad idea in Cocoa applications
  //
  // For a very easy async alternative, we could use GTMHTTPFetcher
  NSError *error = nil;
  NSURLResponse *response = nil;
  NSData *data = [NSURLConnection sendSynchronousRequest:request
                                       returningResponse:&response
                                                   error:&error];

  if (data) {
    // API fetch succeeded
    NSString *str = [[[NSString alloc] initWithData:data
                                           encoding:NSUTF8StringEncoding] autorelease];
    NSLog(@"API response: %@", str);
  } else {
    // fetch failed
    NSLog(@"API fetch error: %@", error);
  }
}

#pragma mark -

- (void)displayErrorThatTheCodeNeedsATwitterConsumerKeyAndSecret {
  NSBeginAlertSheet(@"Error", nil, nil, nil, mMainWindow,
                    self, NULL, NULL, NULL,
                    @"The sample code requires a valid Twitter consumer key"
                    " and consumer secret to sign in to Twitter");
}

- (void)signInFetchStateChanged:(NSNotification *)note {
  // this just lets the user know something is happening during the
  // sign-in sequence's "invisible" fetches to obtain tokens
  //
  // the type of token obtained is available as
  //   [[note userInfo] objectForKey:kGTMOAuthFetchTypeKey]
  //
  if ([[note name] isEqual:kGTMOAuthFetchStarted]) {
    [mSpinner startAnimation:self];
  } else {
    [mSpinner stopAnimation:self];
  }
}

- (void)signInNetworkLost:(NSNotification *)note {
  // the network dropped for 30 seconds
  //
  // we could alert the user and wait for notification that the network has
  // has returned, or just cancel the sign-in sheet, as shown here
  GTMOAuthSignIn *signIn = [note object];
  GTMOAuthWindowController *controller = [signIn delegate];
  [controller cancelSigningIn];
}

- (void)updateUI {
  // update the text showing the signed-in state and the button title
  if ([self isSignedIn]) {
    // signed in
    NSString *token = [mAuth token];
    NSString *email = [mAuth userEmail];

    BOOL isVerified = [[mAuth userEmailIsVerified] boolValue];
    if (!isVerified) {
      // email address is not verified
      //
      // The email address is listed with the account info on the server, but
      // has not been confirmed as belonging to the owner of this account.
      email = [email stringByAppendingString:@" (unverified)"];
    }

    [mTokenField setStringValue:(token != nil ? token : @"")];
    [mUsernameField setStringValue:(email != nil ? email : @"")];
    [mSignInOutButton setTitle:@"Sign Out"];
  } else {
    // signed out
    [mUsernameField setStringValue:@"-Not signed in-"];
    [mTokenField setStringValue:@"-No token-"];
    [mSignInOutButton setTitle:@"Sign In..."];
  }
}

- (void)setAuthentication:(GTMOAuthAuthentication *)auth {
  [mAuth autorelease];
  mAuth = [auth retain];
}

@end
