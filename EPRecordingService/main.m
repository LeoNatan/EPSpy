//
//  main.m
//  EPRecordingService
//
//  Created by Léo Natan on 18/6/25.
//

#import <Foundation/Foundation.h>
#import "EPRecordingServiceProtocol.h"

#import "Benchmark.h"

@interface XPCListener : NSObject <NSXPCListenerDelegate, EPRecordingServiceProtocol> @end
@implementation XPCListener
{
	NSXPCListener* _listener;
}

- (void)start
{
	_listener = [[NSXPCListener alloc] initWithMachServiceName:@"com.LeoNatan.CSMark.xpc"];
	_listener.delegate = self;
	[_listener resume];
	
	dispatch_main();
}

- (BOOL)listener:(NSXPCListener *)listener shouldAcceptNewConnection:(NSXPCConnection *)newConnection
{
	newConnection.exportedInterface = [NSXPCInterface interfaceWithProtocol:@protocol(EPRecordingServiceProtocol)];
	newConnection.invalidationHandler = ^{
		exit(0);
	};
	newConnection.exportedObject = self;
	[newConnection resume];
	
	return YES;
}

- (void)processImageAtURL:(NSURL *)URL iterations:(NSUInteger)iterations parallel:(BOOL)parallel devicePredicate:(NSString* __nullable)predicate  inputScale:(double)scale exitAtEnd:(BOOL)exitAtEnd completionHandler:(void (^)(NSDictionary* results, NSError*))completionHandler
{
	[[Benchmark new] processImageAtURL:URL iterations:iterations parallel:parallel devicePredicate:predicate inputScale:scale exitAtEnd:exitAtEnd completionHandler:completionHandler];
}

@end

int main(int argc, const char * argv[]) {
	[[XPCListener new] start];
}
