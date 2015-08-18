# GTM OAuth: Google Toolbox for Mac - OAuth Controllers #

**Project site** <https://github.com/google/gtm-oauth><br>
**Discussion group** <http://groups.google.com/group/gtm-oauth>


## Release History ##

31-August-2012

Google-specific support removed, as Google has deprecated OAuth 1 in
favor of OAuth 2.


2-August-2011

Projects may now define GTM_OAUTH_SKIP_GOOGLE_SUPPORT to exclude
Google-specific code. The GTMOAuth project file also now includes
"non-Google" targets for building without Google-specific code.


25-May-2011

Mac window controller now opens pop-up window links in an external browser
by default, and provides an externalRequestSelector property to let the
client provide custom handling.


22-Mar-2011

Added +scopeWithStrings: utility method.


18-Oct-2010

Fix issue handling URLs with ports. (thanks dunhamsteve)


4-Oct-2010

Update SignIn object to retain the controller during sign-in.


Release 1.0.0
9-Sept-2010

Initial public release.
