/*
 *  Copyright (C) 2009, 2010 Stephen F. Booth <me@sbooth.org>
 *  All Rights Reserved
 */

#import <AddressBook/AddressBook.h>

#import "SFBCrashReporter.h"
#import "SFBCrashReporterWindowController.h"
#import "SFBSystemInformation.h"
#import "GenerateFormData.h"

@interface SFBCrashReporter (Private)

+ (NSArray *)crashLogPaths;
+ (NSURL *)submissionURL;
- (NSString *)applicationName;

@end


@implementation SFBCrashReporter

@synthesize crashLogURLs;

+ (SFBCrashReporter *)crashReporter {
	return [[[self alloc] init] autorelease];
}

- (id)init {
	if ((self = [super init])) {
		attributes = [[NSMutableDictionary alloc] init];
		attachments = [[NSMutableArray alloc] init];
	}
	
	return self;
}

- (void)dealloc {
	[attributes release]; attributes = nil;
	[attachments release]; attachments = nil;
	
	[_urlConnection release], _urlConnection = nil;
	[_responseData release], _responseData = nil;
	self.crashLogURLs = nil;
	
	[super dealloc];
}

- (void)checkForNewCrashesInteractively:(BOOL)interactively withDelegate:(id <SFBCrashReporterDelegate>)delegate {
	// Verify that the submission URL is valid
	[[self class] submissionURL];

	// Determine when the last crash was reported
	NSDate *lastCrashReportDate = [[NSUserDefaults standardUserDefaults] objectForKey:@"SFBCrashReporterLastCrashReportDate"];
	
	// If a crash was never reported, use now as the starting point
	if(!lastCrashReportDate) {
		lastCrashReportDate = [NSDate date];
		[[NSUserDefaults standardUserDefaults] setObject:lastCrashReportDate forKey:@"SFBCrashReporterLastCrashReportDate"];
	}
	
	// Determine if it is even necessary to show the window (by comparing file modification dates to the last time a crash was reported)
	NSArray *allCrashLogPaths = [[self class] crashLogPaths];
	NSMutableArray *newCrashLogURLs = [NSMutableArray arrayWithCapacity:[allCrashLogPaths count]];
	for(NSString *path in allCrashLogPaths) {
		NSDictionary *fileAttributes = [[NSFileManager defaultManager] attributesOfItemAtPath:path error:nil];
		NSDate *fileModificationDate = [fileAttributes fileModificationDate];
		
		// If the last time a crash was reported is earlier than the file's modification date, allow the user to report the crash
		if(NSOrderedAscending == [lastCrashReportDate compare:fileModificationDate]) {
			[newCrashLogURLs addObject:[NSURL fileURLWithPath:path]];
			[delegate crashReporter:self willSendCrashLogAtPath:path dated:fileModificationDate];
		}
	}
	
	if ([newCrashLogURLs count]) {
		if (interactively) {
			// Set the window's title
			NSString *applicationShortVersion = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleShortVersionString"];
			NSString *windowTitle;
			if (!applicationShortVersion) {
				windowTitle = [NSString stringWithFormat:NSLocalizedString(@"Crash Reporter - %@", @""), [self applicationName]];
			} else {
				windowTitle = [NSString stringWithFormat:NSLocalizedString(@"Crash Reporter - %@ (%@)", @""), [self applicationName], applicationShortVersion];
			}
			
			NSString *message = [NSString stringWithFormat:@"%@ crashed the last time it was run.  Please help fix the problem by submitting a crash report.", [self applicationName]];
						
			[self sendCrashReportURLs:newCrashLogURLs interactivelyWithWindowTitle:windowTitle 
							  message:message 
							   prompt:@"What were you doing at the time of the crash?"
						  placeholder:@"Please enter a brief description of the actions which caused the crash."
								 note:@""
						 emailAddress:nil];
		} else {
			[self sendCrashReportURLs:newCrashLogURLs withComments:nil userEmailAddress:nil];
		}
	}
}

