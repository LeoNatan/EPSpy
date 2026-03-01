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
@import CoreImage;

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

- (VNImageRequestHandler*)_handlerForURL:(NSURL*)URL scale:(double)scale timing:(NSMutableArray*)timing
{
	if(scale == 1.0)
	{
        //Use the URL directly

		return [[VNImageRequestHandler alloc] initWithURL:URL options:@{}];
	}

    if(scale > 1.0)
    {
        NSTimeInterval innerStart = NSDate.timeIntervalSinceReferenceDate;

        CIImage* ciImage = [CIImage imageWithContentsOfURL:URL];
        CVPixelBufferRef buffer = NULL;
        CVPixelBufferCreate(kCFAllocatorDefault, ciImage.extent.size.width, ciImage.extent.size.height, k32ARGBPixelFormat, (__bridge CFDictionaryRef)@{
            (__bridge id)kCVPixelBufferCGImageCompatibilityKey: @YES,
            (__bridge id)kCVPixelBufferCGBitmapContextCompatibilityKey: @YES
        }, &buffer);
        CIContext* ctx = [CIContext new];
        [ctx render:ciImage toCVPixelBuffer:buffer];

        id rv = [[VNImageRequestHandler alloc] initWithCVPixelBuffer:buffer options:@{}];

        CFRelease(buffer);

        NSTimeInterval innerEnd = NSDate.timeIntervalSinceReferenceDate;
        [timing addObject:@(innerEnd - innerStart)];

        return rv;
    }

    //Use CGImageSource to scale the image
	NSTimeInterval innerStart = NSDate.timeIntervalSinceReferenceDate;

	CGImageSourceRef src = CGImageSourceCreateWithURL((__bridge CFURLRef)URL, NULL);
	NSDictionary* props = CFBridgingRelease(CGImageSourceCopyPropertiesAtIndex(src, 0, NULL));
	NSInteger width = [props[@"PixelWidth"] integerValue];
	NSInteger height = [props[@"PixelHeight"] integerValue];
	NSInteger max = MAX(width, height);
	NSInteger scaled = round(scale * max);

	CGImageRef img = CGImageSourceCreateThumbnailAtIndex(src, 0, (__bridge CFDictionaryRef)@{
		(__bridge id)kCGImageSourceCreateThumbnailFromImageAlways: @1,
		(__bridge id)kCGImageSourceCreateThumbnailWithTransform: @1,
		(__bridge id)kCGImageSourceThumbnailMaxPixelSize: @(scaled)
	});

	id rv = [[VNImageRequestHandler alloc] initWithCGImage:img orientation:kCGImagePropertyOrientationUp options:@{}];

	CGImageRelease(img);
	CFRelease(src);

	NSTimeInterval innerEnd = NSDate.timeIntervalSinceReferenceDate;

	[timing addObject:@(innerEnd - innerStart)];

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

	__block NSArray<VNRecognizedTextObservation*>* parsedResults;

    dispatch_apply(iterations, queue, ^(size_t iteration) {
        dispatch_group_t group = dispatch_group_create();
        dispatch_group_enter(group);

		NSMutableArray* perItem = [NSMutableArray new];

        VNRecognizeTextRequest* request = [[VNRecognizeTextRequest alloc] initWithCompletionHandler:^(VNRequest * _Nonnull request, NSError * _Nullable error) {
            if(error)
            {
                _error = error;
            }

            dispatch_group_leave(group);
        }];
//        request.recognitionLanguages = @[@"en"];
//        request.automaticallyDetectsLanguage = NO;
        request.usesLanguageCorrection = correct;
        request.preferBackgroundProcessing = NO;
        request.revision = VNRequest.currentRevision;
        [request setComputeDevice:deviceToUse forComputeStage:VNComputeStageMain];
//        [request setComputeDevice:deviceToUse forComputeStage:VNComputeStagePostProcessing];

		VNImageRequestHandler* handler = [self _handlerForURL:URL scale:scale timing:perItem];

        NSTimeInterval innerStart = NSDate.timeIntervalSinceReferenceDate;

        if([handler performRequests:@[request] error:&_error])
        {
            dispatch_group_wait(group, DISPATCH_TIME_FOREVER);
        }

        NSTimeInterval innerEnd = NSDate.timeIntervalSinceReferenceDate;
		[perItem addObject:@(innerEnd - innerStart)];
		results[iteration] = perItem;

		if(iteration == 0)
		{
			parsedResults = request.results;
		}
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

	NSMutableArray<NSDictionary<NSString*, id>*>* parsedText = [NSMutableArray new];
	for (VNRecognizedTextObservation* to in parsedResults)
	{
		NSArray<VNRecognizedText*>* arr = [to topCandidates:1];
		if(arr.count == 0)
		{
			continue;
		}
		VNRecognizedText* toUse = arr[0];

		[parsedText addObject:@{
			@"confidence": @(toUse.confidence),
			@"string": toUse.string
		}];
	}
	rv[@"parseResults"] = parsedText;

    completionHandler(rv, _error);
    exitIfNeeded();
}

@end
