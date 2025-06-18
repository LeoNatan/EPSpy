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
	
	NSXPCConnection* connection = [[NSXPCConnection alloc] initWithMachServiceName:@"com.LeoNatan.EPRecordingService.xpc" options:NSXPCConnectionPrivileged];
	connection.remoteObjectInterface = [NSXPCInterface interfaceWithProtocol:@protocol(EPRecordingServiceProtocol)];
	[connection resume];
	
	rv = NO;
	id<EPRecordingServiceProtocol> proxy = [connection synchronousRemoteObjectProxyWithErrorHandler:^(NSError * _Nonnull error) {
		NSLog(@"Error: %@", error);
	}];
	[proxy startRecordingWithURL:URL events:events options:options completionHandler:^(BOOL started) {
		rv = started;
	}];
	
	return rv;
}

+ (void)stopRecording
{
	NSXPCConnection* connection = [[NSXPCConnection alloc] initWithMachServiceName:@"com.LeoNatan.EPRecordingService.xpc" options:NSXPCConnectionPrivileged];
	connection.remoteObjectInterface = [NSXPCInterface interfaceWithProtocol:@protocol(EPRecordingServiceProtocol)];
	[connection resume];
	
	id<EPRecordingServiceProtocol> proxy = [connection synchronousRemoteObjectProxyWithErrorHandler:^(NSError * _Nonnull error) {
		NSLog(@"Error: %@", error);
	}];
	[proxy stopRecording];
}

@end