- (void)sendCrashReportURLs:(NSArray *)reports interactivelyWithWindowTitle:(NSString *)title
					message:(NSString *)message 
					 prompt:(NSString *)prompt 
				placeholder:(NSString *)placeholder
					   note:(NSString *)note
			   emailAddress:(NSString *)emailAddress 
{
	if (!emailAddress) {
		// Populate the e-mail field with the users primary e-mail address
		ABMultiValue *emailAddresses = [[[ABAddressBook sharedAddressBook] me] valueForProperty:kABEmailProperty];
		emailAddress = (NSString *)[emailAddresses valueForIdentifier:[emailAddresses primaryIdentifier]];
	}
	
	[SFBCrashReporterWindowController showWindowForCrashReportURLs:reports 
															 title:title 
														   message:message 
															prompt:prompt 
													   placeholder:placeholder
															  note:note
													  emailAddress:emailAddress];
}

// Do the actual work of building the HTTP POST and submitting it
- (void)sendCrashReportURLs:(NSArray *)reports withComments:(NSString *)comments userEmailAddress:(NSString *)emailAddress {
	self.crashLogURLs = reports;
	
	NSMutableDictionary *formValues = [NSMutableDictionary dictionaryWithDictionary:attributes];
	
	// Append system information, if specified
	if([[NSUserDefaults standardUserDefaults] boolForKey:@"SFBCrashReporterIncludeAnonymousSystemInformation"]) {
		SFBSystemInformation *systemInformation = [[SFBSystemInformation alloc] init];
		
		id value = nil;
		
		if((value = [systemInformation machine]))
			[formValues setObject:value forKey:@"machine"];
		if((value = [systemInformation model]))
			[formValues setObject:value forKey:@"model"];
		if((value = [systemInformation physicalMemory]))
			[formValues setObject:value forKey:@"physicalMemory"];
		if((value = [systemInformation numberOfCPUs]))
			[formValues setObject:value forKey:@"numberOfCPUs"];
		if((value = [systemInformation busFrequency]))
			[formValues setObject:value forKey:@"busFrequency"];
		if((value = [systemInformation CPUFrequency]))
			[formValues setObject:value forKey:@"CPUFrequency"];
		if((value = [systemInformation CPUFamily]))
			[formValues setObject:value forKey:@"CPUFamily"];
		if((value = [systemInformation modelName]))
			[formValues setObject:value forKey:@"modelName"];
		if((value = [systemInformation CPUFamilyName]))
			[formValues setObject:value forKey:@"CPUFamilyName"];
		if((value = [systemInformation systemVersion]))
			[formValues setObject:value forKey:@"systemVersion"];
		if((value = [systemInformation systemBuildVersion]))
			[formValues setObject:value forKey:@"systemBuildVersion"];
		
		[formValues setObject:[NSNumber numberWithBool:YES] forKey:@"systemInformationIncluded"];
		
		[systemInformation release], systemInformation = nil;
	}
	else
		[formValues setObject:[NSNumber numberWithBool:NO] forKey:@"systemInformationIncluded"];
	
	// Include email address, if permitted
	if([emailAddress length]) {
		[formValues setObject:emailAddress forKey:@"emailAddress"];
	}
	
	// Optional comments
	if([comments length]) {
		[formValues setObject:comments forKey:@"comments"];
	}
	
	// The most important item of all
	[formValues setObject:[crashLogURLs arrayByAddingObjectsFromArray:attachments] forKey:@"crashLog"];
	for (NSURL *reportURL in crashLogURLs) {
		NSLog(@"Sending logfile: %@", [reportURL path]);
	}
	
	// Add the application information
	NSString *applicationName = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleName"];
	if(applicationName)
		[formValues setObject:applicationName forKey:@"applicationName"];
	
	NSString *applicationIdentifier = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleIdentifier"];
	if(applicationIdentifier)
		[formValues setObject:applicationIdentifier forKey:@"applicationIdentifier"];
	
	NSString *applicationVersion = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleVersion"];
	if(applicationVersion)
		[formValues setObject:applicationVersion forKey:@"applicationVersion"];
	
	NSString *applicationShortVersion = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleShortVersionString"];
	if(applicationShortVersion)
		[formValues setObject:applicationShortVersion forKey:@"applicationShortVersion"];
	
	// Create a date formatter
	[NSDateFormatter setDefaultFormatterBehavior:NSDateFormatterBehavior10_4];
	NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
	
	// Determine which locale the developer would like dates/times in
	NSString *localeName = [[NSUserDefaults standardUserDefaults] stringForKey:@"SFBCrashReporterPreferredReportingLocale"];
	if(!localeName) {
		localeName = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"SFBCrashReporterPreferredReportingLocale"];
		// US English is the default
		if(!localeName)
			localeName = @"en_US";
	}
	
	NSLocale *localeToUse = [[NSLocale alloc] initWithLocaleIdentifier:localeName];
	[dateFormatter setLocale:localeToUse];
	
	[dateFormatter setDateStyle:NSDateFormatterMediumStyle];
	[dateFormatter setTimeStyle:NSDateFormatterMediumStyle];
	
	// Include the date and time
	[formValues setObject:[dateFormatter stringFromDate:[NSDate date]] forKey:@"date"];
	
	[localeToUse release], localeToUse = nil;
	[dateFormatter release], dateFormatter = nil;
	
	// Generate the form data
	NSString *boundary = @"0xKhTmLbOuNdArY";
	NSData *formData = GenerateFormData(formValues, boundary);
	
	// Set up the HTTP request
	NSMutableURLRequest *urlRequest = [NSMutableURLRequest requestWithURL:[[self class] submissionURL]];
	
	[urlRequest setHTTPMethod:@"POST"];
	
	NSString *contentType = [NSString stringWithFormat:@"multipart/form-data; boundary=%@", boundary];
	[urlRequest setValue:contentType forHTTPHeaderField:@"Content-Type"];
	
	[urlRequest setValue:@"SFBCrashReporter" forHTTPHeaderField:@"User-Agent"];
	[urlRequest setValue:[NSString stringWithFormat:@"%lu", [formData length]] forHTTPHeaderField:@"Content-Length"];
	[urlRequest setHTTPBody:formData];
	
	// Submit the URL request
	[self retain];
	_urlConnection = [[NSURLConnection alloc] initWithRequest:urlRequest delegate:self];
}

