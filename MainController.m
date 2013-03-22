//
//  MainController.m
//  Gabtastik
//
//  Created by Danny Espinoza on 4/24/08.
//  Copyright 2008 Mesa Dynamics, LLC. All rights reserved.
//

#import "MainController.h"
#import "Transformers.h"
#import "WebView+Amnesty.h"
#import "MAAttachedWindow.h"
#import "CTBadge.h"

typedef double EventTime;
EventTime GetCurrentEventTime(void);

static NSString* serviceNone = @"";
static NSString* serviceFacebook = @"@facebook.com";
static NSString* serviceGoogle = @"@google.com";
static NSString* serviceMeebo = @"@meebo.com";
static NSString* serviceHahlo = @"@hahlo.com";


@implementation MainController

- (id)init
{
	if(self = [super init]) {
		NSMutableDictionary* defaultPrefs = [NSMutableDictionary dictionary];
		[defaultPrefs setObject:[NSNumber numberWithInt:NSNormalWindowLevel] forKey:@"MainWindowLevel"];
		[defaultPrefs setObject:[NSNumber numberWithInt:100] forKey:@"MainWindowOpacity"];
		[defaultPrefs setObject:[NSNumber numberWithBool:NO] forKey:@"MainWindowGoOpaque"];
		[defaultPrefs setObject:[NSNumber numberWithBool:YES] forKey:@"MainWindowAllSpaces"];

		[defaultPrefs setObject:serviceFacebook forKey:@"DefaultService"];
		[defaultPrefs setObject:[NSNumber numberWithFloat:820.0] forKey:@"WidthBrowser"];
		[defaultPrefs setObject:[NSNumber numberWithFloat:403.0] forKey:@"HeightBrowser"];
		[defaultPrefs setObject:[NSNumber numberWithFloat:400.0] forKey:@"WidthFacebook"];
		[defaultPrefs setObject:[NSNumber numberWithFloat:403.0] forKey:@"HeightFacebook"];
		[defaultPrefs setObject:[NSNumber numberWithFloat:300.0] forKey:@"WidthGoogle"];
		[defaultPrefs setObject:[NSNumber numberWithFloat:492.0] forKey:@"HeightGoogle"];
		[defaultPrefs setObject:[NSNumber numberWithFloat:403.0] forKey:@"HeightMeebo"];
		[defaultPrefs setObject:[NSNumber numberWithFloat:540.0] forKey:@"HeightHahlo"];
		[defaultPrefs setObject:[NSNumber numberWithBool:YES] forKey:@"SingleWindowMode"];
		
		[[NSUserDefaults standardUserDefaults] registerDefaults:defaultPrefs];
		[[NSUserDefaultsController sharedUserDefaultsController] setInitialValues:defaultPrefs];

		NSValueTransformer* transformer = [[[ValueIsNotOneTransformer alloc] init] autorelease];
		[NSValueTransformer setValueTransformer:transformer forName:@"ValueIsNotOneTransformer"];

		service = nil;		
		browser = nil;
	
		googleVerifyTimer = nil;
		
		facebook = nil;
		google = nil;
		meebo = nil;
		hahlo = nil;
		
		facebookTitle = nil;
		googleTitle = nil;
		meeboTitle = nil;
		hahloTitle = nil;
		
		facebookLoginHelp = nil;
		googleLoginHelp = nil;
		
		resetFacebook = NO;
		resetGoogle = NO;
		resetMeebo = NO;
		resetHahlo = NO;
		
		loginFacebook = NO;
		loginGoogle = NO;
		
		redirectToBrowser = NO;
		ignoreResize = NO;
		
		facebookPings = [[NSMutableArray alloc] init];
		googlePings = [[NSMutableArray alloc] init];

		badge = nil;
	}
	
	return self;
}

- (void)awakeFromNib
{
	[NSApp setDelegate:self];

	[about setLevel:NSPopUpMenuWindowLevel+1];
 	[about center];

	[self setWindowFrameAutosaveName:@"MainWindow"];
	[[self window] setMinSize:NSMakeSize(300.0, 403.0)];

	BOOL supportsSpaces = [[self window] respondsToSelector:@selector(setCollectionBehavior:)];
	if(supportsSpaces == NO)
		[prefAllSpaces setHidden:YES];
		
	BOOL firstLaunch = NO;
	if([[NSUserDefaults standardUserDefaults] stringForKey:@"NSWindow Frame MainWindow"] == nil) {
		ignoreResize = YES;

		[[self window] setFrame:NSMakeRect(0.0, 0.0, 360.0, 403.0) display:NO];
		[[self window] center];

		ignoreResize = NO;

		if(supportsSpaces)
			[[self window] setCollectionBehavior:NSWindowCollectionBehaviorCanJoinAllSpaces];

		firstLaunch = YES;
	}
	else {
		id defaults = [NSUserDefaults standardUserDefaults];
		
		NSNumber* levelDefault = [defaults valueForKey:@"MainWindowLevel"];
		int level = (levelDefault ? [levelDefault intValue] : NSNormalWindowLevel);
		if(level == -1)
			level = kCGDesktopIconWindowLevel-1;
		[[self window] setLevel:level];

		NSNumber* opacityDefault =  [defaults valueForKey:@"MainWindowOpacity"];
		int opacity = (opacityDefault ? [opacityDefault intValue] : 100);
		if(opacity == 100)
			[[self window] setAlphaValue:1.0];
		else
			[[self window] setAlphaValue:(float)opacity * .01];
	
		if(supportsSpaces) {
			NSNumber* spacesDefault = [defaults valueForKey:@"MainWindowAllSpaces"];
			if([spacesDefault boolValue] == YES)
				[[self window] setCollectionBehavior:NSWindowCollectionBehaviorCanJoinAllSpaces];
			else
				[[self window] setCollectionBehavior:NSWindowCollectionBehaviorDefault];
		}
	}

	[webView setHostWindow:[self window]];
	
	service = [[NSString alloc] initWithString:serviceNone];
	[webView setGroupName:serviceNone];

	[self setupWebView];
}

