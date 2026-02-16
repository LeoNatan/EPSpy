//
//  EPRecordingServiceProtocol.h
//  EPSpy
//
//  Created by Léo Natan on 18/6/25.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@protocol EPRecordingServiceProtocol <NSObject>

- (void)processImageAtURL:(NSURL*)URL iterations:(NSUInteger)iterations parallel:(BOOL)parallel devicePredicate:(NSString* __nullable)predicate inputScale:(double)scale exitAtEnd:(BOOL)exitAtEnd completionHandler:(void (^)(NSDictionary* results, NSError* __nullable))completionHandler;

@end

NS_ASSUME_NONNULL_END
