//
//  MainController.h
//  Gabtastik
//
//  Created by Danny Espinoza on 4/24/08.
//  Copyright 2008 Mesa Dynamics, LLC. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <WebKit/WebKit.h>

#import "Growl/GrowlApplicationBridge.h"

@interface MainController : NSWindowController <GrowlApplicationBridgeDelegate> {
	IBOutlet WebView* webView;
	IBOutlet NSTextField* webTitle;
	IBOutlet NSProgressIndicator* webWait;
	IBOutlet NSButton* reload;
	IBOutlet NSPanel* preferences;
	IBOutlet NSWindow* about;
	IBOutlet NSButton* prefAllSpaces;
	IBOutlet NSView* facebookHelp;
	IBOutlet NSView* googleHelp;
	
	NSString* service;	
	WebView* browser;

	NSTimer* googleVerifyTimer;
	
	WebView* facebook;
	WebView* google;
	WebView* meebo;
	WebView* hahlo;
	
	NSString* facebookTitle;
	NSString* googleTitle;
	NSString* meeboTitle;
	NSString* hahloTitle;
	
	NSWindow* facebookLoginHelp;
	NSWindow* googleLoginHelp;
		
	BOOL resetFacebook;
	BOOL resetGoogle;
	BOOL resetMeebo;
	BOOL resetHahlo;
	
	BOOL loginFacebook;
	BOOL loginGoogle;
	
	BOOL redirectToBrowser;
	BOOL ignoreResize;
	
	NSMutableArray* facebookPings;
	NSMutableArray* googlePings;
	
	id badge;
		
	// growl
	BOOL growlReady;
}

- (void)setupWebView;
- (void)webReady:(id)sender;
- (void)openService:(NSString*)serviceName force:(BOOL)force;
- (void)loadService;
- (void)saveFrames;
- (void)verifyGoogle:(id)sender;

- (void)clearFacebook;
- (void)clearGoogle;
- (void)updateBadge:(id)sender;
- (void)simulateClick:(NSPoint)where;

- (IBAction)handleHome:(id)sender;
- (IBAction)handleReload:(id)sender;
- (IBAction)handleGab:(id)sender;
- (IBAction)handleLogout:(id)sender;
- (IBAction)handlePreferenceOpen:(id)sender;
- (IBAction)handlePreferenceClose:(id)sender;
- (IBAction)handleOpacityChange:(id)sender;
@end

@interface NSWindow (Leopard)
- (void)setCollectionBehavior:(NSWindowCollectionBehavior)collectionBehavior;
@end

@interface WebPreferences (Private)
- (void)setCacheModel:(WebCacheModel)cacheModel;
@end

