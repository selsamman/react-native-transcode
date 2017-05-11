#import "Transcode.h"
#import "SDAVAssetExportSession.h"
static inline CGFloat RadiansToDegrees(CGFloat radians) {
    return radians * 180 / M_PI;
};

static TranscodeProgress * progress;

@implementation TranscodeProgress

RCT_EXPORT_MODULE();

- (void)startObserving {
    progress = self;
}

- (void)stopObserving {
    progress = nil;
}


- (NSArray<NSString *> *)supportedEvents
{
    return @[@"Progress"];
}



- (void)sendNotification:(NSNumber *) progress
{
    [self sendEventWithName:@"Progress" body:@{@"progress":progress}];
}

@end


@implementation Transcode

NSMutableDictionary *files;
NSMutableArray *segments;
NSMutableDictionary *currentSegment;
//AVAssetExportSession *assetExportSession;
SDAVAssetExportSession *assetExportSession;
NSTimer *exportProgressBarTimer;

+ (NSString*)sayHello {
  return @"Native hello world!";
}

RCT_EXPORT_MODULE()

RCT_EXPORT_METHOD(sayHello:(RCTPromiseResolveBlock)resolve rejecter:(RCTPromiseRejectBlock)reject) {
  resolve([Transcode sayHello]);
}

RCT_EXPORT_METHOD(start) {
    files = [NSMutableDictionary dictionary];
    segments = [NSMutableArray array];
}

RCT_EXPORT_METHOD(asset:(NSDictionary *) inputParameters) {
    NSString *inputFilePath = [inputParameters valueForKey:@"path"];
    NSString *assetName = [inputParameters valueForKey:@"name"];
    NSString *assetType = [inputParameters valueForKey:@"type"];
    if (assetType == nil)
        assetType = @"AudioVideo";
    NSURL *inputFileURL = [self getURLFromFilePath:inputFilePath];
    AVURLAsset *avAsset = [AVURLAsset URLAssetWithURL:inputFileURL options:@{AVURLAssetPreferPreciseDurationAndTimingKey : @YES}];
    NSArray *videoTracks = [avAsset tracksWithMediaType:AVMediaTypeVideo];
    NSArray *audioTracks = [avAsset tracksWithMediaType:AVMediaTypeAudio];
    AVAssetTrack *videoTrack = [videoTracks count] > 0 ? [videoTracks objectAtIndex:0] : @"None";
    AVAssetTrack *audioTrack = [audioTracks count] > 0 ? [audioTracks objectAtIndex:0] : @"None";
    NSMutableDictionary *asset = [NSMutableDictionary dictionaryWithDictionary:
            @{@"url":inputFileURL, @"avAsset": avAsset, @"videoTrack":videoTrack, @"audioTrack":audioTrack,
              @"type":assetType, @"seek": [NSNumber numberWithInteger:0]}];
    [files setObject: asset forKey: assetName];
}

RCT_EXPORT_METHOD(segment:(NSInteger) duration) {
    currentSegment = [NSMutableDictionary dictionaryWithDictionary: @{@"duration": [NSNumber numberWithInteger:duration], @"tracks":[NSMutableArray array]}];
    [segments addObject: currentSegment];
}

RCT_EXPORT_METHOD(track:(NSDictionary *) inputParameters) {
    NSMutableDictionary *parameters = [inputParameters mutableCopy];
    if ([parameters valueForKey: @"seek"] == nil)
        [parameters setObject:[NSNumber numberWithInteger: 0] forKey: @"seek"];
    NSMutableArray * tracks = [currentSegment valueForKey:@"tracks"];
    [tracks addObject:parameters];
}

