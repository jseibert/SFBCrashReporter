/*
 *  Copyright (C) 2009 Stephen F. Booth <me@sbooth.org>
 *  All Rights Reserved
 */

#import <Cocoa/Cocoa.h>

@class SFBCrashReporter;

@protocol SFBCrashReporterDelegate

- (void)crashReporter:(SFBCrashReporter *)reporter willSendCrashLogAtPath:(NSString *)path dated:(NSDate *)date;

@end


// ========================================
// The main interface
// ========================================
@interface SFBCrashReporter : NSObject {
	NSURLConnection *_urlConnection;
	NSMutableData *_responseData;
	
	NSArray *crashLogURLs;
	NSMutableArray *attachments;
	NSMutableDictionary *attributes;
}

@property (retain) NSArray *crashLogURLs;

+ (SFBCrashReporter *)crashReporter;

// Ensure that SFBCrashReporterCrashSubmissionURL is set to a string in either your application's Info.plist
// or NSUserDefaults and call this
- (void)checkForNewCrashesInteractively:(BOOL)interactively withDelegate:(id <SFBCrashReporterDelegate>)delegate;

- (void)sendCrashReportURLs:(NSArray *)reports withComments:(NSString *)comments userEmailAddress:(NSString *)emailAddress;
- (void)sendCrashReportURLs:(NSArray *)reports interactivelyWithWindowTitle:(NSString *)title
					message:(NSString *)message 
					 prompt:(NSString *)prompt 
				placeholder:(NSString *)placeholder
					   note:(NSString *)note
			   emailAddress:(NSString *)emailAddress;

- (void)ignoreCrashReportsUpToAndIncluding:(NSURL *)reportURL;

- (void)sendAttribute:(id)val forKey:(NSString *)key;
- (void)addAttachmentAtPath:(NSString *)path;

@end
