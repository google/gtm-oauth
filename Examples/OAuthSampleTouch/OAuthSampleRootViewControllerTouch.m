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
// OAuthSampleRootViewControllerTouch.m

#import "OAuthSampleRootViewControllerTouch.h"
#import "GTMOAuthViewControllerTouch.h"

#ifndef UI_USER_INTERFACE_IDIOM()
#define UI_USER_INTERFACE_IDIOM() 0
#endif

static NSString *const kAppServiceName = @"OAuth Sample: Google Contacts";
static NSString *const kShouldSaveInKeychainKey = @"shouldSaveInKeychain";

static NSString *const kTwitterAppServiceName = @"OAuth Sample: Twitter";
static NSString *const kTwitterServiceName = @"Twitter";

@interface OAuthSampleRootViewControllerTouch()
- (void)viewController:(GTMOAuthViewControllerTouch *)viewController
      finishedWithAuth:(GTMOAuthAuthentication *)auth
                 error:(NSError *)error;
- (void)incrementNetworkActivity:(NSNotification *)notify;
- (void)decrementNetworkActivity:(NSNotification *)notify;
- (void)signInNetworkLostOrFound:(NSNotification *)notify;
- (GTMOAuthAuthentication *)authForTwitter;
- (void)doAnAuthenticatedAPIFetch;
- (BOOL)shouldSaveInKeychain;
@end

@implementation OAuthSampleRootViewControllerTouch

@synthesize serviceSegments = mServiceSegments;
@synthesize shouldSaveInKeychainSwitch = mShouldSaveInKeychainSwitch;
@synthesize signInOutButton = mSignInOutButton;
@synthesize emailField = mEmailField;
@synthesize tokenField = mTokenField;

- (void)awakeFromNib {
  NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
  [nc addObserver:self selector:@selector(incrementNetworkActivity:) name:kGTMOAuthFetchStarted object:nil];
  [nc addObserver:self selector:@selector(decrementNetworkActivity:) name:kGTMOAuthFetchStopped object:nil];
  [nc addObserver:self selector:@selector(signInNetworkLostOrFound:) name:kGTMOAuthNetworkLost  object:nil];
  [nc addObserver:self selector:@selector(signInNetworkLostOrFound:) name:kGTMOAuthNetworkFound object:nil];

  // Get the saved authentication, if any, from the keychain.
  //
  // first, we'll try to get the saved Google authentication, if any
  GTMOAuthAuthentication *auth;
  auth = [GTMOAuthViewControllerTouch authForGoogleFromKeychainForName:kAppServiceName];
  if ([auth canAuthorize]) {
    // select the Google index
    [mServiceSegments setSelectedSegmentIndex:0];
  } else {
    // there is no saved Google authentication
    //
    // perhaps we have a saved authorization for Twitter instead; try getting
    // that from the keychain
    auth = [self authForTwitter];
    if (auth) {
      BOOL didAuth = [GTMOAuthViewControllerTouch authorizeFromKeychainForName:kTwitterAppServiceName
                                                                  authentication:auth];
      if (didAuth) {
        // select the Twitter index
        [mServiceSegments setSelectedSegmentIndex:1];
      }
    }
  }

  // save the authentication object, which holds the auth tokens
  [self setAuthentication:auth];

  BOOL isRemembering = [self shouldSaveInKeychain];
  [mShouldSaveInKeychainSwitch setOn:isRemembering];
  [self updateUI];
}

- (void)dealloc {
  NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
  [nc removeObserver:self];
  [mSignInOutButton release];
  [mShouldSaveInKeychainSwitch release];
  [mServiceSegments release];
  [mEmailField release];
  [mTokenField release];
  [mAuth release];
  [super dealloc];
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)orientation {
  // Returns non-zero on iPad, but backward compatible to SDKs earlier than 3.2.
  if (UI_USER_INTERFACE_IDIOM()) {
    return YES;
  }
  return [super shouldAutorotateToInterfaceOrientation:orientation];
}

- (BOOL)isSignedIn {
  BOOL isSignedIn = [mAuth canAuthorize];
  return isSignedIn;
}

- (BOOL)isGoogleSegmentSelected {
  int segmentIndex = [mServiceSegments selectedSegmentIndex];
  return (segmentIndex == 0);
}

- (IBAction)signInOutClicked:(id)sender {
  if (![self isSignedIn]) {
    // sign in
    if ([self isGoogleSegmentSelected]) {
      [self signInToGoogle];
    } else {
      [self signInToTwitter];
    }
  } else {
    // sign out
    [self signOut];
  }
  [self updateUI];
}

// UISwitch does the toggling for us. We just need to read the state.
- (IBAction)toggleShouldSaveInKeychain:(id)sender {
  [[NSUserDefaults standardUserDefaults] setBool:[sender isOn]
                                          forKey:kShouldSaveInKeychainKey];
}

- (void)signOut {
  if ([[mAuth serviceProvider] isEqual:kGTMOAuthServiceProviderGoogle]) {
    // remove the token from Google's servers
    [GTMOAuthViewControllerTouch revokeTokenForGoogleAuthentication:mAuth];
  }

  // remove the stored Google authentication from the keychain, if any
  [GTMOAuthViewControllerTouch removeParamsFromKeychainForName:kAppServiceName];

  // remove the stored Twitter authentication from the keychain, if any
  [GTMOAuthViewControllerTouch removeParamsFromKeychainForName:kTwitterAppServiceName];

  // Discard our retained authentication object.
  [self setAuthentication:nil];

  [self updateUI];
}