RCT_EXPORT_METHOD(process:(NSString*)resolution outputFilePath:(NSString*)outputFilePath resolver:(RCTPromiseResolveBlock)resolve rejecter:(RCTPromiseRejectBlock)reject) {

    NSError *audioVideoError;
    AVMutableComposition *composition = [AVMutableComposition composition];
    
    AVMutableCompositionTrack *mutableCompositionTrack1 = [composition addMutableTrackWithMediaType:AVMediaTypeVideo preferredTrackID: kCMPersistentTrackID_Invalid];
    AVMutableCompositionTrack *mutableCompositionTrack2 = [composition addMutableTrackWithMediaType:AVMediaTypeVideo preferredTrackID: kCMPersistentTrackID_Invalid];
    
    AVMutableAudioMix *mix = [AVMutableAudioMix audioMix];
    AVMutableAudioMixInputParameters *audioParams = [AVMutableAudioMixInputParameters audioMixInputParameters];
    
    CMTime outputPosition = CMTimeMake(0, 1000);
    
    NSMutableArray *audioTracks = [NSMutableArray array];
    NSMutableArray *videoTracks = [NSMutableArray array];
    NSMutableArray *transitionSegments = [NSMutableArray array];
    
    [videoTracks addObject:mutableCompositionTrack1];
    [videoTracks addObject:mutableCompositionTrack2];
    
    AVAssetTrack *firstAssetTrack;
    
    // Loop through each segment
    for (NSUInteger segmentIndex = 0; segmentIndex < [segments count]; segmentIndex++) {
        
        NSMutableDictionary *currentSegment = segments[segmentIndex];
        CMTime segmentDuration = CMTimeMake([[currentSegment valueForKey: @"duration"] integerValue], 1000);

        int videoTrackIndex = 0;
        int audioTrackIndex = 0;
    
        NSMutableArray *layerInstructions = [NSMutableArray array];
        NSArray * segmentTracks = [currentSegment valueForKey:@"tracks"];
        
        // Loop throught the tracks in the segment and add each track to the composition
        for (NSMutableDictionary *currentTrack in segmentTracks) {
            
            NSString *filter = [currentTrack valueForKey: @"filter"];
 
            // Grab assets
            NSString *assetName = [currentTrack valueForKey:@"asset"];
            NSMutableDictionary *asset = [files valueForKey:assetName];
            AVAsset *avAsset = [asset valueForKey: @"avAsset"];
            NSString *trackType = [asset valueForKey: @"type"];
            AVAssetTrack *assetTrack = [asset valueForKey: @"videoTrack"];
            if (firstAssetTrack == nil)
                firstAssetTrack = assetTrack;
            
            // Compute end time of segment which can't be greater than segment declared duration
            long trackStartTimeMs = [[currentTrack valueForKey:@"seek"] longValue] + [[asset valueForKey:@"seek"] longValue];
            CMTime trackStartTime = CMTimeMake(trackStartTimeMs, 1000);
            CMTime trackDuration = CMTimeSubtract([avAsset duration], trackStartTime);
            segmentDuration = CMTimeMinimum(segmentDuration, trackDuration);
            CMTimeRange timeRange =CMTimeRangeMake(trackStartTime, segmentDuration);
            [asset setObject:[NSNumber numberWithInteger: trackStartTimeMs + segmentDuration.value] forKey:@"seek"];
            
            // Insert video track segment
            if (segmentDuration.value > 0 && ([trackType isEqualToString: @"Video"] || [trackType isEqualToString:@"AudioVideo"])) {
                
                
                // Determine video track to use.  We only need multiple tracks to create multiple layers for transition effects
                // so only segments with mutliple video tracks would get a second track.  For now a maximum of two is enforced
                AVMutableCompositionTrack *videoTrack;
                if (videoTrackIndex >= [videoTracks count]) {
                    videoTrack = [composition addMutableTrackWithMediaType:AVMediaTypeVideo preferredTrackID: kCMPersistentTrackID_Invalid];
                    [videoTracks addObject: videoTrack];
                } else
                    videoTrack = videoTracks[videoTrackIndex];
                
                CGAffineTransform transform = assetTrack.preferredTransform;
                videoTrack.preferredTransform = transform;
                
                // Add the input asset to the video track
                [videoTrack
                    insertTimeRange:timeRange
                    ofTrack:[asset valueForKey: @"videoTrack"]
                    atTime: outputPosition error: &audioVideoError];
                
                if (audioVideoError) {
                    reject(@"ERROR", [[audioVideoError localizedDescription] stringByAppendingString:@" Adding Video Segment"], audioVideoError);
                    return;
                }
                
                // Record the filter so we can match up later when we get the layer instructions
                if ([filter isEqualToString: @"FadeOut"]) {
                    [currentSegment setObject:[NSNumber numberWithInt:videoTrackIndex]  forKey: @"fadeOutTrackIndex"];
                }
               
                ++videoTrackIndex;
            }

            // Insert audio track segment
            if (segmentDuration.value > 0 && ([trackType isEqualToString: @"Audio"] || [trackType isEqualToString:@"AudioVideo"])) {

                // Same approach as video for audio tracks
                AVMutableCompositionTrack *audioTrack;
                if (audioTrackIndex >= [audioTracks count]) {
                    audioTrack = [composition addMutableTrackWithMediaType:AVMediaTypeAudio preferredTrackID: kCMPersistentTrackID_Invalid];
                    [audioTracks addObject: audioTrack];
                } else
                    audioTrack = audioTracks[audioTrackIndex];
                
                [audioTrack
                 insertTimeRange:timeRange
                 ofTrack:[asset valueForKey: @"audioTrack"]
                 atTime: outputPosition error: &audioVideoError];
                
                if (audioVideoError) {
                    reject(@"ERROR", [[audioVideoError localizedDescription] stringByAppendingString:@" Adding Audio Segment"], audioVideoError);
                    return;
                }
                
                ++audioTrackIndex;
            }
        }
        
        // Calculate the time range for the segment and use to record duration in segment itself and increment outputPosition
        CMTimeRange timeRange = CMTimeRangeMake(outputPosition, segmentDuration);
        NSNumber *duration = [NSNumber numberWithLong: timeRange.duration.value];
        NSNumber *start = [NSNumber numberWithLong: timeRange.start.value];
        [currentSegment setObject: duration forKey:@"duration"];
        [currentSegment setObject: start forKey:@"start"];
        outputPosition = CMTimeAdd(outputPosition, timeRange.duration);

        // Keep list of transition segments (those that have multiple tracks)
        if (videoTrackIndex > 1)
            [transitionSegments addObject:currentSegment];
        if (videoTrackIndex > 2)
            reject(@"Error", @"Configuration", @"Segment has more than two video tracks");
    }
    
    // Creating the videoComposition from the composition ensures that we have default intructions and layerInstructions
    AVMutableVideoComposition *videoComposition = [AVMutableVideoComposition videoCompositionWithPropertiesOfAsset:composition];
    
    
    float trackFrameRate = [firstAssetTrack nominalFrameRate];
    
    if (trackFrameRate == 0)
    {
        trackFrameRate = 30;
    }
    
    // Determine any transformation that needs to occur
    videoComposition.frameDuration = CMTimeMake(1, trackFrameRate);
    CGSize targetSize = [resolution isEqualToString: @"high"] ? CGSizeMake(1920.0,1080.0) : CGSizeMake(1280.0, 720.0);
    CGSize naturalSize = [firstAssetTrack naturalSize];
    CGAffineTransform transform = firstAssetTrack.preferredTransform;
    CGFloat videoAngleInDegree  = atan2(transform.b, transform.a) * 180 / M_PI;
    if (videoAngleInDegree == 90 || videoAngleInDegree == -90) {
        CGFloat width = naturalSize.width;
        naturalSize.width = naturalSize.height;
        naturalSize.height = width;
    }
    videoComposition.renderSize = naturalSize;
    // center inside
    {
        float ratio;
        float xratio = targetSize.width / naturalSize.width;
        float yratio = targetSize.height / naturalSize.height;
        ratio = MIN(xratio, yratio);
        
        float postWidth = naturalSize.width * ratio;
        float postHeight = naturalSize.height * ratio;
        float transx = (targetSize.width - postWidth) / 2;
        float transy = (targetSize.height - postHeight) / 2;
        
        CGAffineTransform matrix = CGAffineTransformMakeTranslation(transx / xratio, transy / yratio);
        matrix = CGAffineTransformScale(matrix, ratio / xratio, ratio / yratio);
        transform = CGAffineTransformConcat(transform, matrix);
    }

    // Look at all instructions
    int layeredSegementsIndex = 0;
    for (AVMutableVideoCompositionInstruction *compositionInstruction in videoComposition.instructions) {
        
        // Those that have two layersInstructions relate to overlapping segments in the two tracks
        AVMutableVideoCompositionLayerInstruction * layerInstruction1 = compositionInstruction.layerInstructions[0];
        if (compositionInstruction.layerInstructions.count == 2) {

            // We kept track of all segments that should have two layerInstructiosn
            NSDictionary * layeredSegment = transitionSegments[layeredSegementsIndex];
            
            AVMutableVideoCompositionLayerInstruction * layerInstruction2 = compositionInstruction.layerInstructions[1];
            
            AVMutableVideoCompositionLayerInstruction * transitionLayerInstruction =
            [[layeredSegment valueForKey:@"fadeOutTrackIndex"] intValue] == 0 ? layerInstruction1 : layerInstruction2;
            
            // Add the opacity ramp for the entire time range of the segment
            long start = [(NSNumber *)[layeredSegment valueForKey:@"start"] longValue];
            long duration = [(NSNumber *)[layeredSegment valueForKey:@"duration"] longValue];
            CMTimeRange transitionRange = CMTimeRangeMake(CMTimeMake(start, 1000), CMTimeMake(duration, 1000));
            [transitionLayerInstruction setOpacityRampFromStartOpacity: 1.0 toEndOpacity:0.0 timeRange: transitionRange];
            
            //[layerInstruction2 setTransform: transform atTime:compositionInstruction.timeRange.start];
            
            
            ++layeredSegementsIndex;
        }
        //[layerInstruction1 setTransform: transform atTime:compositionInstruction.timeRange.start];
    }

    videoComposition.frameDuration = CMTimeMake(1, 30);

    
    int videoBitrate = 4000000; // default to 1 megabit
    int audioChannels =  2;
    int audioSampleRate =  44100;
    int audioBitrate = 128000; // default to 128 kilobits


    assetExportSession = [SDAVAssetExportSession.alloc initWithAsset:composition];
    assetExportSession.outputFileType = AVFileTypeMPEG4;
    assetExportSession.outputURL = [self getURLFromFilePath:outputFilePath];
    assetExportSession.shouldOptimizeForNetworkUse = NO;
    assetExportSession.videoSettings = @
    
    {
    AVVideoCodecKey: AVVideoCodecH264,
    AVVideoWidthKey: [NSNumber numberWithInt: naturalSize.width],
    AVVideoHeightKey: [NSNumber numberWithInt: naturalSize.height],
        /*
    AVVideoCompressionPropertiesKey: @
        {
        AVVideoAverageBitRateKey: [NSNumber numberWithInt: videoBitrate],
        AVVideoProfileLevelKey: AVVideoProfileLevelH264High40
        }*/
    };
    assetExportSession.audioSettings = @
    {
    AVFormatIDKey: @(kAudioFormatMPEG4AAC),
    AVNumberOfChannelsKey: [NSNumber numberWithInt: audioChannels],
    AVSampleRateKey: [NSNumber numberWithInt: audioSampleRate],
    AVEncoderBitRateKey: [NSNumber numberWithInt: audioBitrate]
    };
    
    
    
    
    
/*
    
    
    if ([self doFlipHeightWidth:firstAssetTrack])
        videoComposition.renderSize = [resolution isEqualToString: @"high"] ? CGSizeMake(1080.0, 1920.0) : CGSizeMake(720.0, 1280.0);
    else
        videoComposition.renderSize = [resolution isEqualToString: @"high"] ? CGSizeMake(1920.0,1080.0) : CGSizeMake(1280.0, 720.0);
    
    // Setup the AssetExport session
    NSURL *outputFileURL = [self getURLFromFilePath:outputFilePath];
    NSString *stringOutputFileType = AVFileTypeMPEG4;
    BOOL optimizeForNetworkUse = NO;
 
    if ([resolution isEqualToString: @"high"])
        assetExportSession = [AVAssetExportSession exportSessionWithAsset: composition presetName: AVAssetExportPreset1920x1080];
    else
        assetExportSession = [AVAssetExportSession exportSessionWithAsset: composition presetName: AVAssetExportPreset1280x720];

    
    
    assetExportSession.outputFileType = stringOutputFileType;
    assetExportSession.outputURL = outputFileURL;
    assetExportSession.shouldOptimizeForNetworkUse = optimizeForNetworkUse;
  */
    assetExportSession.timeRange = CMTimeRangeMake(CMTimeMake(0, 1000), outputPosition);
    assetExportSession.videoComposition = videoComposition;
    
    dispatch_async(dispatch_get_main_queue(), ^{
        exportProgressBarTimer = [NSTimer scheduledTimerWithTimeInterval:.1 target:self selector:@selector(updateExportDisplay) userInfo:nil repeats:YES];
    });
    
    
    // Start encoding
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        
        [assetExportSession exportAsynchronouslyWithCompletionHandler:^
         {
             if (assetExportSession.status == AVAssetExportSessionStatusCompleted)
             {
                 [exportProgressBarTimer invalidate];
                 NSLog(@"Video export succeeded ");
                 NSLog(@"Finished! Created %@", outputFilePath);
                 resolve(@"Finished");
             }
             else if (assetExportSession.status == AVAssetExportSessionStatusCancelled)
             {
                 [exportProgressBarTimer invalidate];
                 NSLog(@"Video export cancelled");
                 reject(@"cancel", @"Cancelled", @"Video export cancelled");
                 
             }
             else
             {
                 [exportProgressBarTimer invalidate];
                 NSLog(@"Video export failed with error: %@: %ld", assetExportSession.error.localizedDescription, assetExportSession.error.code);;
                 reject(@"failed", @"Failed", @"Video export failed");
             }
         }];
    });
    
    
}
- (void)updateExportDisplay {
    if (progress != nil)
        [progress sendNotification:@(assetExportSession.progress)];
    
}

