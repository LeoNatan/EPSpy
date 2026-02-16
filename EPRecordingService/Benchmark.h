//
//  Benchmark.h
//  EPRecordingService
//
//  Created by Léo Natan on 12/02/2026.
//

#import <Foundation/Foundation.h>
#import "EPRecordingServiceProtocol.h"

NS_ASSUME_NONNULL_BEGIN

@interface Benchmark : NSObject <EPRecordingServiceProtocol>

- (void)processImageAtURL:(NSURL*)URL iterations:(NSUInteger)iterations parallel:(BOOL)parallel devicePredicate:(NSString* __nullable)predicate inputScale:(double)scale exitAtEnd:(BOOL)exitAtEnd completionHandler:(void (^)(NSDictionary* results, NSError* __nullable))completionHandler;

@end

NS_ASSUME_NONNULL_END