- (void)setupWebView
{
	if([WebView respondsToSelector:@selector(_setShouldUseFontSmoothing:)])
		[WebView _setShouldUseFontSmoothing:YES];
	
	if([webView respondsToSelector:@selector(_setDashboardBehavior:to:)]) {
		[webView _setDashboardBehavior:WebDashboardBehaviorAlwaysSendMouseEventsToAllWindows to:YES];
		[webView _setDashboardBehavior:WebDashboardBehaviorAlwaysAcceptsFirstMouse to:YES];
		[webView _setDashboardBehavior:WebDashboardBehaviorAllowWheelScrolling to:YES];
		[webView _setDashboardBehavior:WebDashboardBehaviorAlwaysSendActiveNullEventsToPlugIns to:NO];
	}
	
	[webView setEditable:NO];
	
	WebPreferences* prefs = [webView preferences];
	if([prefs respondsToSelector:@selector(setCacheModel:)])
		[prefs setCacheModel:WebCacheModelDocumentViewer];

	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(webReady:) name:WebViewProgressFinishedNotification object:webView];	
}

- (void)webReady:(id)sender
{
	[[self window] makeFirstResponder:webView];
	
	if(resetGoogle && [service isEqualToString:serviceGoogle]) {
		resetGoogle = NO;
		loginGoogle = NO;

		if(googleLoginHelp) {
			[[self window] removeChildWindow:googleLoginHelp];
			[googleLoginHelp orderOut:self];
			[googleLoginHelp release];
			googleLoginHelp = nil;
		}
		
#if !defined(GoogleTalkGadget)
		NSString* saveService = [NSString stringWithString:service];
		[service release];
		service = nil;
		
		[self openService:saveService force:YES];
#endif
		
		return;
	}
	
	ignoreResize = YES;
	
	NSSize minSize = [[self window] minSize];
	NSSize maxSize = [[self window] maxSize];
	NSRect frame = [[self window] frame];

	id defaults = [NSUserDefaults standardUserDefaults];
	
	if([service isEqualToString:serviceFacebook]) {
		if((int)minSize.width != 400 || (int)minSize.height != 403) {
			minSize.width = 400.0;
			minSize.height = 403.0;
			[[self window] setMinSize:minSize];
		}
		
		if((int)maxSize.width != 1024 || (int)maxSize.height != 4096) {
			maxSize.width = 1024.0;
			maxSize.height = 4096.0;
			[[self window] setMaxSize:maxSize];
		}
		
		if(loginFacebook) {
			frame.origin.y += (frame.size.height - 562.0);
			frame.size.width = 820.0;
			frame.size.height = 562.0;
			[[self window] setFrame:frame display:YES animate:YES];
		}
		else {
			NSNumber* x = [defaults valueForKey:@"WidthFacebook"];
			NSNumber* y = [defaults valueForKey:@"HeightFacebook"];
			if(x && y) {
				frame.origin.y += (frame.size.height - [y floatValue]);
				frame.size.width = [x floatValue];
				frame.size.height = [y floatValue];
				
				if((int)frame.size.width < 400)
					frame.size.width = 400.0;
				
				[[self window] setFrame:frame display:YES animate:YES];
			}
			else if((int)frame.size.width < 400) {
				frame.size.width = 400.0;
				[[self window] setFrame:frame display:YES animate:YES];
			}
		}
	}
	else if([service isEqualToString:serviceGoogle]) {
#if defined(GoogleTalkGadget)
		if((int)minSize.width != 348 || (int)minSize.height != 560) {
			minSize.width = 348.0;
			minSize.height = 560.0;
			[[self window] setMinSize:minSize];
		}	
#else
		if((int)minSize.width != 300 || (int)minSize.height != 492) {
			minSize.width = 300.0;
			minSize.height = 492.0;
			[[self window] setMinSize:minSize];
		}	

		if((int)maxSize.width != 1024 || (int)maxSize.height != 4096) {
			maxSize.width = 1024.0;
			maxSize.height = 4096.0;
			[[self window] setMaxSize:maxSize];
		}
#endif
		
		if(loginGoogle) {
			if((int)maxSize.width != 1024 || (int)maxSize.height != 4096) {
				maxSize.width = 1024.0;
				maxSize.height = 4096.0;
				[[self window] setMaxSize:maxSize];
			}

			frame.origin.y += (frame.size.height - 560.0);
			frame.size.width = 820.0;
			frame.size.height = 560.0;
			[[self window] setFrame:frame display:YES animate:YES];
		}
		else {
#if defined(GoogleTalkGadget)
			if((int)maxSize.width != 348 || (int)maxSize.height != 560) {
				maxSize.width = 348.0;
				maxSize.height = 560.0;
				[[self window] setMaxSize:maxSize];
			}
					
			if((int)frame.size.width != 348 || (int)frame.size.height != 560) {
				frame.origin.y += (frame.size.height - 560.0);
				frame.size.width = 348.0;
				frame.size.height = 560.0;
				[[self window] setFrame:frame display:YES animate:YES];
			}
#else
			NSNumber* x = [defaults valueForKey:@"WidthGoogle"];
			NSNumber* y = [defaults valueForKey:@"HeightGoogle"];
			if(x && y) {
				frame.origin.y += (frame.size.height - [y floatValue]);
				frame.size.width = [x floatValue];
				frame.size.height = [y floatValue];
				[[self window] setFrame:frame display:YES animate:YES];
			}
			else if((int)frame.size.width < 300) {
				frame.size.width = 300.0;
				[[self window] setFrame:frame display:YES animate:YES];
			}
#endif
		}
	}
	else if([service isEqualToString:serviceMeebo]) {
		float w = [NSScroller scrollerWidth];
		float minWidth = 328.0 + w;
		
		if((int)minSize.width != minWidth || (int)minSize.height != 403.0) {
			minSize.width = minWidth;
			minSize.height = 403.0;
			[[self window] setMinSize:minSize];
		}
		
		if((int)maxSize.width != minWidth || (int)maxSize.height != 4096.0) {
			maxSize.width = minWidth;
			maxSize.height = 4096.0;
			[[self window] setMaxSize:maxSize];
		}
		
		NSNumber* y = [defaults valueForKey:@"HeightMeebo"];
		
		if(y) {
			frame.origin.y += (frame.size.height - [y floatValue]);
			frame.size.height = [y floatValue];
			[[self window] setFrame:frame display:YES animate:YES];
		}
		if((int)frame.size.width != minWidth) {
			frame.size.width = minWidth;
			[[self window] setFrame:frame display:YES animate:YES];
		}
	}
	else if([service isEqualToString:serviceHahlo]) {
		float w = [NSScroller scrollerWidth];
		float minWidth = 328.0 + w;
		
		if((int)minSize.width != minWidth || (int)minSize.height != 403.0) {
			minSize.width = minWidth;
			minSize.height = 403.0;
			[[self window] setMinSize:minSize];
		}
		
		if((int)maxSize.width != minWidth || (int)maxSize.height != 4096.0) {
			maxSize.width = minWidth;
			maxSize.height = 4096.0;
			[[self window] setMaxSize:maxSize];
		}
		
		NSNumber* y = [defaults valueForKey:@"HeightHahlo"];
		
		if(y) {
			frame.origin.y += (frame.size.height - [y floatValue]);
			frame.size.height = [y floatValue];
			[[self window] setFrame:frame display:YES animate:YES];
		}
		if((int)frame.size.width != minWidth) {
			frame.size.width = minWidth;
			[[self window] setFrame:frame display:YES animate:YES];
		}
	}
	
	ignoreResize = NO;
	
	[webWait stopAnimation:self];
	[reload setHidden:NO];

	[defaults setObject:service forKey:@"DefaultService"];
	redirectToBrowser = YES;
}

