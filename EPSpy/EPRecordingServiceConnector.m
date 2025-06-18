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

static NSXPCConnection* currentConnection;

@implementation EPRecordingServiceConnector

+ (BOOL)startRecordingWithURL:(NSURL *)URL events:(NSArray<NSNumber*>*)events options:(EPRecorderOptions *)options
{
	NSError* err;
	SMAppService* service = [SMAppService daemonServiceWithPlistName:@"com.LeoNatan.EPRecordingService.plist"];
//	[service unregisterAndReturnError:&err];
	__block BOOL rv = [service registerAndReturnError:&err];
	
	if(rv == NO)
	{
		[[NSAlert alertWithError:err] runModal];
		
		return NO;
	}
	
	currentConnection = [[NSXPCConnection alloc] initWithMachServiceName:@"com.LeoNatan.EPRecordingService.xpc" options:NSXPCConnectionPrivileged];
	currentConnection.remoteObjectInterface = [NSXPCInterface interfaceWithProtocol:@protocol(EPRecordingServiceProtocol)];
	[currentConnection resume];
	
	rv = NO;
	id<EPRecordingServiceProtocol> proxy = [currentConnection synchronousRemoteObjectProxyWithErrorHandler:^(NSError * _Nonnull error) {
		NSLog(@"Error: %@", error);
	}];
	[proxy startRecordingWithURL:URL events:events options:options completionHandler:^(BOOL started) {
		rv = started;
	}];
	
	return rv;
}

+ (void)stopRecording
{
	id<EPRecordingServiceProtocol> proxy = [currentConnection synchronousRemoteObjectProxyWithErrorHandler:^(NSError * _Nonnull error) {
		NSLog(@"Error: %@", error);
	}];
	[proxy stopRecording];
	[currentConnection invalidate];
	currentConnection = nil;
}

@end
