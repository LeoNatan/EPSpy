//
//  main.m
//  EPRecordingService
//
//  Created by Léo Natan on 18/6/25.
//

#import <Foundation/Foundation.h>
#import "EPRecordingServiceProtocol.h"

@interface XPCListener : NSObject <NSXPCListenerDelegate, EPRecordingServiceProtocol> @end
@implementation XPCListener
{
	NSXPCListener* _listener;
}

- (void)start
{
	NSLog(@"%@", EPRecorderOptions.class);
	
	_listener = [[NSXPCListener alloc] initWithMachServiceName:@"com.LeoNatan.EPRecordingService.xpc"];
	_listener.delegate = self;
	[_listener resume];
	
	dispatch_main();
}

- (BOOL)listener:(NSXPCListener *)listener shouldAcceptNewConnection:(NSXPCConnection *)newConnection
{
	newConnection.exportedInterface = [NSXPCInterface interfaceWithProtocol:@protocol(EPRecordingServiceProtocol)];
	newConnection.invalidationHandler = ^{
		[self stopRecording];
	};
	newConnection.exportedObject = self;
	[newConnection resume];
	
	return YES;
}

- (void)startRecordingWithURL:(NSURL *)URL events:(NSArray<NSNumber*>*)events options:(EPRecorderOptions *)options completionHandler:(void (^)(BOOL))completionHandler
{
	completionHandler(EPRecorderStartRecording(URL, events, options));
}

- (void)stopRecording
{
	EPRecorderStopRecording();
}

@end

int main(int argc, const char * argv[]) {
	[[XPCListener new] start];
}