- (void)openService:(NSString*)serviceName force:(BOOL)force
{
	[NSApp activateIgnoringOtherApps:YES];
	[[self window] makeKeyAndOrderFront:self];
	
	if([serviceName isEqualTo:service] == NO) {
		[reload setHidden:YES];
		[webWait startAnimation:self];
		
		[webTitle setStringValue:[NSString stringWithFormat:@"%@", serviceName]];

		if([[webView groupName] isEqualToString:serviceNone] == NO) {
			NSRect frame = [webView frame];
			
			//[webView setFrameLoadDelegate:nil];
			[webView setPolicyDelegate:nil];
			[webView setResourceLoadDelegate:nil];
			[webView setUIDelegate:nil];
			[webView setDownloadDelegate:nil];

			[webView setHidden:YES];
			///[webView setHostWindow:nil];
			[webView removeFromSuperview];
			
			BOOL preloaded = NO;
			WebView* newWebView = nil;
			if([serviceName isEqualToString:serviceFacebook] && facebook) {
				if(facebookTitle)
					[webTitle setStringValue:facebookTitle];
	
				if(facebookLoginHelp) {
					[(MAAttachedWindow*)facebookLoginHelp updateGeometry];
					[[self window] addChildWindow:facebookLoginHelp ordered:NSWindowAbove];
				}

				if(googleLoginHelp) {
					[[self window] removeChildWindow:googleLoginHelp];
					[googleLoginHelp orderOut:self];
				}
				
				newWebView = facebook;
				[newWebView setFrame:frame];
				preloaded = YES;
			}
			else if([serviceName isEqualToString:serviceGoogle] && google) {
				if(googleTitle)
					[webTitle setStringValue:googleTitle];

				if(googleLoginHelp) {
					[(MAAttachedWindow*)googleLoginHelp updateGeometry];
					[[self window] addChildWindow:googleLoginHelp ordered:NSWindowAbove];
				}
				
				if(facebookLoginHelp) {
					[[self window] removeChildWindow:facebookLoginHelp];
					[facebookLoginHelp orderOut:self];
				}
				
				newWebView = google;
				[newWebView setFrame:frame];
				preloaded = YES;
			}
			else if([serviceName isEqualToString:serviceMeebo] && meebo) {
				if(meeboTitle)
					[webTitle setStringValue:meeboTitle];
				
				if(facebookLoginHelp) {
					[[self window] removeChildWindow:facebookLoginHelp];
					[facebookLoginHelp orderOut:self];
				}
				
				if(googleLoginHelp) {
					[[self window] removeChildWindow:googleLoginHelp];
					[googleLoginHelp orderOut:self];
				}
				
				newWebView = meebo;
				[newWebView setFrame:frame];
				preloaded = YES;
			}
			else if([serviceName isEqualToString:serviceHahlo] && hahlo) {
				if(hahloTitle)
					[webTitle setStringValue:hahloTitle];
				
				if(facebookLoginHelp) {
					[[self window] removeChildWindow:facebookLoginHelp];
					[facebookLoginHelp orderOut:self];
				}
				
				if(googleLoginHelp) {
					[[self window] removeChildWindow:googleLoginHelp];
					[googleLoginHelp orderOut:self];
				}
				
				newWebView = hahlo;
				[newWebView setFrame:frame];
				preloaded = YES;
			}
			else {
				newWebView = [[WebView alloc] initWithFrame:frame frameName:nil groupName:nil];
				[newWebView setPreferencesIdentifier:[webView preferencesIdentifier]];
				[newWebView setAutoresizingMask:[webView autoresizingMask]];
			}
			
			[newWebView setFrameLoadDelegate:self];
			[newWebView setPolicyDelegate:self];
			[newWebView setResourceLoadDelegate:self];
			[newWebView setUIDelegate:self];
			[newWebView setDownloadDelegate:self];

			[[[self window] contentView] addSubview:newWebView];
			[newWebView setHostWindow:[self window]];
			[newWebView setHidden:NO];
			
			webView = newWebView;
			
			if(preloaded) {
				if(force == NO) {
					[service release];
					service = [[NSString alloc] initWithString:serviceName];

					if([service isEqualToString:serviceFacebook] && [facebookPings count] > 0)
						[self clearFacebook];
					
					if([service isEqualToString:serviceGoogle] && [googlePings count] > 0)
						[self clearGoogle];

					[self performSelectorOnMainThread:@selector(webReady:) withObject:self waitUntilDone:NO];
					return;
				}
			}
			else
				[self setupWebView];
		}
		
		[service release];
		service = [[NSString alloc] initWithString:serviceName];
		
		[self loadService];
	}
}

