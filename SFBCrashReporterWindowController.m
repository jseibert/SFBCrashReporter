/*
 *  Copyright (C) 2009, 2010 Stephen F. Booth <me@sbooth.org>
 *  All Rights Reserved
 */

#import "SFBCrashReporter.h"
#import "SFBCrashReporterWindowController.h"


@implementation SFBCrashReporterWindowController

@synthesize emailAddress = _emailAddress;
@synthesize crashReports, title, message, prompt, placeholder, note;

+ (void) initialize {
	// Register reasonable defaults for most preferences
	NSMutableDictionary *defaultsDictionary = [NSMutableDictionary dictionary];
	
	[defaultsDictionary setObject:[NSNumber numberWithBool:YES] forKey:@"SFBCrashReporterIncludeAnonymousSystemInformation"];
	[defaultsDictionary setObject:[NSNumber numberWithBool:NO] forKey:@"SFBCrashReporterIncludeEmailAddress"];
		
	[[NSUserDefaults standardUserDefaults] registerDefaults:defaultsDictionary];
}

+ (void)showWindowForCrashReportURLs:(NSArray *)reports 
							   title:(NSString *)title 
							 message:(NSString *)message 
							  prompt:(NSString *)prompt 
						 placeholder:(NSString *)placeholder 
								note:(NSString *)note
						emailAddress:(NSString *)emailAddress 
{
	NSParameterAssert(nil != reports);

	SFBCrashReporterWindowController *windowController = [[self alloc] init];
	
	windowController.crashReports = reports;
	windowController.title = title;
	windowController.message = message;
	windowController.prompt = prompt;
	windowController.emailAddress = emailAddress;
	windowController.placeholder = placeholder;
	windowController.note = note;
	
	[[windowController window] center];
	[windowController showWindow:self];

	[windowController release], windowController = nil;
}

// Should not be called directly by anyone except this class
- (id) init {
	return [super initWithWindowNibName:@"SFBCrashReporterWindow" owner:self];
}

- (void) dealloc {
	[_emailAddress release], _emailAddress = nil;
	self.crashReports = nil;

	[super dealloc];
}

- (void) windowDidLoad {
	[self retain];
	[[self window] setTitle:self.title];
	
	// Select the comments text
	[_commentsTextView setString:self.placeholder];
	[_commentsTextView setSelectedRange:NSMakeRange(0, NSUIntegerMax)];
}

- (void) windowWillClose:(NSNotification *)notification {
	#pragma unused(notification)
	
	// Ensure we don't leak memory
	[self autorelease];
}

#pragma mark Action Methods

// Send the report off
- (IBAction) sendReport:(id)sender {
	#pragma unused(sender)
	
	if (![self.emailAddress length]) {
		[[NSAlert alertWithMessageText:@"Email address not valid." 
						 defaultButton:nil 
					   alternateButton:nil 
						   otherButton:nil 
			 informativeTextWithFormat:@"Please enter a valid email address so that we can respond to your feedback."] runModal];
		
		return;
	}
		
	NSAttributedString *attributedComments = [_commentsTextView attributedSubstringFromRange:NSMakeRange(0, NSUIntegerMax)];
	
	if (![attributedComments length]) {
		[[NSAlert alertWithMessageText:@"Comments missing." 
						 defaultButton:nil 
					   alternateButton:nil 
						   otherButton:nil 
			 informativeTextWithFormat:[NSString stringWithFormat:@"Please respond to \"%@\"", self.prompt]] runModal];
		
		return;
	}
		
	[_progressIndicator startAnimation:self];
	[_reportButton setEnabled:NO];
	[_ignoreButton setEnabled:NO];
	[_discardButton setEnabled:NO];

	[[SFBCrashReporter crashReporter] sendCrashReportURLs:self.crashReports 
											 withComments:[attributedComments string] 
										 userEmailAddress:self.emailAddress];
	
	[[self window] orderOut:self];
}

// Don't do anything except dismiss our window
- (IBAction) ignoreReport:(id)sender
{

#pragma unused(sender)

	[[SFBCrashReporter crashReporter] ignoreCrashReportsUpToAndIncluding:[self.crashReports lastObject]];
	[[self window] orderOut:self];
}

@end