- (boolean_t)doFlipHeightWidth:(AVAssetTrack *)videoTrack
{
    CGAffineTransform txf       = [videoTrack preferredTransform];
    CGFloat videoAngleInDegree  = RadiansToDegrees(atan2(txf.b, txf.a));
    
    boolean_t flip = false;
    switch ((int)videoAngleInDegree) {
        case 0:
            flip = false;
            break;
        case 90:
            flip = true;
            break;
        case 180:
            flip = false;
            break;
        case -90:
            flip = true;
            break;
        default:
            flip = false;
            break;
    }
    
    return flip;
}
RCT_EXPORT_METHOD(transcode2:(NSString *)inputFilePath outputFilePath:(NSString*)outputFilePath resolver:(RCTPromiseResolveBlock)resolve rejecter:(RCTPromiseRejectBlock)reject)
{
    NSURL *inputFileURL = [self getURLFromFilePath:inputFilePath];

    AVURLAsset *avAsset1 = [AVURLAsset URLAssetWithURL:inputFileURL options:@{AVURLAssetPreferPreciseDurationAndTimingKey : @YES}];
    NSArray *videoAssetTracks1 = [avAsset1 tracksWithMediaType:AVMediaTypeVideo];
    AVAssetTrack *videoAssetTrack1 = [videoAssetTracks1 objectAtIndex:0];
    
    AVURLAsset *avAsset2 = [AVURLAsset URLAssetWithURL:inputFileURL options:@{AVURLAssetPreferPreciseDurationAndTimingKey : @YES}];
    NSArray *videoAssetTracks2 = [avAsset2 tracksWithMediaType:AVMediaTypeVideo];
    AVAssetTrack *videoAssetTrack2 = [videoAssetTracks2 objectAtIndex:0];

    AVURLAsset *avAsset3 = [AVURLAsset URLAssetWithURL:inputFileURL options:@{AVURLAssetPreferPreciseDurationAndTimingKey : @YES}];
    NSArray *videoAssetTracks3 = [avAsset3 tracksWithMediaType:AVMediaTypeVideo];
    AVAssetTrack *videoAssetTrack3 = [videoAssetTracks3 objectAtIndex:0];
    
    AVURLAsset *avAsset4 = [AVURLAsset URLAssetWithURL:inputFileURL options:@{AVURLAssetPreferPreciseDurationAndTimingKey : @YES}];
    NSArray *videoAssetTracks4 = [avAsset4 tracksWithMediaType:AVMediaTypeVideo];
    AVAssetTrack *videoAssetTrack4 = [videoAssetTracks3 objectAtIndex:0];
    
    AVURLAsset *avAsset5 = [AVURLAsset URLAssetWithURL:inputFileURL options:@{AVURLAssetPreferPreciseDurationAndTimingKey : @YES}];
    NSArray *videoAssetTracks5 = [avAsset5 tracksWithMediaType:AVMediaTypeVideo];
    AVAssetTrack *videoAssetTrack5 = [videoAssetTracks5 objectAtIndex:0];
    
   
    AVMutableComposition *mutableComposition = [AVMutableComposition composition];
    AVMutableVideoComposition *videoComposition = [AVMutableVideoComposition videoComposition];
    NSError *audioVideoError;
    AVMutableCompositionTrack *mutableCompositionTrack1 = [mutableComposition addMutableTrackWithMediaType:AVMediaTypeVideo preferredTrackID: kCMPersistentTrackID_Invalid];
    AVMutableCompositionTrack *mutableCompositionTrack2 = [mutableComposition addMutableTrackWithMediaType:AVMediaTypeVideo preferredTrackID: kCMPersistentTrackID_Invalid];
    AVMutableCompositionTrack *mutableCompositionTrack3 = [mutableComposition addMutableTrackWithMediaType:AVMediaTypeVideo preferredTrackID: kCMPersistentTrackID_Invalid];
    AVMutableCompositionTrack *mutableCompositionTrack4 = [mutableComposition addMutableTrackWithMediaType:AVMediaTypeVideo preferredTrackID: kCMPersistentTrackID_Invalid];
    AVMutableCompositionTrack *mutableCompositionTrack5 = [mutableComposition addMutableTrackWithMediaType:AVMediaTypeVideo preferredTrackID: kCMPersistentTrackID_Invalid];
    
    [mutableCompositionTrack1
     insertTimeRange:CMTimeRangeMake(CMTimeMake(0, 1000), CMTimeMake(2999, 1000))
     ofTrack:videoAssetTrack1
     atTime: CMTimeMake(0, 1000)
     error: &audioVideoError];
    [mutableCompositionTrack1 insertEmptyTimeRange:CMTimeRangeMake(CMTimeMake(3000, 1000), CMTimeMake(10999, 1000))];

    [mutableCompositionTrack2
     insertTimeRange:CMTimeRangeMake(CMTimeMake(0, 1000), CMTimeMake(2999, 1000))
     ofTrack:videoAssetTrack2
     atTime: CMTimeMake(3000, 1000)
     error: &audioVideoError];
    
    if (audioVideoError) {
        NSLog(@"!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!! Error - %@", audioVideoError.debugDescription);
    }
/*
    [mutableCompositionTrack3
     insertTimeRange:CMTimeRangeMake(CMTimeMake(0, 1000), CMTimeMake(2999, 1000))
     ofTrack:videoAssetTrack3
     atTime: CMTimeMake(4000, 1000)
     error: &audioVideoError];

    if (audioVideoError) {
        NSLog(@"!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!! Error - %@", audioVideoError.debugDescription);
    }

    [mutableCompositionTrack4
     insertTimeRange:CMTimeRangeMake(CMTimeMake(0, 1000), CMTimeMake(2999, 1000))
     ofTrack:videoAssetTrack4
     atTime: CMTimeMake(6000, 1000)
     error: &audioVideoError];
    
    if (audioVideoError) {
        NSLog(@"!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!! Error - %@", audioVideoError.debugDescription);
    }
    
    [mutableCompositionTrack5
     insertTimeRange:CMTimeRangeMake(CMTimeMake(0, 1000), CMTimeMake(2999, 1000))
     ofTrack:videoAssetTrack5
     atTime: CMTimeMake(8000, 1000)
     error: &audioVideoError];
*/
    if (audioVideoError) {
        NSLog(@"!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!! Error - %@", audioVideoError.debugDescription);
    }
    
    AVMutableVideoCompositionLayerInstruction *layerInstruction1 = [AVMutableVideoCompositionLayerInstruction videoCompositionLayerInstructionWithAssetTrack:mutableCompositionTrack1];
    //[layerInstruction1 setOpacityRampFromStartOpacity: 1.0 toEndOpacity: 0.0 timeRange:CMTimeRangeMake(CMTimeMake(2000, 1000), CMTimeMake(2999, 1000))];

    AVMutableVideoCompositionLayerInstruction *layerInstruction2 = [AVMutableVideoCompositionLayerInstruction videoCompositionLayerInstructionWithAssetTrack:mutableCompositionTrack2];
    //[layerInstruction2 setOpacityRampFromStartOpacity: 1.0 toEndOpacity: 0.0 timeRange:CMTimeRangeMake(CMTimeMake(4000, 1000), CMTimeMake(4999, 1000))];
/*
    AVMutableVideoCompositionLayerInstruction *layerInstruction3 = [AVMutableVideoCompositionLayerInstruction videoCompositionLayerInstructionWithAssetTrack:mutableCompositionTrack3];
    [layerInstruction3 setOpacityRampFromStartOpacity: 1.0 toEndOpacity: 0.0 timeRange:CMTimeRangeMake(CMTimeMake(6000, 1000), CMTimeMake(6999, 1000))];

    AVMutableVideoCompositionLayerInstruction *layerInstruction4 = [AVMutableVideoCompositionLayerInstruction videoCompositionLayerInstructionWithAssetTrack:mutableCompositionTrack4];
    [layerInstruction4 setOpacityRampFromStartOpacity: 1.0 toEndOpacity: 0.0 timeRange:CMTimeRangeMake(CMTimeMake(8000, 1000), CMTimeMake(8999, 1000))];

    AVMutableVideoCompositionLayerInstruction *layerInstruction5 = [AVMutableVideoCompositionLayerInstruction videoCompositionLayerInstructionWithAssetTrack:mutableCompositionTrack5];
*/
    AVMutableVideoCompositionInstruction *instruction1 = [AVMutableVideoCompositionInstruction videoCompositionInstruction];
    instruction1.backgroundColor = [[UIColor clearColor] CGColor];
    instruction1.timeRange = CMTimeRangeMake(CMTimeMake(0, 1000), CMTimeMake(2999, 1000));
    instruction1.layerInstructions = @[layerInstruction1];//, layerInstruction3, layerInstruction4, layerInstruction5];

    AVMutableVideoCompositionInstruction *instruction2 = [AVMutableVideoCompositionInstruction videoCompositionInstruction];
    instruction1.backgroundColor = [[UIColor clearColor] CGColor];
    instruction1.timeRange = CMTimeRangeMake(CMTimeMake(3000, 1000), CMTimeMake(5999, 1000));
    instruction1.layerInstructions = @[layerInstruction2];//, layerInstruction3, layerInstruction4, layerInstruction5];

    
    NSURL *outputFileURL = [self getURLFromFilePath:outputFilePath];
    NSString *stringOutputFileType = AVFileTypeMPEG4;
    BOOL optimizeForNetworkUse = NO;
    SDAVAssetExportSession *assetExportSession = [AVAssetExportSession exportSessionWithAsset: mutableComposition presetName: AVAssetExportPreset640x480];
    assetExportSession.outputFileType = stringOutputFileType;
    assetExportSession.outputURL = outputFileURL;
    assetExportSession.shouldOptimizeForNetworkUse = optimizeForNetworkUse;
    
    videoComposition.instructions = @[instruction1, instruction2];
    videoComposition.frameDuration = CMTimeMake(1, 30);
    videoComposition.renderSize = CGSizeMake(1280.0, 720.0);
    assetExportSession.videoComposition = videoComposition;

    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
    
    [assetExportSession exportAsynchronouslyWithCompletionHandler:^
     {
         if (assetExportSession.status == AVAssetExportSessionStatusCompleted)
         {
             NSLog(@"Video export succeeded ");
             NSLog(outputFilePath);
             resolve(@"Finished");
         }
         else if (assetExportSession.status == AVAssetExportSessionStatusCancelled)
         {
             NSLog(@"Video export cancelled");
             reject(@"cancel", @"Cancelled", @"Video export cancelled");
             
         }
         else
         {
             NSLog(@"Video export failed with error: %@: %d", assetExportSession.error.localizedDescription, assetExportSession.error);
             reject(@"failed", @"Failed", @"Video export failed");
         }
     }];
    });

}
RCT_EXPORT_METHOD(transcode3:(NSString *)inputFilePath inputFilePath2:(NSString*)inputFilePath2 outputFilePath:(NSString*)outputFilePath resolver:(RCTPromiseResolveBlock)resolve rejecter:(RCTPromiseRejectBlock)reject)
{
    NSURL *inputFileURL = [self getURLFromFilePath:inputFilePath2];
    NSURL *inputFileURL2 = [self getURLFromFilePath:inputFilePath];
    
    AVURLAsset *avAsset1 = [AVURLAsset URLAssetWithURL:inputFileURL options:@{AVURLAssetPreferPreciseDurationAndTimingKey : @YES}];
    NSArray *videoAssetTracks1 = [avAsset1 tracksWithMediaType:AVMediaTypeVideo];
    AVAssetTrack *videoAssetTrack1 = [videoAssetTracks1 objectAtIndex:0];
    
    AVURLAsset *avAsset2 = [AVURLAsset URLAssetWithURL:inputFileURL2 options:@{AVURLAssetPreferPreciseDurationAndTimingKey : @YES}];
    NSArray *videoAssetTracks2 = [avAsset2 tracksWithMediaType:AVMediaTypeVideo];
    AVAssetTrack *videoAssetTrack2 = [videoAssetTracks2 objectAtIndex:0];
    
    AVMutableComposition *mutableComposition = [AVMutableComposition composition];
    NSError *audioVideoError;
    AVMutableCompositionTrack *mutableCompositionTrack1 = [mutableComposition addMutableTrackWithMediaType:AVMediaTypeVideo preferredTrackID: kCMPersistentTrackID_Invalid];
    AVMutableCompositionTrack *mutableCompositionTrack2 = [mutableComposition addMutableTrackWithMediaType:AVMediaTypeVideo preferredTrackID: kCMPersistentTrackID_Invalid];
    
    [mutableCompositionTrack1
     insertTimeRange:CMTimeRangeMake(CMTimeMake(0, 1000), CMTimeMake(2000, 1000))
     ofTrack:videoAssetTrack1
     atTime: CMTimeMake(0, 1000)
     error: &audioVideoError];
    if (audioVideoError) {
        NSLog(@"!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!! Error - %@", audioVideoError.debugDescription);
    }

    [mutableCompositionTrack1
     insertTimeRange:CMTimeRangeMake(CMTimeMake(2000, 1000), CMTimeMake(3000, 1000)) // one second
     ofTrack:videoAssetTrack1
     atTime: CMTimeMake(2000, 1000)
     error: &audioVideoError];
    if (audioVideoError) {
        NSLog(@"!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!! Error - %@", audioVideoError.debugDescription);
    }
    
    [mutableCompositionTrack2
     insertTimeRange:CMTimeRangeMake(CMTimeMake(0, 1000), CMTimeMake(1000, 1000)) // one second
     ofTrack:videoAssetTrack2
     atTime: CMTimeMake(2000, 1000)
     error: &audioVideoError];
    
    if (audioVideoError) {
        NSLog(@"!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!! Error - %@", audioVideoError.debugDescription);
    }

    [mutableCompositionTrack1
     insertTimeRange:CMTimeRangeMake(CMTimeMake(1000, 1000), CMTimeMake(3000, 1000)) // 2 seconds
     ofTrack:videoAssetTrack2
     atTime: CMTimeMake(3000, 1000)
     error: &audioVideoError];
    if (audioVideoError) {
        NSLog(@"!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!! Error - %@", audioVideoError.debugDescription);
    }
    
    CMTime end = CMTimeMake(5000, 1000);
    
    AVMutableVideoComposition *videoComposition = [AVMutableVideoComposition videoCompositionWithPropertiesOfAsset:mutableComposition];
    AVMutableVideoCompositionLayerInstruction *layerInstruction1;
    AVMutableVideoCompositionLayerInstruction *layerInstruction2;
    
     int layerInstructionIndex = 1;
    NSMutableArray * instructions = [NSArray array];
    for (AVMutableVideoCompositionInstruction *vci in videoComposition.instructions) {
        if (vci.layerInstructions.count == 2) {
            layerInstruction1 = vci.layerInstructions[1 - layerInstructionIndex];
            layerInstruction2 = vci.layerInstructions[layerInstructionIndex];
            layerInstructionIndex = layerInstructionIndex == 1 ? 0 : 1;
        }
    }
    
    [layerInstruction1 setOpacityRampFromStartOpacity: 1.0 toEndOpacity: 0.0 timeRange:CMTimeRangeMake(CMTimeMake(2000, 1000), CMTimeMake(2999, 1000))];
    
    NSURL *outputFileURL = [self getURLFromFilePath:outputFilePath];
    NSString *stringOutputFileType = AVFileTypeMPEG4;
    BOOL optimizeForNetworkUse = NO;
    AVAssetExportSession *assetExportSession = [AVAssetExportSession exportSessionWithAsset: mutableComposition presetName: AVAssetExportPreset640x480];
    assetExportSession.outputFileType = stringOutputFileType;
    assetExportSession.outputURL = outputFileURL;
    assetExportSession.shouldOptimizeForNetworkUse = optimizeForNetworkUse;
    assetExportSession.timeRange = CMTimeRangeMake(CMTimeMake(0, 1000), CMTimeMake(5000, 1000));
    

    videoComposition.frameDuration = CMTimeMake(1, 30);
    videoComposition.renderSize = CGSizeMake(640.0, 480.0);
    assetExportSession.videoComposition = videoComposition;
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        
        [assetExportSession exportAsynchronouslyWithCompletionHandler:^
         {
             if (assetExportSession.status == AVAssetExportSessionStatusCompleted)
             {
                 NSLog(@"Video export succeeded ");
                 NSLog(@"Created %@", outputFilePath);
                 resolve(@"Finished");
             }
             else if (assetExportSession.status == AVAssetExportSessionStatusCancelled)
             {
                 NSLog(@"Video export cancelled");
                 reject(@"cancel", @"Cancelled", @"Cancelled");
                 
             }
             else
             {
                 NSLog(@"Video export failed with error: %@: %ld", assetExportSession.error.localizedDescription, assetExportSession.error.code);
                 reject(@"failed", @"Failed", assetExportSession.error.localizedDescription);
             }
         }];
    });
    
}