- (void)loadService
{
	redirectToBrowser = NO;

	WebFrame* mainFrame = [webView mainFrame];
	WebFrameView* mainFrameView = [mainFrame frameView];

	if([service isEqualToString:serviceFacebook]) {
		if(facebook == nil) {
			facebook = [webView retain];
			[webView setGroupName:service];
		}
		
		[mainFrameView setAllowsScrolling:NO];
		[webView setProhibitsMainFrameScrolling:YES];
		[webView setCustomUserAgent:@"Mozilla/5.0 (Macintosh; U; Intel Mac OS X 10_5_2; en-us) AppleWebKit/525.18 (KHTML, like Gecko) Version/3.1.1 Safari/525.18"];
		
		NSString* facebookChatURL = @"http://www.facebook.com/presence/popout.php";
		NSMutableURLRequest* request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:facebookChatURL]];
		[[webView mainFrame] loadRequest:request];
	}
	else if([service isEqualToString:serviceGoogle]) {
		if(google == nil) {
			google = [webView retain];
			[webView setGroupName:service];
		}
		
		[mainFrameView setAllowsScrolling:NO];
		[webView setProhibitsMainFrameScrolling:YES];
		[webView setCustomUserAgent:@"Mozilla/5.0 (Macintosh; U; Intel Mac OS X 10_5_2; en-us) AppleWebKit/525.18 (KHTML, like Gecko) Version/3.1.1 Safari/525.18"];

#if defined(GoogleTalkGadget)		
		NSString* googleChatHTML = @"<html><head><title>Google Talk</title><meta http-equiv='content-type' content='text/html;charset=iso-8859-1'></head><body style='border:0px;'><script src='http://gmodules.com/ig/ifr?url=http://www.google.com/ig/modules/googletalk.xml&amp;synd=gabtastik&amp;w=320&amp;h=451&amp;title=Google+Talk&amp;lang=en&amp;country=US&amp;border=%23ffffff%7C3px%2C1px+solid+%23999999&amp;output=js'></script></body>";
		[[webView mainFrame] loadHTMLString:googleChatHTML baseURL:nil];
#else
		NSString* googleChatURL = @"http://talkgadget.google.com/talkgadget/popout";
		NSMutableURLRequest* request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:googleChatURL]];
		[[webView mainFrame] loadRequest:request];	
#endif
	}
	else if([service isEqualToString:serviceMeebo]) {
		if(meebo == nil) {
			meebo = [webView retain];
			[webView setGroupName:service];
		}
		
		[mainFrameView setAllowsScrolling:YES];
		[webView setProhibitsMainFrameScrolling:NO];
		[webView setCustomUserAgent:@"Mozilla/5.0 (iPhone; U; CPU like Mac OS X; en) AppleWebKit/420+ (KHTML, like Gecko) Version/3.0 Mobile/1A543a Safari/419.3"];
		
		NSString* meeboChatURL = @"http://www.meebo.com/";
		//meeboChatURL = @"http://m.ebuddy.com";
		//meeboChatURL = @"http://iphone.mundu.com/";
		//meeboChatURL = @"http://iphone.beejive.com";
		
		NSMutableURLRequest* request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:meeboChatURL]];
		[[webView mainFrame] loadRequest:request];
	}		
	else if([service isEqualToString:serviceHahlo]) {
		if(hahlo == nil) {
			hahlo = [webView retain];
			[webView setGroupName:service];
		}
		
		[mainFrameView setAllowsScrolling:YES];
		[webView setProhibitsMainFrameScrolling:NO];
		[webView setCustomUserAgent:@"Mozilla/5.0 (iPhone; U; CPU like Mac OS X; en) AppleWebKit/420+ (KHTML, like Gecko) Version/3.0 Mobile/1A543a Safari/419.3"];
		
		NSString* hahloChatURL = @"http://www.hahlo.com";
		//meeboChatURL = @"http://m.ebuddy.com";
		//meeboChatURL = @"http://iphone.mundu.com/";
		//meeboChatURL = @"http://iphone.beejive.com";
		
		NSMutableURLRequest* request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:hahloChatURL]];
		[[webView mainFrame] loadRequest:request];
	}		
}

- (void)saveFrames
{
	NSRect frame = [[self window] frame];
	id defaults = [NSUserDefaults standardUserDefaults];
	if([service isEqualToString:serviceFacebook] && loginFacebook == NO) {
		[defaults setObject:[NSNumber numberWithFloat:frame.size.width] forKey:@"WidthFacebook"];
		[defaults setObject:[NSNumber numberWithFloat:frame.size.height] forKey:@"HeightFacebook"];
		[defaults synchronize];
	}
	else if([service isEqualToString:serviceGoogle] && loginGoogle == NO) {
		[defaults setObject:[NSNumber numberWithFloat:frame.size.width] forKey:@"WidthGoogle"];
		[defaults setObject:[NSNumber numberWithFloat:frame.size.height] forKey:@"HeightGoogle"];
		[defaults synchronize];
	}
	else if([service isEqualToString:serviceMeebo]) {
		[defaults setObject:[NSNumber numberWithFloat:frame.size.height] forKey:@"HeightMeebo"];
		[defaults synchronize];
	}
	else if([service isEqualToString:serviceHahlo]) {
		[defaults setObject:[NSNumber numberWithFloat:frame.size.height] forKey:@"HeightHahlo"];
		[defaults synchronize];
	}
}

- (void)verifyGoogle:(id)sender
{
	googleVerifyTimer = nil;
	
	if([service isEqualToString:serviceGoogle]) {
		loginGoogle = YES;
		
		if(googleLoginHelp == nil) {
			NSPoint buttonPoint = NSMakePoint(0.0, [[self window] frame].size.height - 150.0);
			googleLoginHelp = [[MAAttachedWindow alloc] initWithView:googleHelp
													   attachedToPoint:buttonPoint 
															  inWindow:[self window] 
																onSide:MAPositionLeft 
															atDistance:8.0];
			
			[(MAAttachedWindow*)googleLoginHelp setBackgroundColor:[NSColor blackColor]];

			[[self window] addChildWindow:googleLoginHelp ordered:NSWindowAbove];
		}
		
		
		[webView setCustomUserAgent:@"Mozilla/5.0 (Macintosh; U; Intel Mac OS X 10_5_2; en-us) AppleWebKit/525.18 (KHTML, like Gecko) Version/3.1.1 Safari/525.18"];
		
		//NSString* googleLoginURL = @"https://www.google.com/accounts/Login?continue=https%3A%2F%2Ftalkgadget.google.com%2Ftalkgadget%2Fauth%3Fverify%3Dtrue%26http%3Dtrue&service=talk";
		NSString* googleLoginURL = @"https://www.google.com/accounts/ServiceLogin?service=talk&passive=true&skipvpage=true&continue=https%3A%2F%2Ftalkgadget.google.com%2Ftalkgadget%2Fauth%3Fverify%3Dtrue%26http%3Dtrue";
		NSMutableURLRequest* request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:googleLoginURL]];
		[[webView mainFrame] loadRequest:request];
	}
}

