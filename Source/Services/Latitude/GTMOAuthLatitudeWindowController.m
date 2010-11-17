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

//
//  GTMOAuthLatitudeWindowController.h
//

#import <Foundation/Foundation.h>

#if !(TARGET_OS_IPHONE) && (!GTL_REQUIRE_SERVICE_INCLUDES || GTL_INCLUDE_LATITUDE_SERVICE)

#import "GTMOAuthLatitudeWindowController.h"

@implementation GTMOAuthLatitudeWindowController

- (id)initWithScope:(NSString *)scope
        consumerKey:(NSString *)consumerKey
         privateKey:(NSString *)privateKey
             domain:(NSString *)domain
           language:(NSString *)language
     appServiceName:(NSString *)keychainAppServiceName
     resourceBundle:(NSBundle *)bundle {

  // we need a non-standard authorizeURL
  NSURL *requestURL = [NSURL URLWithString:@"https://www.google.com/accounts/OAuthGetRequestToken"];
  NSURL *authorizeURL = [NSURL URLWithString:@"https://www.google.com/latitude/apps/OAuthAuthorizeToken?location=all&granularity=best"];
  NSURL *accessURL = [NSURL URLWithString:@"https://www.google.com/accounts/OAuthGetAccessToken"];

  GTMOAuthAuthentication *auth;
  auth = [[[GTMOAuthAuthentication alloc] initWithSignatureMethod:kGTMOAuthSignatureMethodHMAC_SHA1
                                                      consumerKey:consumerKey
                                                       privateKey:privateKey] autorelease];
  auth.callback = @"http://www.google.com/Auth_Done";
  auth.mobile = @"mobile";
  auth.serviceProvider = kGTMOAuthServiceProviderGoogle;
  auth.domain = domain;

  self = [super initWithScope:scope
                     language:language
              requestTokenURL:requestURL
            authorizeTokenURL:authorizeURL
               accessTokenURL:accessURL
               authentication:auth
               appServiceName:keychainAppServiceName
               resourceBundle:bundle];
  return self;
}

@end

#endif // !(TARGET_OS_IPHONE) && (!GTL_REQUIRE_SERVICE_INCLUDES || GTL_INCLUDE_LATITUDE_SERVICE)
