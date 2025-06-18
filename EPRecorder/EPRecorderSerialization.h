//
//  EPRecorderSerialization.h
//  EPRecorder
//
//  Created by Léo Natan on 18/6/25.
//

#import <Foundation/Foundation.h>
#import <EndpointSecurity/EndpointSecurity.h>

@class EPRecorderOptions;

NS_ASSUME_NONNULL_BEGIN

NSDictionary* EPRecorderDictionaryForMessage(const es_message_t* message, EPRecorderOptions* options);

NS_ASSUME_NONNULL_END