- (void)ignoreCrashReportsUpToAndIncluding:(NSURL *)reportURL {
	// Create our own instance since this method could be called from a background thread
	NSFileManager *fileManager = [[NSFileManager alloc] init];
	
	// Use the file's modification date as the last submitted crash date
	NSDictionary *fileAttributes = [fileManager attributesOfItemAtPath:[reportURL path] error:nil];
	NSDate *fileModificationDate = [fileAttributes fileModificationDate];
	
	[[NSUserDefaults standardUserDefaults] setObject:fileModificationDate forKey:@"SFBCrashReporterLastCrashReportDate"];
	[[NSUserDefaults standardUserDefaults] synchronize];
	
	[fileManager release], fileManager = nil;
}

- (void)sendAttribute:(id)val forKey:(NSString *)key {
	[attributes setObject:val forKey:key];
}

- (void)addAttachmentAtPath:(NSString *)path {
	[attachments addObject:[NSURL fileURLWithPath:path]];
}
	 
@end

@implementation SFBCrashReporter (Private)

+ (NSArray *)crashLogDirectories {
	// Determine which directories contain crash logs based on the OS version
	// See http://developer.apple.com/technotes/tn2004/tn2123.html

	// Determine the OS version
	SInt32 versionMajor = 0;
	OSErr err = Gestalt(gestaltSystemVersionMajor, &versionMajor);
	if(noErr != err)
		NSLog(@"SFBCrashReporter: Unable to determine major system version (%i)", err);

	SInt32 versionMinor = 0;
	err = Gestalt(gestaltSystemVersionMinor, &versionMinor);
	if(noErr != err)
		NSLog(@"SFBCrashReporter: Unable to determine minor system version (%i)", err);
	
	NSArray *libraryPaths = NSSearchPathForDirectoriesInDomains(NSLibraryDirectory, NSUserDomainMask | NSLocalDomainMask, YES);
	NSString *crashLogDirectory = nil;
	
	// Snow Leopard (10.6) or later
	// Snow Leopard crash logs are located in ~/Library/Logs/DiagnosticReports with aliases placed in the Leopard location
	if(10 == versionMajor && 6 <= versionMinor)
		crashLogDirectory = @"Logs/DiagnosticReports";
	// Leopard (10.5) or earlier
	// Leopard crash logs have the form APPNAME_YYYY-MM-DD-hhmm_MACHINE.crash and are located in ~/Library/Logs/CrashReporter
	else if(10 == versionMajor && 5 >= versionMinor)
		crashLogDirectory = @"Logs/CrashReporter";

	NSMutableArray *crashFolderPaths = [[NSMutableArray alloc] init];
	
	for(NSString *libraryPath in libraryPaths) {
		NSString *path = [libraryPath stringByAppendingPathComponent:crashLogDirectory];
		
		BOOL isDir = NO;
		if([[NSFileManager defaultManager] fileExistsAtPath:path isDirectory:&isDir] && isDir) {
			[crashFolderPaths addObject:path];
			break;
		}
	}
	
	return [crashFolderPaths autorelease];	
}