- (void)clearFacebook
{
	[self simulateClick:NSMakePoint(32.0, 128.0)];
	
	[facebookPings removeAllObjects];
	[self performSelectorOnMainThread:@selector(updateBadge:) withObject:self waitUntilDone:NO];
}

- (void)clearGoogle
{
	[self simulateClick:NSMakePoint(32.0, 32.0)];
	
	[googlePings removeAllObjects];
	[self performSelectorOnMainThread:@selector(updateBadge:) withObject:self waitUntilDone:NO];
}

- (void)updateBadge:(id)sender
{
	int pingCount = 0;
	
	pingCount += [facebookPings count];
	pingCount += [googlePings count];
		
	if(pingCount == 0) {
		if(badge) {
			NSImage* myImage = [NSImage imageNamed: @"NSApplicationIcon"];
			[NSApp setApplicationIconImage: myImage];
		}
		
		return;
	}
	
	if(badge == nil)
		badge = [[CTBadge alloc] init];
	
	[badge badgeApplicationDockIconWithValue:pingCount insetX:0 y:0];
}

- (void)simulateClick:(NSPoint)where
{
	NSEvent* mouseDownEvent = [NSEvent  
							   mouseEventWithType:NSLeftMouseDown location:where
							   modifierFlags:0 timestamp:GetCurrentEventTime() 
							   windowNumber:[[self window] windowNumber] context:nil eventNumber:0 clickCount:1  
							   pressure:1.0];
	
	[NSApp postEvent:mouseDownEvent atStart:YES];
	
	NSEvent* mouseUpEvent = [NSEvent  
							 mouseEventWithType:NSLeftMouseUp location:where
							 modifierFlags:0 timestamp:GetCurrentEventTime()
							 windowNumber:[[self window] windowNumber] context:nil eventNumber:0 clickCount:1  
							 pressure:1.0];
	
	[NSApp postEvent:mouseUpEvent atStart:YES];
}

- (IBAction)handleHome:(id)sender
{
	NSString* url = [NSString stringWithFormat:@"http://www.%@", [service substringFromIndex:1]];
	[[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:url]];
}

- (IBAction)handleReload:(id)sender
{
	[reload setHidden:YES];
	[webWait startAnimation:self];

	redirectToBrowser = NO;
	
	if([service isEqualToString:serviceGoogle]) {
		NSString* saveService = [NSString stringWithString:service];
		[service release];
		service = nil;

		[self openService:saveService force:YES];
	}
	else		
		[webView reload:self];
}

- (IBAction)handleGab:(id)sender
{
	NSString* serviceName = [sender title];
	[self openService:serviceName force:NO];
}

- (IBAction)handleLogout:(id)sender
{
	if([service isEqualToString:serviceFacebook]) {
	}
	else if([service isEqualToString:serviceGoogle]) {
		NSString* googleChatURL = @"http://www.google.com/accounts/logout?continue=http://talkgadget.google.com/talkgadget/popout";
		NSMutableURLRequest* request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:googleChatURL]];
		[[google mainFrame] loadRequest:request];
	}
}

- (IBAction)handlePreferenceOpen:(id)sender
{
	[NSApp beginSheet:preferences
	   modalForWindow:[self window]
		modalDelegate:nil
	   didEndSelector:nil 
		  contextInfo:nil];
	
	[NSApp runModalForWindow:preferences];
	
	[NSApp endSheet:preferences];
	[preferences orderOut:self];
}

- (IBAction)handlePreferenceClose:(id)sender
{
	[NSApp stopModal];
	
	id defaults = [NSUserDefaults standardUserDefaults];
	NSNumber* levelDefault = [defaults valueForKey:@"MainWindowLevel"];
	int level = (levelDefault ? [levelDefault intValue] : NSNormalWindowLevel);
	if(level == -1)
		level = kCGDesktopIconWindowLevel-1;
	[[self window] setLevel:level];

	BOOL supportsSpaces = [[self window] respondsToSelector:@selector(setCollectionBehavior:)];

	if(supportsSpaces) {
		NSNumber* spacesDefault = [defaults valueForKey:@"MainWindowAllSpaces"];
		if([spacesDefault boolValue] == YES)
			[[self window] setCollectionBehavior:NSWindowCollectionBehaviorCanJoinAllSpaces];
		else
			[[self window] setCollectionBehavior:NSWindowCollectionBehaviorDefault];
	}
}

- (IBAction)handleOpacityChange:(id)sender
{
	int opacity = [sender intValue];
	if(opacity == 100)
		[[self window] setAlphaValue:1.0];
	else
		[[self window] setAlphaValue:(float)opacity * .01];
}

