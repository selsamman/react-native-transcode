#import "Transcode.h"
#import "SDAVAssetExportSession.h"

static inline CGFloat RadiansToDegrees(CGFloat radians) {
    return radians * 180 / M_PI;
};
static inline NSMutableDictionary * findSegment(NSArray * segments, CMPersistentTrackID trackID) {
    for (int i = 0; i < segments.count; ++i)
        if ([[segments[i] valueForKey: @"trackID"] integerValue] == trackID)
            return segments[i];
    return nil;
}

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
NSInteger NO_DURATION = 999999999;

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
    NSInteger adjustedDuration = duration;
    if (!(adjustedDuration > 0))
        adjustedDuration = NO_DURATION;
    currentSegment = [NSMutableDictionary dictionaryWithDictionary: @{@"duration": [NSNumber numberWithInteger: adjustedDuration], @"tracks":[NSMutableArray array]}];
    [segments addObject: currentSegment];
}

RCT_EXPORT_METHOD(track:(NSDictionary *) inputParameters) {
    NSMutableDictionary *parameters = [inputParameters mutableCopy];
    if ([parameters valueForKey: @"seek"] == nil)
        [parameters setObject:[NSNumber numberWithInteger: 0] forKey: @"seek"];
    NSMutableArray * tracks = [currentSegment valueForKey:@"tracks"];
    [tracks addObject:parameters];
}

RCT_EXPORT_METHOD(setLogLevel:(NSInteger) level) {}
RCT_EXPORT_METHOD(setLogTags:(NSString*) tags) {}

