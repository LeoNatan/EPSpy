//
//  EPRecorder.mm
//  EPRecorder
//
//  Created by Léo Natan on 18/6/25.
//

#import <EPRecorder/EPRecorder.h>
#import <EndpointSecurity/EndpointSecurity.h>

#import "EPRecorderSerialization.h"

static es_client_t* client = NULL;
static NSFileHandle* fileHandle = nil;

static dispatch_queue_t writerQueue = dispatch_queue_create("eprecorder.writer", NULL);
static NSMutableArray* eventsToWrite = nil;

@implementation EPRecorderOptions

+ (BOOL)supportsSecureCoding
{
	return YES;
}

- (void)encodeWithCoder:(nonnull NSCoder *)coder
{
	[coder encodeBool:_ignorePlatformProcesses forKey:@"ignorePlatformProcesses"];
	[coder encodeBool:_expandProcess forKey:@"expandProcess"];
	[coder encodeBool:_recordLaunchArguments forKey:@"recordLaunchArguments"];
	[coder encodeBool:_recordEnvironmentVariables forKey:@"recordEnvironmentVariables"];
}

- (nullable instancetype)initWithCoder:(nonnull NSCoder *)coder
{ 
	self = [super init];
	if(self)
	{
		_ignorePlatformProcesses = [coder decodeBoolForKey:@"ignorePlatformProcesses"];
		_expandProcess = [coder decodeBoolForKey:@"expandProcess"];
		_recordLaunchArguments = [coder decodeBoolForKey:@"recordLaunchArguments"];
		_recordEnvironmentVariables = [coder decodeBoolForKey:@"recordEnvironmentVariables"];
	}
	return self;
}

@end

BOOL EPRecorderStartRecording(NSURL* url, NSArray<NSNumber*>* events, EPRecorderOptions* options)
{
	NSError* err;
	[NSFileManager.defaultManager removeItemAtURL:url error:NULL];
	[NSFileManager.defaultManager createFileAtPath:url.path contents:nil attributes:@{NSFilePosixPermissions: @0666}];
	fileHandle = [NSFileHandle fileHandleForWritingToURL:url error:&err];
	
	if(err != nil)
	{
		return NO;
	}
	
	eventsToWrite = [NSMutableArray new];
	
	es_new_client_result_t res = es_new_client(&client, ^(es_client_t * _Nonnull client, const es_message_t * _Nonnull message) {
		es_retain_message(message);
		dispatch_async(writerQueue, ^{
			NSDictionary* dict = EPRecorderDictionaryForMessage(message, options);
			if(dict != nil)
			{
				[eventsToWrite addObject:dict];
			}
			es_release_message(message);
		});
	});
	
	if(res != ES_NEW_CLIENT_RESULT_SUCCESS)
	{
		return false;
	}
	
	es_event_type_t _events[events.count];
	for(NSUInteger idx = 0; idx < events.count; idx++)
	{
		_events[idx] = (es_event_type_t)events[idx].unsignedIntValue;
	}
	
	es_mute_path(client, "/usr/libexec/endpointsecurityd", ES_MUTE_PATH_TYPE_LITERAL);
	
	if(ES_RETURN_ERROR == es_subscribe(client, _events, (uint32_t)events.count))
	{
		es_delete_client(client);
		client = NULL;
		return false;
	}
	
	return true;
}

void EPRecorderStopRecording(void)
{
	es_delete_client(client);
	client = NULL;
	
	dispatch_sync(writerQueue, ^{
		if(eventsToWrite != nil)
		{
			[fileHandle writeData:[NSJSONSerialization dataWithJSONObject:eventsToWrite options:NSJSONWritingPrettyPrinted | NSJSONWritingSortedKeys | NSJSONWritingWithoutEscapingSlashes error:NULL]];
			eventsToWrite = nil;
		}
		[fileHandle closeFile];
		fileHandle = nil;
		
		exit(0);
	});
}