// WebPolicy delegate
- (void)webView:(WebView *)sender decidePolicyForNavigationAction:(NSDictionary *)actionInformation request:(NSURLRequest *)request frame:(WebFrame *)frame decisionListener:(id<WebPolicyDecisionListener>)listener
{
	NSURL* url = [request URL];
	NSString* urlString = [url absoluteString];
	
	//NSLog(@"%@ URL %@", service, urlString);
	
	if([service isEqualToString:serviceGoogle]) {
		if(loginGoogle || (browser && [frame isEqual:[browser mainFrame]])) {
			//if(!loginGoogle)
			//	NSLog(@"in browser");
			
			NSRange googleAccount = [urlString rangeOfString:@"google.com/accounts/NewAccount"];
			if(googleAccount.location != NSNotFound) {
				[[NSWorkspace sharedWorkspace] openURL:url];
				[listener ignore];
				return;
			}
			NSRange googleSupport = [urlString rangeOfString:@"google.com/support"];
			if(googleSupport.location != NSNotFound) {
				[[NSWorkspace sharedWorkspace] openURL:url];
				[listener ignore];
				return;
			}
			
			NSRange googleLogin = [urlString rangeOfString:@"google.com/accounts/ServiceLogin"];
			if(googleLogin.location != NSNotFound && googleVerifyTimer == nil) {
				if(loginGoogle) {
					[listener use];
					return;
				}
				else
					googleVerifyTimer = [NSTimer scheduledTimerWithTimeInterval:3.0 target:self selector:@selector(verifyGoogle:) userInfo:nil repeats:NO];
			}

			NSRange googleLoading = [urlString rangeOfString:@"talkgadget.google.com"];
			if(googleLoading.location != NSNotFound) {
				NSRange authLoading = [urlString rangeOfString:@"talkgadget/auth?"];

				if(authLoading.location != NSNotFound && loginGoogle) {
					/*if(browser == nil) {
						browser = [[WebView alloc] initWithFrame:[webView frame] frameName:nil groupName:nil];
						[browser setPreferencesIdentifier:[webView preferencesIdentifier]];
						[browser setAutoresizingMask:[webView autoresizingMask]];
						
						[browser setHidden:YES];
						[browser setHostWindow:nil];
						
						[browser setPolicyDelegate:self];
					}
					
					NSMutableURLRequest* newRequest = [NSMutableURLRequest requestWithURL:url];
					[[browser mainFrame] loadRequest:newRequest];

					[listener ignore];*/
					
					[listener use];
					
					resetGoogle = YES;
				}
				else
					[listener use];
			}
			else {
				[[NSWorkspace sharedWorkspace] openURL:url];
				[listener ignore];
			}
			
			return;
		}
		
		NSRange googleLoaded = [urlString rangeOfString:@"talkgadget.google.com"];
		if(googleLoaded.location != NSNotFound) {
			[listener use];
			return;
			
			if(googleVerifyTimer) {
				[googleVerifyTimer invalidate];
				googleVerifyTimer = nil;
			}
		}

		NSRange googleRelay = [urlString rangeOfString:@"google.com/ig/ifpc_relay"];
		if(googleRelay.location != NSNotFound) {
			[listener use];
			return;
		}
	}
	else if([service isEqualToString:serviceFacebook]) {
		NSRange facebookLogin = [urlString rangeOfString:@"facebook.com/login.php"];
		if(facebookLogin.location != NSNotFound) {
			[listener use];
			return;
		}

		NSRange facebookChat = [urlString rangeOfString:@"facebook.com/presence/"];
		if(facebookChat.location != NSNotFound) {
			[listener use];
			return;
		}
		
		NSRange facebookSignUp = [urlString rangeOfString:@"facebook.com/r.php"];
		if(facebookSignUp.location != NSNotFound) {
			[[NSWorkspace sharedWorkspace] openURL:url];
			[listener ignore];
			return;
		}
	}
	else if([service isEqualToString:serviceHahlo]) {
		if([urlString hasPrefix:@"http://hahlo.com"] || [urlString hasPrefix:@"http://www.hahlo.com"]) {
			[listener use];
			return;
		}
	}
	
	if(redirectToBrowser && [frame isEqual:[webView mainFrame]]) {
		NSString* scheme = [url scheme];
		if([scheme isEqualToString:@"http"]) {	
			[[NSWorkspace sharedWorkspace] openURL:url];
			[listener ignore];
			return;
		}
	}
		
	[listener use];
}

- (void)webView:(WebView *)sender decidePolicyForNewWindowAction:(NSDictionary *)actionInformation request:(NSURLRequest *)request newFrameName:(NSString *)frameName decisionListener:(id<WebPolicyDecisionListener>)listener
{
	NSURL* url = [request URL];
	NSString* urlString = [url absoluteString];

	if([service isEqualToString:serviceFacebook]) {
		if(url) {
			NSRange facebookLogin = [urlString rangeOfString:@"facebook.com/login.php"];
			if(facebookLogin.location == NSNotFound) {
				[[NSWorkspace sharedWorkspace] openURL:url];
				[listener ignore];
				return;
			}
		}
		
		[listener ignore];

		NSString* saveService = [NSString stringWithString:service];
		[service release];
		service = nil;
		
		[self openService:saveService force:YES];
		
		return;
	}

	[[NSWorkspace sharedWorkspace] openURL:url];
	[listener ignore];

	//NSLog(@"new window requested at %@", url);
}

- (id)webView:(WebView *)sender identifierForInitialRequest:(NSURLRequest *)request fromDataSource:(WebDataSource *)dataSource
{
	NSURL* url = [request URL];
	return [NSString stringWithString:[url absoluteString]];
}

// WebResourceLoad delegate
- (void)webView:(WebView *)sender resource:(id)identifier didFinishLoadingFromDataSource:(WebDataSource *)dataSource
{
#if 0
	if([service isEqualToString:serviceFacebook]) {
		//[webView stringByEvaluatingJavaScriptFromString:@"var c = document.getElementsByTagName('textarea'); for (var i = 0; i < c.length; i++) { if(c[i].className == 'chat_input') { c[i].rows = '2'; } }"];
	}
	
	if([identifier hasSuffix:@".php"]) {
		NSLog(identifier);
		NSData* data = [dataSource data];
		NSString* dataString = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding]; 
		NSLog(@"%@", dataString);
		NSLog(@"-----");
	}
#endif
}

