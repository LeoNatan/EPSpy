//
//  Benchmark.m
//  EPRecordingService
//
//  Created by Léo Natan on 12/02/2026.
//

#import "Benchmark.h"
@import Speech;
@import Darwin;

#define ln_dispatch_queue_create_autoreleasing(name, attr) dispatch_queue_create(name, dispatch_queue_attr_make_with_autorelease_frequency(attr, DISPATCH_AUTORELEASE_FREQUENCY_WORK_ITEM))

@implementation Benchmark

- (NSString*)_hwModel
{
    size_t len = 0;
    NSString* rv = NULL;
    sysctlbyname("hw.model", NULL, &len, NULL, 0);

    if(len > 0)
    {
        char *cStr = malloc(len * sizeof(char));
        sysctlbyname("hw.model", cStr, &len, NULL, 0);

        rv = [NSString stringWithUTF8String:cStr];
        free(cStr);
    }

    return rv;
}

- (NSString*)_hwMachine
{
    size_t len = 0;
    NSString* rv = NULL;
    sysctlbyname("hw.machine", NULL, &len, NULL, 0);

    if(len > 0)
    {
        char *cStr = malloc(len * sizeof(char));
        sysctlbyname("hw.machine", cStr, &len, NULL, 0);

        rv = [NSString stringWithUTF8String:cStr];
        free(cStr);
    }

    return rv;
}

- (SFSpeechRecognitionRequest*)_handlerForURL:(NSURL*)URL
{
    SFSpeechURLRecognitionRequest* rv = [[SFSpeechURLRecognitionRequest alloc] initWithURL:URL];

    rv.shouldReportPartialResults = NO;
    rv.requiresOnDeviceRecognition = YES;
    rv.addsPunctuation = NO;

	return rv;
}

- (void)processImageAtURL:(NSURL *)URL iterations:(NSUInteger)iterations parallel:(BOOL)parallel devicePredicate:(NSString* __nullable)predicate inputScale:(double)scale correct:(BOOL)correct exitAtEnd:(BOOL)exitAtEnd completionHandler:(void (^)(NSDictionary* results, NSError*))completionHandler
{
    void (^exitIfNeeded)(void) = ^ {
        if(exitAtEnd)
        {
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                exit(0);
            });
        }
    };

    NSOperationQueue* queue = [NSOperationQueue new];
    queue.maxConcurrentOperationCount = NSOperationQueueDefaultMaxConcurrentOperationCount;

    SFSpeechRecognizer* recognizer = [SFSpeechRecognizer new];
    recognizer.queue = queue;

    NSParameterAssert(recognizer.available);
    NSParameterAssert(recognizer.supportsOnDeviceRecognition);

    NSTimeInterval start = NSDate.timeIntervalSinceReferenceDate;

    [recognizer recognitionTaskWithRequest:[self _handlerForURL:URL] resultHandler:^(SFSpeechRecognitionResult * _Nullable result, NSError * _Nullable error) {
        NSTimeInterval end = NSDate.timeIntervalSinceReferenceDate;

        NSMutableDictionary* rv = [NSMutableDictionary new];
        rv[@"totalDuration"] = @(end - start);
        rv[@"results"] = @[@(end - start)];

        NSMutableDictionary* device = [NSMutableDictionary new];
        device[@"hw_model"] = [self _hwModel];
        device[@"hw_machine"] = [self _hwMachine];
        device[@"os"] = NSProcessInfo.processInfo.operatingSystemVersionString;
        rv[@"hostMachine"] = device;

        NSMutableArray<NSDictionary<NSString*, id>*>* parsedText = [NSMutableArray new];
        SFTranscription* toUse = result.bestTranscription;
        if(toUse)
        {
            [parsedText addObject:@{
                @"confidence": @0.0,
                @"string": toUse.formattedString,
            }];
            rv[@"parseResults"] = parsedText;
        }

        completionHandler(rv, error);
        exitIfNeeded();
    }];
}

@end
