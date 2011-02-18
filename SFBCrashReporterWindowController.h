/*
 *  Copyright (C) 2009 Stephen F. Booth <me@sbooth.org>
 *  All Rights Reserved
 */

#import <Cocoa/Cocoa.h>

// ========================================
// The main class for SFBCrashReporter
// ========================================
@interface SFBCrashReporterWindowController : NSWindowController
{
	IBOutlet NSTextView *_commentsTextView;
	IBOutlet NSButton *_reportButton;
	IBOutlet NSButton *_ignoreButton;
	IBOutlet NSButton *_discardButton;
	IBOutlet NSProgressIndicator *_progressIndicator;
	
@private
	NSString *_emailAddress;
	NSArray *crashReports;
	
	NSString *message;
	NSString *prompt;
	NSString *title;
	NSString *placeholder;
	NSString *note;
}

// ========================================
// Properties
@property (copy) NSString *emailAddress;
@property (copy) NSString *message;
@property (copy) NSString *prompt;
@property (copy) NSString *title;
@property (copy) NSString *placeholder;
@property (copy) NSString *note;
@property (retain) NSArray *crashReports;


// ========================================
// Always use this to show the window- do not alloc/init directly
+ (void)showWindowForCrashReportURLs:(NSArray *)reports 
							   title:(NSString *)title 
							 message:(NSString *)message 
							  prompt:(NSString *)prompt 
						 placeholder:(NSString *)placeholder
								note:(NSString *)note
						emailAddress:(NSString *)emailAddress;

// ========================================
// Action methods
- (IBAction) sendReport:(id)sender;
- (IBAction) ignoreReport:(id)sender;

@end
