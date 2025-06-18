//
//  EPRecorder.h
//  EPRecorder
//
//  Created by Léo Natan on 18/6/25.
//

#import <Foundation/Foundation.h>
#import <EPRecorder/EPRecorderOptions.h>

//! Project version number for EPRecorder.
FOUNDATION_EXPORT double EPRecorderVersionNumber;

//! Project version string for EPRecorder.
FOUNDATION_EXPORT const unsigned char EPRecorderVersionString[];

CF_ASSUME_NONNULL_BEGIN
CF_EXTERN_C_BEGIN

BOOL EPRecorderStartRecording(NSURL* url, NSArray<NSNumber*>* events, EPRecorderOptions* options);
void EPRecorderStopRecording(void);

CF_EXTERN_C_END
CF_ASSUME_NONNULL_END
