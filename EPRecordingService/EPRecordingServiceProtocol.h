//
//  EPRecordingServiceProtocol.h
//  EPSpy
//
//  Created by Léo Natan on 18/6/25.
//

#import <Foundation/Foundation.h>
#import "EPRecorder.h"

@protocol EPRecordingServiceProtocol <NSObject>

- (void)startRecordingWithURL:(NSURL*)URL events:(NSArray<NSNumber*>*)events options:(EPRecorderOptions*)options completionHandler:(void (^)(BOOL))completionHandler;
- (void)stopRecordingWithCompletionHandler:(void (^)(void))completionHandler;

@end