RCT_EXPORT_METHOD(transcode:(NSString *)inputFilePath outputFilePath:(NSString*)outputFilePath width:(float)width height:(float)height resolver:(RCTPromiseResolveBlock)resolve rejecter:(RCTPromiseRejectBlock)reject)
{
    NSURL *inputFileURL = [self getURLFromFilePath:inputFilePath];
    NSURL *outputFileURL = [self getURLFromFilePath:outputFilePath];
    enum CDVOutputFileType outputFileType = MPEG4;
    BOOL optimizeForNetworkUse = NO;
    BOOL saveToPhotoAlbum =  NO;
    //float videoDuration = [[options objectForKey:@"duration"] floatValue];
    BOOL maintainAspectRatio = YES;
    int videoBitrate = 1000000; // default to 1 megabit
    int audioChannels =  2;
    int audioSampleRate =  44100;
    int audioBitrate = 128000; // default to 128 kilobits
    
    
    NSString *stringOutputFileType = AVFileTypeMPEG4;

    AVURLAsset *avAsset = [AVURLAsset URLAssetWithURL:inputFileURL options:nil];
    
    NSArray *tracks = [avAsset tracksWithMediaType:AVMediaTypeVideo];
    AVAssetTrack *track = [tracks objectAtIndex:0];
    CGSize mediaSize = track.naturalSize;
    
    float videoWidth = mediaSize.width;
    float videoHeight = mediaSize.height;
    int newWidth;
    int newHeight;
    
    if (maintainAspectRatio) {
        float aspectRatio = videoWidth / videoHeight;
        
        // for some portrait videos ios gives the wrong width and height, this fixes that
        NSString *videoOrientation = [self getOrientationForTrack:avAsset];
        if ([videoOrientation isEqual: @"portrait"]) {
            if (videoWidth > videoHeight) {
                videoWidth = mediaSize.height;
                videoHeight = mediaSize.width;
                aspectRatio = videoWidth / videoHeight;
            }
        }
        
        newWidth = (width && height) ? height * aspectRatio : videoWidth;
        newHeight = (width && height) ? newWidth / aspectRatio : videoHeight;
    } else {
        newWidth = (width && height) ? width : videoWidth;
        newHeight = (width && height) ? height : videoHeight;
    }
    
    NSLog(@"input videoWidth: %f", videoWidth);
    NSLog(@"input videoHeight: %f", videoHeight);
    NSLog(@"output newWidth: %d", newWidth);
    NSLog(@"output newHeight: %d", newHeight);
    
    SDAVAssetExportSession *encoder = [SDAVAssetExportSession.alloc initWithAsset:avAsset];
    encoder.outputFileType = stringOutputFileType;
    encoder.outputURL = outputFileURL;
    encoder.shouldOptimizeForNetworkUse = optimizeForNetworkUse;
    encoder.videoSettings = @
    
    {
    AVVideoCodecKey: AVVideoCodecH264,
    AVVideoWidthKey: [NSNumber numberWithInt: newWidth],
    AVVideoHeightKey: [NSNumber numberWithInt: newHeight],
    AVVideoCompressionPropertiesKey: @
        {
        AVVideoAverageBitRateKey: [NSNumber numberWithInt: videoBitrate],
        AVVideoProfileLevelKey: AVVideoProfileLevelH264High40
        }
    };
    encoder.audioSettings = @
    {
    AVFormatIDKey: @(kAudioFormatMPEG4AAC),
    AVNumberOfChannelsKey: [NSNumber numberWithInt: audioChannels],
    AVSampleRateKey: [NSNumber numberWithInt: audioSampleRate],
    AVEncoderBitRateKey: [NSNumber numberWithInt: audioBitrate]
    };
    
    /* // setting timeRange is not possible due to a bug with SDAVAssetExportSession (https://github.com/rs/SDAVAssetExportSession/issues/28)
     if (videoDuration) {
     int32_t preferredTimeScale = 600;
     CMTime startTime = CMTimeMakeWithSeconds(0, preferredTimeScale);
     CMTime stopTime = CMTimeMakeWithSeconds(videoDuration, preferredTimeScale);
     CMTimeRange exportTimeRange = CMTimeRangeFromTimeToTime(startTime, stopTime);
     encoder.timeRange = exportTimeRange;
     }
     */
   
      dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        
        [encoder exportAsynchronouslyWithCompletionHandler:^
        {
            if (encoder.status == AVAssetExportSessionStatusCompleted)
            {
                NSLog(@"Video export succeeded");
                resolve(@"Finished");
            }
            else if (encoder.status == AVAssetExportSessionStatusCancelled)
            {
                NSLog(@"Video export cancelled");
                reject(@"cancel", @"Cancelled", @"Video export cancelled");

            }
            else
            {
                NSLog(@"Video export failed with error: %@ (%d)", encoder.error.localizedDescription, encoder.error.code);
                reject(@"failed", @"Failed", @"Video export failed");
            }
        }];
    });


}

// inspired by http://stackoverflow.com/a/6046421/1673842
- (NSString*)getOrientationForTrack:(AVAsset *)asset
{
    AVAssetTrack *videoTrack = [[asset tracksWithMediaType:AVMediaTypeVideo] objectAtIndex:0];
    CGSize size = [videoTrack naturalSize];
    CGAffineTransform txf = [videoTrack preferredTransform];
    
    if (size.width == txf.tx && size.height == txf.ty)
        return @"landscape";
    else if (txf.tx == 0 && txf.ty == 0)
        return @"landscape";
    else if (txf.tx == 0 && txf.ty == size.width)
        return @"portrait";
    else
        return @"portrait";
}

- (NSURL*)getURLFromFilePath:(NSString*)filePath
{
    if ([filePath containsString:@"assets-library://"]) {
        return [NSURL URLWithString:[filePath stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding]];
    } else if ([filePath containsString:@"file://"]) {
        return [NSURL URLWithString:[filePath stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding]];
    }
    
    return [NSURL fileURLWithPath:[filePath stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding]];
}

@end