RCT_EXPORT_METHOD(process:(NSString*)resolution outputFilePath:(NSString*)outputFilePath resolver:(RCTPromiseResolveBlock)resolve rejecter:(RCTPromiseRejectBlock)reject) {
    
    NSError *audioVideoError;
    AVMutableComposition *composition = [AVMutableComposition composition];
    
    AVMutableCompositionTrack *mutableCompositionTrack1 = [composition addMutableTrackWithMediaType:AVMediaTypeVideo preferredTrackID: kCMPersistentTrackID_Invalid];
    
    AVMutableAudioMix *mix = [AVMutableAudioMix audioMix];
    AVMutableAudioMixInputParameters *audioParams = [AVMutableAudioMixInputParameters audioMixInputParameters];
    
    CMTime outputPosition = CMTimeMake(0, 1000);
    
    NSMutableArray *audioTracks = [NSMutableArray array];
    NSMutableArray *videoTracks = [NSMutableArray array];
    NSMutableArray *instructionSegments = [NSMutableArray array];
    
    [videoTracks addObject:mutableCompositionTrack1];
    
    AVAssetTrack *firstAssetTrack;
    int videoTrackIndex = 0;
    int audioTrackIndex = 0;

    // Loop through each segment
    for (NSUInteger segmentIndex = 0; segmentIndex < [segments count]; segmentIndex++) {
        
        NSMutableDictionary *currentSegment = segments[segmentIndex];
        CMTime segmentDuration = CMTimeMake([[currentSegment valueForKey: @"duration"] integerValue], 1000);
        CMTime trackDuration; // Will be calaculated for each track
        
        NSArray * segmentTracks = [currentSegment valueForKey:@"tracks"];
        
        NSLog(@"Adding Segment %tx", segmentIndex);
        
         //videoTrackIndex = 0;
         //audioTrackIndex = 0;
        
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
            
            // Start time is the seek requested plus the current position in the track
             CMTime trackStartTime = CMTimeMake([[currentTrack valueForKey:@"seek"] longValue] + [[asset valueForKey:@"position"] longValue], 1000);

            // The duration of the track (input) will be either what is specified for the track,
            // what is specified for the segement or if nothing else the remaingin time according to
            // the legnth of the track.
            Boolean scaleTime = false;
            if ([currentTrack valueForKey: @"duration"] != nil) {
                scaleTime = true;
                trackDuration = CMTimeMake([[currentTrack valueForKey: @"duration"] integerValue], 1000);
            } else
                trackDuration = CMTimeMake([[currentSegment valueForKey: @"duration"] integerValue], 1000);
            if (trackDuration.value == NO_DURATION)
                trackDuration = CMTimeSubtract([avAsset duration], trackStartTime);
            CMTimeRange trackTimeRange = CMTimeRangeMake(trackStartTime, trackDuration);
   
            // Segment duration may also be the lenght of the track remaining if not specified
            if (segmentDuration.value == NO_DURATION)
                segmentDuration = CMTimeSubtract([avAsset duration], trackStartTime);
    
            // Upadate the position in the track based on the duration
            [asset setObject:[NSNumber numberWithLongLong: trackStartTime.value + trackDuration.value] forKey:@"position"];
            
            // Insert video track segment
            if (segmentDuration.value > 0 &&
                ([trackType isEqualToString: @"Video"] || [trackType isEqualToString:@"AudioVideo"])) {
                
                // Determine video track to use.  We only need multiple tracks to create multiple layers for transition effects
                // however we need to force separate instructions and the composition login in IOS will consolidate adjacant
                // segments on the same track so we try to put each consectutive segment on a new track
                AVMutableCompositionTrack *videoTrack;
                //if (videoTrackIndex > 3)
                //    videoTrackIndex = 0;
                if (videoTrackIndex >= [videoTracks count]) {
                    videoTrack = [composition addMutableTrackWithMediaType:AVMediaTypeVideo preferredTrackID: kCMPersistentTrackID_Invalid];
                    [videoTracks addObject: videoTrack];
                    CGAffineTransform transform = assetTrack.preferredTransform;
                    videoTrack.preferredTransform = transform;
                } else
                    videoTrack = videoTracks[videoTrackIndex];


                // Add the input asset to the video track
                [videoTrack
                 insertTimeRange:trackTimeRange
                 ofTrack:[asset valueForKey: @"videoTrack"]
                 atTime: outputPosition error: &audioVideoError];
                
                NSLog(@"Adding video to track %i at %lli track time %lli for %lli", videoTrack.trackID, outputPosition.value, trackTimeRange.start.value, trackTimeRange.duration.value);
 
                // If the input and ouput are different scale the time
                if (scaleTime) {
                    CMTimeRange outputRange = CMTimeRangeMake(outputPosition, trackTimeRange.duration);
                    [videoTrack scaleTimeRange:outputRange toDuration:segmentDuration];
                    NSLog(@"Scaling time track time %lli for %lli to %lli", outputRange.start.value, outputRange.duration.value, segmentDuration.value);
                }
                [currentTrack setObject: [NSNumber numberWithInteger: videoTrack.trackID] forKey: @"trackID"];

                if (audioVideoError) {
                    reject(@"ERROR", [[audioVideoError localizedDescription] stringByAppendingString:@" Adding Video Segment"], audioVideoError);

                    return;
                }
                
                // Record the filter so we can match up later when we get the layer instructions
                if ([filter isEqualToString: @"FadeOut"]) {
                    [currentSegment setObject:[NSNumber numberWithInt:videoTrack.trackID]  forKey: @"fadeOutTrackID"];
                }
                
                ++videoTrackIndex;
            }
            
            // Insert audio track segment
            if (segmentDuration.value > 0 && ![filter isEqualToString: @"Mute"] && !scaleTime &&
                ([trackType isEqualToString: @"Audio"] || [trackType isEqualToString:@"AudioVideo"])) {
                
                // Same approach as video for audio tracks
                AVMutableCompositionTrack *audioTrack;
                //if (audioTrackIndex > 3)
                //    audioTrackIndex = 0;
                if (audioTrackIndex >= [audioTracks count]) {
                    audioTrack = [composition addMutableTrackWithMediaType:AVMediaTypeAudio preferredTrackID: kCMPersistentTrackID_Invalid];
                [audioTracks addObject: audioTrack];
                } else
                    audioTrack = audioTracks[audioTrackIndex];

                // Add audio asset to the track
                [audioTrack
                 insertTimeRange:trackTimeRange
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
        CMTimeRange outputTimeRange = CMTimeRangeMake(outputPosition, segmentDuration);
        NSNumber *duration = [NSNumber numberWithLongLong: outputTimeRange.duration.value];
        NSNumber *start = [NSNumber numberWithLongLong: outputTimeRange.start.value];
        [currentSegment setObject: duration forKey:@"duration"];
        [currentSegment setObject: start forKey:@"start"];
        outputPosition = CMTimeAdd(outputPosition, outputTimeRange.duration);
        
        // Keep cross reference of segments to instructions for later processin
        [instructionSegments addObject:currentSegment];

    }
    
    // Creating the videoComposition from the composition ensures that we have default intructions and layerInstructions
    AVMutableVideoComposition *videoComposition = [AVMutableVideoComposition videoCompositionWithPropertiesOfAsset:composition];
    
    
    float trackFrameRate = [firstAssetTrack nominalFrameRate];
    
    if (trackFrameRate == 0)
    {
        trackFrameRate = 30;
    }
    
    // Determine render size
    videoComposition.frameDuration = CMTimeMake(1, trackFrameRate);
    CGSize targetSize = [resolution isEqualToString: @"high"] ? CGSizeMake(1920.0,1080.0) : CGSizeMake(1280.0, 720.0);
    //CGSize originalSize = [firstAssetTrack naturalSize];
    CGAffineTransform transform = firstAssetTrack.preferredTransform;
    CGFloat targetVideoAngle  = atan2(transform.b, transform.a) * 180 / M_PI;
    if (targetVideoAngle == 90 || targetVideoAngle == -90) {
        CGFloat width = targetSize.width;
        targetSize.width = targetSize.height;
        targetSize.height = width;
    }
    videoComposition.renderSize = targetSize;
    NSLog(@"Target Size %f x %f", targetSize.width, targetSize.height);
    
    
    // Look at all instructions
    int layeredSegementsIndex = 0;
    for (AVMutableVideoCompositionInstruction *compositionInstruction in videoComposition.instructions) {
        
        NSLog(@"composition instruction %i starting at %lli for %lli", layeredSegementsIndex, [compositionInstruction timeRange].start.value, [compositionInstruction timeRange].duration.value );
        
        if (layeredSegementsIndex >= instructionSegments.count) {
            NSLog(@"Warning: composition has extra instruction that are being ignored");
            continue;
        }
        
        // Retrieve the segment
        NSDictionary * segment = instructionSegments[layeredSegementsIndex];
        long start = [(NSNumber *)[segment valueForKey:@"start"] longValue];
        long duration = [(NSNumber *)[segment valueForKey:@"duration"] longValue];
        CMTimeRange transitionRange = CMTimeRangeMake(CMTimeMake(start, 1000), CMTimeMake(duration, 1000));
        
        // Those that have two layersInstructions relate to overlapping segments in the two tracks
        if (compositionInstruction.layerInstructions.count > 0) {
            
            AVMutableVideoCompositionLayerInstruction * layerInstruction1 = compositionInstruction.layerInstructions[0];
            
            // If we have multiple we need to fade out one of the layers
            if (compositionInstruction.layerInstructions.count == 2) {
                
                // Determine which layerInstruction to be used for fadeout
                AVMutableVideoCompositionLayerInstruction * layerInstruction2 = compositionInstruction.layerInstructions[1];
                if ([segment valueForKey:@"fadeOutTrackID"] != nil) {
                    int fadeOutTrackID = [[segment valueForKey:@"fadeOutTrackID"] intValue];
                    AVMutableVideoCompositionLayerInstruction * transitionLayerInstruction =
                    layerInstruction1.trackID == fadeOutTrackID ? layerInstruction1 : layerInstruction2;
                    NSLog(@"fadeOutTrackId %i", fadeOutTrackID);
                    
                    // Add the opacity ramp for the entire time range of the segment
                    [transitionLayerInstruction setOpacityRampFromStartOpacity: 1.0 toEndOpacity:0.0 timeRange: transitionRange];
                }
            }
            ++layeredSegementsIndex;
        }

        for (AVMutableVideoCompositionLayerInstruction * layerInstruction in compositionInstruction.layerInstructions) {
            CMPersistentTrackID trackID = layerInstruction.trackID;
            
            CMTimeRange ir;
            [layerInstruction getTransformRampForTime:transitionRange.start startTransform:NULL endTransform:NULL timeRange:&ir];
            NSLog(@"layerInstruction for trackId %i at %lld for %lld", layerInstruction.trackID,ir.start.value,ir.duration.value);

            NSArray * segmentTracks = [segment valueForKey:@"tracks"];

            NSMutableDictionary *currentTrack = findSegment(segmentTracks, trackID);
            if (currentTrack == nil) {
                NSLog(@"Warning: Cannot find segment track for instruction %i - layer ignored", layeredSegementsIndex);
                continue;

            }
            NSString *assetName = [currentTrack valueForKey:@"asset"];
            NSMutableDictionary *asset = [files valueForKey:assetName];
            AVAssetTrack *assetTrack = [asset valueForKey: @"videoTrack"];
            CGAffineTransform transform = assetTrack.preferredTransform;
            UIInterfaceOrientation orientation = UIInterfaceOrientationPortrait;
            
            // Determine orientation
            
            // Portrait
            if(transform.a == 0 && transform.b == 1.0 && transform.c == -1.0 && transform.d == 0) {
                orientation = UIInterfaceOrientationPortrait;
            }
            // PortraitUpsideDown
            if(transform.a == 0 && transform.b == -1.0 && transform.c == 1.0 && transform.d == 0) {
                orientation = UIInterfaceOrientationPortraitUpsideDown;
            }
            // LandscapeRight
            if(transform.a == 1.0 && transform.b == 0 && transform.c == 0 && transform.d == 1.0) {
                orientation = UIInterfaceOrientationLandscapeRight;
            }
            // LandscapeLeft
            if(transform.a == -1.0 && transform.b == 0 && transform.c == 0 && transform.d == -1.0) {
                orientation = UIInterfaceOrientationLandscapeLeft;
            }
            
            // Create a preferred transform
            CGSize originalSize = [assetTrack naturalSize];
            CGAffineTransform finalTransform;
            switch (orientation) {
                case UIInterfaceOrientationLandscapeLeft:
                    finalTransform = CGAffineTransformMake(-1, 0, 0, -1, originalSize.width, originalSize.height);
                    break;
                case UIInterfaceOrientationLandscapeRight:
                    finalTransform = CGAffineTransformMake(1, 0, 0, 1, 0, 0);
                    break;
                case UIInterfaceOrientationPortrait:
                    finalTransform = CGAffineTransformMake(0, 1, -1, 0, originalSize.height, 0);
                    break;
                case UIInterfaceOrientationPortraitUpsideDown:
                    finalTransform = CGAffineTransformMake(0, -1, 1, 0, 0, originalSize.width);
                    break;
                default:
                    break;
            }
            
            if (orientation == UIInterfaceOrientationPortrait || orientation == UIInterfaceOrientationPortraitUpsideDown) {
                CGFloat width = originalSize.width;
                originalSize.width = originalSize.height;
                originalSize.height = width;
            }
            
            // center original inside target
            float ratio = MIN(targetSize.width / originalSize.width, targetSize.height / originalSize.height);
            float transx = (targetSize.width - originalSize.width * ratio) / 2;
            float transy = (targetSize.height - originalSize.height * ratio) / 2;
            CGAffineTransform matrix = CGAffineTransformMakeTranslation(transx, transy);
            matrix = CGAffineTransformScale(matrix, ratio, ratio);
            finalTransform = CGAffineTransformConcat(finalTransform, matrix);
  
            NSLog(@"setTransform");
            [layerInstruction setTransform: finalTransform atTime:transitionRange.start];
            
        }
    }
    
    videoComposition.frameDuration = CMTimeMake(1, 30);
    
    int audioChannels =  2;
    int audioSampleRate =  44100;
    int audioBitrate = 128000; // default to 128 kilobits
    
    
    assetExportSession = [SDAVAssetExportSession.alloc initWithAsset:composition];
    assetExportSession.outputFileType = AVFileTypeMPEG4;
    assetExportSession.outputURL = [self getURLFromFilePath:outputFilePath];
    assetExportSession.shouldOptimizeForNetworkUse = NO;
    assetExportSession.videoSettings = @ {
    AVVideoCodecKey: AVVideoCodecH264,
    AVVideoWidthKey: [NSNumber numberWithInt: targetSize.width],
    AVVideoHeightKey: [NSNumber numberWithInt: targetSize.height],
        /*
         AVVideoCompressionPropertiesKey: @ {
         AVVideoAverageBitRateKey: [NSNumber numberWithInt: videoBitrate],
         AVVideoProfileLevelKey: AVVideoProfileLevelH264High40
         }
         */
    };
    assetExportSession.audioSettings = @ {
    AVFormatIDKey: @(kAudioFormatMPEG4AAC),
    AVNumberOfChannelsKey: [NSNumber numberWithInt: audioChannels],
    AVSampleRateKey: [NSNumber numberWithInt: audioSampleRate],
    AVEncoderBitRateKey: [NSNumber numberWithInt: audioBitrate]
    };
    
    /*
     // Keep this in case we ditch SDAVAssetExportSession
     
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
                 NSLog(@"Video export failed with error: %@: %ld", assetExportSession.error.localizedDescription, (long)assetExportSession.error.code);;
                 reject(@"failed", @"Failed", @"Video export failed");
             }
         }];
    });
    
    
}
- (void)updateExportDisplay {
    if (progress != nil)
        [progress sendNotification:@(assetExportSession.progress)];
    
}
/*
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
*/
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