// WebFrameLoad delegate
- (void)webView:(WebView *)sender didReceiveTitle:(NSString *)title forFrame:(WebFrame *)frame
{
	BOOL serviceIsActive = [service isEqualToString:[[frame webView] groupName]];
	
	NSString* fullTitle = nil;

	if(facebook && [frame isEqualTo:[facebook mainFrame]]) {
		fullTitle = [NSString stringWithFormat:@"%@ > %@", service, title];
		
		if(googleLoginHelp && serviceIsActive) {
			[[self window] removeChildWindow:googleLoginHelp];
			[googleLoginHelp orderOut:self];
		}
		
		if([title hasPrefix:@"Login"]) {
			fullTitle = [NSString stringWithFormat:@"%@ (https)", fullTitle];
			loginFacebook = YES;
			
			if(facebookLoginHelp == nil && serviceIsActive) {
				NSPoint buttonPoint = NSMakePoint(0.0, [[self window] frame].size.height - 150.0);
				facebookLoginHelp = [[MAAttachedWindow alloc] initWithView:facebookHelp
					attachedToPoint:buttonPoint 
					inWindow:[self window] 
					onSide:MAPositionLeft 
					atDistance:8.0];
				
				[(MAAttachedWindow*)facebookLoginHelp setBackgroundColor:[NSColor blackColor]];
				
				[[self window] addChildWindow:facebookLoginHelp ordered:NSWindowAbove];
			}
		}
		else if([title hasPrefix:@"New message from "]) {
			if([[self window] isKeyWindow] == NO || [[self window] isMiniaturized] || !serviceIsActive) {
				if([facebookPings containsObject:title] == NO) {
					[facebookPings addObject:title];
					
					if([GrowlApplicationBridge isGrowlRunning])
						[GrowlApplicationBridge notifyWithTitle:serviceFacebook
													description:title
											   notificationName:@"GabFacebookNewMessage"
													   iconData:nil
													   priority:0
													   isSticky:NO
												   clickContext:serviceFacebook];
					else
						[NSApp requestUserAttention:NSInformationalRequest];
					
					[self performSelectorOnMainThread:@selector(updateBadge:) withObject:self waitUntilDone:NO];
				}
			}
		}
		
		[facebookTitle release];
		facebookTitle = [fullTitle retain];
	}
	else if(google && [frame isEqualTo:[google mainFrame]]) {
		fullTitle = [NSString stringWithFormat:@"%@ > %@", service, title];
		
		if(facebookLoginHelp && serviceIsActive) {
			[[self window] removeChildWindow:facebookLoginHelp];
			[facebookLoginHelp orderOut:self];
		}
		
		if([title isEqualToString:@"Google Accounts"]) {
			fullTitle = [NSString stringWithFormat:@"%@ (https)", fullTitle];
			loginGoogle = YES;

			if(googleLoginHelp == nil && serviceIsActive) {
				NSPoint buttonPoint = NSMakePoint(0.0, [[self window] frame].size.height - 150.0);
				googleLoginHelp = [[MAAttachedWindow alloc] initWithView:googleHelp
														   attachedToPoint:buttonPoint 
																  inWindow:[self window] 
																	onSide:MAPositionLeft 
																atDistance:8.0];

				[(MAAttachedWindow*)googleLoginHelp setBackgroundColor:[NSColor blackColor]];

				[[self window] addChildWindow:googleLoginHelp ordered:NSWindowAbove];
			}
		}	
		else if([title hasSuffix:@" says..."]) {
			if([[self window] isKeyWindow] == NO || [[self window] isMiniaturized] || !serviceIsActive) {
				if([googlePings containsObject:title] == NO) {
					[googlePings addObject:title];
										
					if([GrowlApplicationBridge isGrowlRunning])
						[GrowlApplicationBridge notifyWithTitle:serviceGoogle
													description:title
											   notificationName:@"GabGoogleNewMessage"
													   iconData:nil
													   priority:0
													   isSticky:NO
												   clickContext:serviceGoogle];
					else
						[NSApp requestUserAttention:NSInformationalRequest];

					[self performSelectorOnMainThread:@selector(updateBadge:) withObject:self waitUntilDone:NO];
}
			}
		}
		
		[googleTitle release];
		googleTitle = [fullTitle retain];
	}	
	else if(meebo && [frame isEqualTo:[meebo mainFrame]]) {
		fullTitle = [NSString stringWithFormat:@"%@ > %@", service, title];
		
		if(facebookLoginHelp && serviceIsActive) {
			[[self window] removeChildWindow:facebookLoginHelp];
			[facebookLoginHelp orderOut:self];
		}
		
		if(googleLoginHelp && serviceIsActive) {
			[[self window] removeChildWindow:googleLoginHelp];
			[googleLoginHelp orderOut:self];
		}
		
		[meeboTitle release];
		meeboTitle = [fullTitle retain];
	}	
	else if(hahlo && [frame isEqualTo:[hahlo mainFrame]]) {
		fullTitle = [NSString stringWithFormat:@"%@ > %@", service, title];
		
		if(facebookLoginHelp && serviceIsActive) {
			[[self window] removeChildWindow:facebookLoginHelp];
			[facebookLoginHelp orderOut:self];
		}
		
		if(googleLoginHelp && serviceIsActive) {
			[[self window] removeChildWindow:googleLoginHelp];
			[googleLoginHelp orderOut:self];
		}
		
		[hahloTitle release];
		hahloTitle = [fullTitle retain];
	}	
	
	if(serviceIsActive && fullTitle)
		[webTitle setStringValue:fullTitle];
}

- (void)webView:(WebView *)sender didReceiveIcon:(NSImage *)image forFrame:(WebFrame *)frame
{
	//[[self window] setMiniwindowImage:image];
}

- (void)webView:(WebView *)sender willPerformClientRedirectToURL:(NSURL *)URL delay:(NSTimeInterval)seconds fireDate:(NSDate *)date forFrame:(WebFrame *)frame
{
	BOOL serviceIsActive = [service isEqualToString:[[frame webView] groupName]];
	
	if(facebook && [[frame webView] isEqualTo:facebook] && [frame isEqualTo:[facebook mainFrame]] == NO) {
		loginFacebook = NO;
		
		if(facebookLoginHelp) {
			if(serviceIsActive) {
				[[self window] removeChildWindow:facebookLoginHelp];
				[facebookLoginHelp orderOut:self];
			}

			[facebookLoginHelp release];
			facebookLoginHelp = nil;
		}
	}
}

// WebUI delegate
- (WebView *)webView:(WebView *)sender createWebViewWithRequest:(NSURLRequest *)request
{
	NSURL* url = [request URL];
	if(url == nil)
		url = [request mainDocumentURL];

	//NSLog(@"new webview requested at %@", url);

	if(url)
		[[NSWorkspace sharedWorkspace] openURL:url];
	
	if(browser == nil) {
		browser = [[WebView alloc] initWithFrame:[webView frame] frameName:nil groupName:nil];
		[browser setPreferencesIdentifier:[webView preferencesIdentifier]];
		[browser setAutoresizingMask:[webView autoresizingMask]];

		[browser setHidden:YES];
		[browser setHostWindow:nil];

		[browser setPolicyDelegate:self];
	}

	return browser;
}