- (void)signInToGoogle {
  [self signOut];

  NSString *keychainAppServiceName = nil;
  if ([self shouldSaveInKeychain]) {
    keychainAppServiceName = kAppServiceName;
  }

  // For GTM applications, the scope is available as
  //   NSString *scope = [[service class] authorizationScope]
  NSString *scope = @"http://www.google.com/m8/feeds/";

  // ### Important ###
  // GTMOAuthViewControllerTouch is not designed to be reused. Make a new
  // one each time you are going to show it.

  // Display the autentication view.
  GTMOAuthViewControllerTouch *viewController = [[[GTMOAuthViewControllerTouch alloc]
            initWithScope:scope
                 language:nil
           appServiceName:keychainAppServiceName
                 delegate:self
         finishedSelector:@selector(viewController:finishedWithAuth:error:)] autorelease];

  // You can set the title of the navigationItem of the controller here, if you want.

  // Optional: display some html briefly before the sign-in page loads
  NSString *html = @"<html><body bgcolor=silver><div align=center>Loading sign-in page...</div></body></html>";
  [viewController setInitialHTMLString:html];

  [[self navigationController] pushViewController:viewController animated:YES];
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
  if (auth == nil) {
    // perhaps display something friendlier in the UI?
    NSAssert(NO, @"A valid consumer key and consumer secret are required for signing in to Twitter");
  }

  // set the callback URL to which the site should redirect, and for which
  // the OAuth controller should look to determine when sign-in has
  // finished or been canceled
  //
  // This URL does not need to be for an actual web page; it will not be
  // loaded
  [auth setCallback:@"http://www.example.com/OAuthCallback"];

  NSString *keychainAppServiceName = nil;
  if ([self shouldSaveInKeychain]) {
    keychainAppServiceName = kTwitterAppServiceName;
  }

  // Display the autentication view.
  GTMOAuthViewControllerTouch *viewController;
  viewController = [[[GTMOAuthViewControllerTouch alloc] initWithScope:scope
                language:nil
         requestTokenURL:requestURL
       authorizeTokenURL:authorizeURL
          accessTokenURL:accessURL
          authentication:auth
          appServiceName:keychainAppServiceName
                delegate:self
        finishedSelector:@selector(viewController:finishedWithAuth:error:)] autorelease];

  // We can set a URL for deleting the cookies after sign-in so the next time
  // the user signs in, the browser does not assume the user is already signed
  // in
  [viewController setBrowserCookiesURL:[NSURL URLWithString:@"http://api.twitter.com/"]];

  // You can set the title of the navigationItem of the controller here, if you want.

  [[self navigationController] pushViewController:viewController animated:YES];
}

- (void)viewController:(GTMOAuthViewControllerTouch *)viewController
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
    // or store the authentication object into a GTM service object like
    //
    //   [[self contactService] setAuthorizer:auth];

    // save the authentication object
    [self setAuthentication:auth];

    // Just to prove we're signed in, we'll attempt an authenticated fetch for the
    // signed-in user
    [self doAnAuthenticatedAPIFetch];
  }

  [self updateUI];
}

- (void)doAnAuthenticatedAPIFetch {
  NSString *urlStr;
  if ([self isGoogleSegmentSelected]) {
    // Google Contacts feed
    urlStr = @"http://www.google.com/m8/feeds/contacts/default/thin";
  } else {
    // Twitter status feed
    urlStr = @"http://api.twitter.com/1/statuses/home_timeline.json";
  }

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

- (void)incrementNetworkActivity:(NSNotification *)notify {
  ++mNetworkActivityCounter;
  if (1 == mNetworkActivityCounter) {
    UIApplication *app = [UIApplication sharedApplication];
    [app setNetworkActivityIndicatorVisible:YES];
  }
}

- (void)decrementNetworkActivity:(NSNotification *)notify {
  --mNetworkActivityCounter;
  if (0 == mNetworkActivityCounter) {
    UIApplication *app = [UIApplication sharedApplication];
    [app setNetworkActivityIndicatorVisible:NO];
  }
}

- (void)signInNetworkLostOrFound:(NSNotification *)notify {
  if ([[notify name] isEqual:kGTMOAuthNetworkLost]) {
    // network connection was lost; alert the user, or dismiss
    // the sign-in view with
    //   [[[notify object] delegate] cancelSigningIn];
  } else {
    // network connection was found again
  }
}

#pragma mark -

- (void)updateUI {
  // update the text showing the signed-in state and the button title
  // A real program would use NSLocalizedString() for strings shown to the user.
  if ([self isSignedIn]) {
    // signed in
    NSString *email = [mAuth userEmail];
    NSString *token = [mAuth token];

    [mEmailField setText:email];
    [mTokenField setText:token];
    [mSignInOutButton setTitle:@"Sign Out"];
  } else {
    // signed out
    [mEmailField setText:@"Not signed in"];
    [mTokenField setText:@"No authorization token"];
    [mSignInOutButton setTitle:@"Sign In..."];
  }
  BOOL isRemembering = [self shouldSaveInKeychain];
  [mShouldSaveInKeychainSwitch setOn:isRemembering];
}

- (void)setAuthentication:(GTMOAuthAuthentication *)auth {
  [mAuth autorelease];
  mAuth = [auth retain];
}

- (BOOL)shouldSaveInKeychain {
  return [[NSUserDefaults standardUserDefaults] boolForKey:kShouldSaveInKeychainKey];
}

@end