+ (NSArray *)crashLogPaths {
	NSString *applicationName = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleName"];
	NSArray *crashLogDirectories = [self crashLogDirectories];

	NSMutableArray *paths = [[NSMutableArray alloc] init];

	for(NSString *crashLogDirectory in crashLogDirectories) {
		NSString *file = nil;
		NSDirectoryEnumerator *dirEnum = [[NSFileManager defaultManager] enumeratorAtPath:crashLogDirectory];
		while((file = [dirEnum nextObject]))
			if([file hasPrefix:applicationName])
				[paths addObject:[crashLogDirectory stringByAppendingPathComponent:file]];
	}
	
	return [paths autorelease];
}

static NSURL *crashSubmissionURL = nil;
+ (NSURL *)submissionURL {
	if (!crashSubmissionURL) {
		// If no URL is found for the submission, we can't do anything
		NSString *crashSubmissionURLString = [[NSUserDefaults standardUserDefaults] stringForKey:@"SFBCrashReporterCrashSubmissionURL"];
		
		if (!crashSubmissionURLString) {
			crashSubmissionURLString = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"SFBCrashReporterCrashSubmissionURL"];
			
			if (!crashSubmissionURLString) {
				[NSException raise:@"Missing SFBCrashReporterCrashSubmissionURL" format:@"You must specify the URL for crash log submission as the SFBCrashReporterCrashSubmissionURL in either Info.plist or the user defaults!"];
			} else {
				crashSubmissionURL = [[NSURL URLWithString:crashSubmissionURLString] retain];
			}
		}
	}
	
	return crashSubmissionURL;
}

- (NSString *)applicationName {
	NSString *name = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleDisplayName"];
	if (!name) {
		name = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleName"];
	}
	
	return name;
}

#pragma mark NSURLConnection delegate methods

- (void)connection:(NSURLConnection *)connection didReceiveResponse:(NSURLResponse *)response {	
#pragma unused(connection)
#pragma unused(response)
	
	_responseData = [[NSMutableData alloc] init];
}

- (void) connection:(NSURLConnection *)connection didReceiveData:(NSData *)data {
#pragma unused(connection)
	
	[_responseData appendData:data];
}

-(void) connectionDidFinishLoading:(NSURLConnection *)connection {
#pragma unused(connection)
	
	// A valid response is simply the string 'ok'
	NSString *responseString = [[NSString alloc] initWithData:_responseData encoding:NSUTF8StringEncoding];
	BOOL responseOK = [responseString isEqualToString:@"ok"];
	
	[responseString release], responseString = nil;
	[_urlConnection release], _urlConnection = nil;
	[_responseData release], _responseData = nil;
	
	if(responseOK) {
		[self ignoreCrashReportsUpToAndIncluding:[self.crashLogURLs lastObject]];
		
		// Even though the log wasn't deleted, submission was still successful
		//[self performSelectorOnMainThread: @selector(showSubmissionSucceededSheet) withObject:nil waitUntilDone:NO];
		[self autorelease];
	}
	// An error occurred on the server
	else {
//		NSDictionary *userInfo = [NSDictionary dictionaryWithObjectsAndKeys:NSLocalizedString(@"Unrecognized response from the server", @""), NSLocalizedDescriptionKey, nil];
//		NSError *error = [NSError errorWithDomain:NSPOSIXErrorDomain code:EPROTO userInfo:userInfo];
		
		//[self performSelectorOnMainThread: @selector(showSubmissionFailedSheet:) withObject:error waitUntilDone:NO];
		[self autorelease];
	}
}

-(void) connection:(NSURLConnection *)connection didFailWithError:(NSError *)error {
	
#pragma unused(connection)
#pragma unused(error)
	
	[_urlConnection release], _urlConnection = nil;
	[_responseData release], _responseData = nil;
	
	[self autorelease];
	
	//[self performSelectorOnMainThread:@selector(showSubmissionFailedSheet:) withObject:error waitUntilDone:NO];
}

@end
