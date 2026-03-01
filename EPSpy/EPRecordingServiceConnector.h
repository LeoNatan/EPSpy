//
//  EPRecordingServiceConnector.h
//  EPSpy
//
//  Created by Léo Natan on 18/6/25.
//

#import <Foundation/Foundation.h>
#import "EPRecordingServiceProtocol.h"

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSUInteger, BenchmarkTargetProcess) {
    BenchmarkTargetProcessLocal,
    BenchmarkTargetProcessUserService,
    BenchmarkTargetProcessRootDaemon,
};

@interface EPRecordingServiceConnector : NSObject

+ (void)processImageAtURL:(NSURL*)URL iterations:(NSUInteger)iterations parallel:(BOOL)parallel devicePredicate:(NSString* __nullable)predicate inputScale:(double)scale correct:(BOOL)correct targetProcess:(BenchmarkTargetProcess)targetProcess completionHandler:(void (^)(NSDictionary<NSString*, id>* results, NSError* __nullable))completionHandler;

@end

NS_ASSUME_NONNULL_END