- (void)webViewShow:(WebView *)sender
{
}

- (void)webViewClose:(WebView *)sender
{
#if 0
	[[self window] performMiniaturize:self];

	if([service isEqualToString:serviceFacebook])
		resetFacebook = YES;
	else if([service isEqualToString:serviceGoogle])
		resetGoogle = YES;
	else if([service isEqualToString:serviceMeebo])
		resetMeebo = YES;
	else if([service isEqualToString:serviceHahlo])
		resetHahlo = YES;
#endif
}

- (NSArray *)webView:(WebView *)sender contextMenuItemsForElement:(NSDictionary *)element defaultMenuItems:(NSArray *)defaultMenuItems
{
	return nil;
}

// NSMenu delegate
- (BOOL)validateMenuItem:(NSMenuItem *)aMenuItem
{
	if([aMenuItem action] == @selector(handlePreferenceOpen:))
   		return YES;
	
	if([aMenuItem action] == @selector(handleGab:))
   		return YES;
	
	if([aMenuItem action] == @selector(handleLogout:)) {
		if([service isEqualToString:serviceFacebook] && loginFacebook == NO)
			return YES;
		
		if([service isEqualToString:serviceGoogle] && loginGoogle == NO)
			return YES;
		
		return NO;
	}
	
	if([aMenuItem action] == @selector(handleUpdate:))
   		return YES;
	
	if([aMenuItem action] == @selector(handleContact:))
   		return YES;
	
	if([aMenuItem action] == @selector(handleLicense:))
   		return YES;
	
	if([aMenuItem action] == @selector(handleCredits:))
   		return YES;
	
	if([aMenuItem action] == @selector(handleNotes:))
   		return YES;
	
	return NO;
}

- (int)numberOfItemsInMenu:(NSMenu *)menu
{
	return 4;
}

- (BOOL)menu:(NSMenu *)menu updateItem:(NSMenuItem *)item atIndex:(int)index shouldCancel:(BOOL)shouldCancel
{
	NSString* title = [item title];
	if([title isEqualToString:service]) {
		if([[self window] isVisible])
			[item setState:NSOnState];
		else
			[item setState:NSMixedState];
	}
	else
		[item setState:NSOffState];

	return YES;
}

// NSWindow delegate
- (BOOL)windowShouldClose:(id)window
{
	[[self window] orderOut:self];
	return NO;
}

- (void)windowDidBecomeKey:(NSNotification *)notification
{
	id defaults = [NSUserDefaults standardUserDefaults];

	NSNumber* opaqueValue = [defaults valueForKey:@"MainWindowGoOpaque"];
	BOOL opaque = (opaqueValue ? [opaqueValue boolValue] : NO);
	if(opaque)
		[[self window] setAlphaValue:1.0];
}

- (void)windowDidResignKey:(NSNotification *)notification
{
	id defaults = [NSUserDefaults standardUserDefaults];
	
	NSNumber* opaqueValue = [defaults valueForKey:@"MainWindowGoOpaque"];
	BOOL opaque = (opaqueValue ? [opaqueValue boolValue] : NO);
	if(opaque) {
		NSNumber* opacityDefault =  [defaults valueForKey:@"MainWindowOpacity"];
	
		int opacity = (opacityDefault ? [opacityDefault intValue] : 100);
		if(opacity == 100)
			[[self window] setAlphaValue:1.0];
		else
			[[self window] setAlphaValue:(float)opacity * .01];
	}
}

- (void)windowDidResize:(NSNotification *)notification
{
	if(ignoreResize)
		return;
	
	[self saveFrames];
}

- (void)windowDidDeminiaturize:(NSNotification *)notification
{
#if 0
	BOOL reloadService = NO;
	
	if(resetFacebook && [service isEqualToString:serviceFacebook]) {
		reloadService = YES;
		resetFacebook = NO;
	}
	else if(resetGoogle && [service isEqualToString:serviceGoogle]) {
		reloadService = YES;
		resetGoogle = NO;
	}
	else if(resetMeebo && [service isEqualToString:serviceMeebo]) {
		reloadService = YES;
		resetMeebo = NO;
	}	
	else if(resetHahlo && [service isEqualToString:serviceHahlo]) {
		reloadService = YES;
		resetHahlo = NO;
	}	
	
	if(reloadService) {
		NSString* saveService = [NSString stringWithString:service];
		[service release];
		service = nil;
		
		[self openService:saveService force:YES];
	}
#endif
}

// NSApplication delegate
- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
	[GrowlApplicationBridge setGrowlDelegate:self];
	
	id defaults = [NSUserDefaults standardUserDefaults];
	[self openService:[defaults valueForKey:@"DefaultService"] force:NO];

	[[self window] makeKeyAndOrderFront:self];
}

- (void)applicationWillTerminate:(NSNotification *)aNotification
{
	if(googleVerifyTimer)
		[googleVerifyTimer invalidate];
	
	[webView stopLoading:self];

	[self saveFrames];
}

- (BOOL)applicationShouldTerminateAfterLastWindowClosed:(NSApplication *)theApplication
{
	return NO;
}

- (void)applicationDidBecomeActive:(NSNotification *)aNotification
{
	if([service isEqualToString:serviceFacebook] && [facebookPings count] > 0)
		[self clearFacebook];
	
	if([service isEqualToString:serviceGoogle] && [googlePings count] > 0)
		[self clearGoogle];
}

// Growl delegate
- (NSString *) applicationNameForGrowl
{
	return @"Gabtastik";
}

- (void) growlNotificationWasClicked:(id)clickContext
{
	NSString* growlService = (NSString*) clickContext;
	
	if([growlService isEqualToString:serviceFacebook] || [growlService isEqualToString:serviceGoogle]) {
		if([service isEqualToString:growlService] == NO)
			[self openService:growlService force:NO];
		
		[NSApp activateIgnoringOtherApps:YES];
		[[self window] makeKeyAndOrderFront:self];		
	}
}

@end
