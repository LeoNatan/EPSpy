//
//  EPRecordingServiceConnector.m
//  EPSpy
//
//  Created by Léo Natan on 18/6/25.
//

#import <ServiceManagement/ServiceManagement.h>
#import <AppKit/AppKit.h>

#import "EPRecordingServiceConnector.h"
#import "EPRecordingServiceProtocol.h"

static NSXPCConnection* currentConnection = nil;

@implementation EPRecordingServiceConnector

+ (void)startRecordingWithURL:(NSURL*)URL events:(NSArray<NSNumber*>*)events options:(EPRecorderOptions*)options completionHandler:(void(^)(BOOL))completionHandler
{
	NSError* err;
	SMAppService* service = [SMAppService daemonServiceWithPlistName:@"com.LeoNatan.EPRecordingService.plist"];
	
//	[service unregisterAndReturnError:&err];
	
	int retryCount = 3;
	
	while(retryCount > 0)
	{
		retryCount--;
		
		__block BOOL rv = [service registerAndReturnError:&err];
		
		if(rv == NO)
		{
			[NSRunLoop.currentRunLoop runUntilDate:[NSDate.date dateByAddingTimeInterval:0.5]];
			continue;
		}
		
		currentConnection = [[NSXPCConnection alloc] initWithMachServiceName:@"com.LeoNatan.EPRecordingService.xpc" options:NSXPCConnectionPrivileged];
		currentConnection.remoteObjectInterface = [NSXPCInterface interfaceWithProtocol:@protocol(EPRecordingServiceProtocol)];
		[currentConnection resume];
		
		rv = NO;
		id<EPRecordingServiceProtocol> proxy = [currentConnection remoteObjectProxyWithErrorHandler:^(NSError * _Nonnull error) {
			NSLog(@"Error: %@", error);
		}];
		[proxy startRecordingWithURL:URL events:events options:options completionHandler:^(BOOL started) {
			dispatch_async(dispatch_get_main_queue(), ^ {
				completionHandler(started);
			});
		}];
		
		return;
	}
	
	[[NSAlert alertWithError:err] runModal];
	
	completionHandler(NO);
}

+ (void)stopRecordingWithCompletionHandler:(void(^)(void))completionHandler
{
	id<EPRecordingServiceProtocol> proxy = [currentConnection remoteObjectProxyWithErrorHandler:^(NSError * _Nonnull error) {
		dispatch_async(dispatch_get_main_queue(), ^ {
			completionHandler();
		});
	}];
	[proxy stopRecordingWithCompletionHandler:^ {
		dispatch_async(dispatch_get_main_queue(), ^ {
			completionHandler();
			[currentConnection invalidate];
			currentConnection = nil;
		});
	}];
}

@end
