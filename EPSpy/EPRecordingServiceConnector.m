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
#import "Benchmark.h"

static NSXPCConnection* currentConnection = nil;

#define ln_dispatch_queue_create_autoreleasing(name, attr) dispatch_queue_create(name, dispatch_queue_attr_make_with_autorelease_frequency(attr, DISPATCH_AUTORELEASE_FREQUENCY_WORK_ITEM))

@implementation EPRecordingServiceConnector

+ (void)processImageAtURL:(NSURL*)URL iterations:(NSUInteger)iterations parallel:(BOOL)parallel devicePredicate:(NSString* __nullable)predicate inputScale:(double)scale targetProcess:(BenchmarkTargetProcess)targetProcess completionHandler:(void (^)(NSDictionary<NSString*, id>* results, NSError* __nullable))completionHandler
{
    completionHandler = ^(NSDictionary* results, NSError* error) {
        NSMutableDictionary* run = [NSMutableDictionary new];
        run[@"iterations"] = @(iterations);
        run[@"parallel"] = @(parallel);
		run[@"inputScale"] = @(scale);
        run[@"processTarget"] = @(targetProcess);

        NSMutableDictionary* rv = [results mutableCopy];
        rv[@"runInformation"] = run;

        completionHandler(rv, error);
    };

    if(targetProcess == BenchmarkTargetProcessLocal)
    {
        dispatch_queue_t local = ln_dispatch_queue_create_autoreleasing("local benchmark", NULL);

        dispatch_async(local, ^{
			[[Benchmark new] processImageAtURL:URL iterations:iterations parallel:parallel devicePredicate:predicate inputScale:scale exitAtEnd:NO completionHandler:completionHandler];
        });

        return;
    }

	NSError* err;
	SMAppService* service = [SMAppService daemonServiceWithPlistName:@"com.LeoNatan.EPRecordingService.plist"];
	
	[service unregisterAndReturnError:&err];
	
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
		
		currentConnection = [[NSXPCConnection alloc] initWithMachServiceName:@"com.LeoNatan.CSMark.xpc" options:NSXPCConnectionPrivileged];
		currentConnection.remoteObjectInterface = [NSXPCInterface interfaceWithProtocol:@protocol(EPRecordingServiceProtocol)];
		[currentConnection resume];
		
		rv = NO;
		id<EPRecordingServiceProtocol> proxy = [currentConnection remoteObjectProxyWithErrorHandler:^(NSError * _Nonnull error) {
			NSLog(@"Error: %@", error);
            completionHandler(nil, error);
		}];
		[proxy processImageAtURL:URL iterations:iterations parallel:parallel devicePredicate:predicate inputScale:scale exitAtEnd:YES completionHandler:completionHandler];

		return;
	}
	
	[[NSAlert alertWithError:err] runModal];
	
	completionHandler(nil, err);
}

@end
