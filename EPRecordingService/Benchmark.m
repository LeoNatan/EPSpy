//
//  Benchmark.m
//  EPRecordingService
//
//  Created by Léo Natan on 12/02/2026.
//

#import "Benchmark.h"
@import CoreML;
@import Vision;
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

- (void)processImageAtURL:(NSURL *)URL iterations:(NSUInteger)iterations parallel:(BOOL)parallel devicePredicate:(NSString* __nullable)predicate exitAtEnd:(BOOL)exitAtEnd completionHandler:(void (^)(NSDictionary* results, NSError*))completionHandler
{
    void (^exitIfNeeded)(void) = ^ {
        if(exitAtEnd)
        {
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                exit(0);
            });
        }
    };

    __block NSError* _error = nil;

    NSArray<id<MLComputeDeviceProtocol>>* devices = MLAllComputeDevices();
    id<MLComputeDeviceProtocol> deviceToUse = nil;
    if(predicate != nil)
    {
        for(id<MLComputeDeviceProtocol> device in devices)
        {
            if([NSStringFromClass(device.class) localizedCaseInsensitiveContainsString:predicate])
            {
                deviceToUse = device;
                break;
            }
        }
    }

    dispatch_queue_attr_t attr = dispatch_queue_attr_make_with_qos_class(parallel ? DISPATCH_QUEUE_CONCURRENT : NULL, QOS_CLASS_USER_INITIATED, 0);
    dispatch_queue_t queue = ln_dispatch_queue_create_autoreleasing("q", attr);

    NSMutableArray* results = [[NSMutableArray alloc] initWithCapacity:iterations];
    for (size_t idx = 0; idx < iterations; idx++) {
        results[idx] = @0.0;
    }

    NSTimeInterval start = NSDate.timeIntervalSinceReferenceDate;

    dispatch_apply(iterations, queue, ^(size_t iteration) {
        dispatch_group_t group = dispatch_group_create();
        dispatch_group_enter(group);

        VNRecognizeTextRequest* request = [[VNRecognizeTextRequest alloc] initWithCompletionHandler:^(VNRequest * _Nonnull request, NSError * _Nullable error) {
            if(error)
            {
                _error = error;
            }

            dispatch_group_leave(group);
        }];
        request.recognitionLanguages = @[@"en"];
        request.automaticallyDetectsLanguage = NO;
        request.preferBackgroundProcessing = NO;
        request.revision = VNRequest.currentRevision;
        [request setComputeDevice:deviceToUse forComputeStage:VNComputeStageMain];
//        [request setComputeDevice:deviceToUse forComputeStage:VNComputeStagePostProcessing];

        VNImageRequestHandler* handler = [[VNImageRequestHandler alloc] initWithURL:URL options:@{}];

        NSTimeInterval innerStart = NSDate.timeIntervalSinceReferenceDate;

        if([handler performRequests:@[request] error:&_error])
        {
            dispatch_group_wait(group, DISPATCH_TIME_FOREVER);
        }

        NSTimeInterval innerEnd = NSDate.timeIntervalSinceReferenceDate;
        results[iteration] = @(innerEnd - innerStart);
    });

    NSTimeInterval end = NSDate.timeIntervalSinceReferenceDate;

    NSMutableDictionary* rv = [NSMutableDictionary new];
    rv[@"totalDuration"] = @(end - start);
    rv[@"results"] = results;

    NSMutableDictionary* compute = [NSMutableDictionary new];
    compute[@"availableDevices"] = [devices valueForKeyPath:@"class.description"];
    NSDictionary* supported = [[VNRecognizeTextRequest new] supportedComputeStageDevicesAndReturnError:NULL];
    compute[@"supportedDevicesMain"] = [supported[VNComputeStageMain] valueForKeyPath:@"class.description"] ?: @[];
    compute[@"supportedDevicesPost"] = [supported[VNComputeStagePostProcessing] valueForKeyPath:@"class.description"] ?: @[];
    compute[@"deviceUsed"] = deviceToUse.class.description;
    rv[@"computeDevices"] = compute;

    NSMutableDictionary* device = [NSMutableDictionary new];
    device[@"hw_model"] = [self _hwModel];
    device[@"hw_machine"] = [self _hwMachine];
	device[@"os"] = NSProcessInfo.processInfo.operatingSystemVersionString;
	device[@"visionRevision"] = @(VNRequest.currentRevision);
    rv[@"hostMachine"] = device;

    completionHandler(rv, _error);
    exitIfNeeded();
}

@end
