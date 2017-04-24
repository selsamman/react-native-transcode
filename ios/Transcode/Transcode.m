#import "Transcode.h"
#import "SDAVAssetExportSession.h"

@implementation Transcode

NSMutableDictionary *files;
NSMutableArray *segments;
NSMutableDictionary *currentSegment;

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

RCT_EXPORT_METHOD(asset:(NSString *) assetName fileName:(NSString *) inputFilePath) {
    NSURL *inputFileURL = [self getURLFromFilePath:inputFilePath];
    AVURLAsset *avAsset = [AVURLAsset URLAssetWithURL:inputFileURL options:nil];
    NSArray *videoTracks = [avAsset tracksWithMediaType:AVMediaTypeVideo];
    NSArray *audioTracks = [avAsset tracksWithMediaType:AVMediaTypeAudio];
    AVAssetTrack *videoTrack = [videoTracks count] > 0 ? [videoTracks objectAtIndex:0] : @"None";
    AVAssetTrack *audioTrack = [audioTracks count] > 0 ? [audioTracks objectAtIndex:0] : @"None";
    NSMutableDictionary *asset = @{@"url":inputFileURL, @"avAsset": avAsset, @"videoTrack":videoTrack, @"audioTrack":audioTrack};
    [files setObject: asset forKey: assetName];
}

RCT_EXPORT_METHOD(segment:(NSInteger) duration) {
    currentSegment = @{@"duration": [NSNumber numberWithInteger:duration], @"tracks" : [NSMutableArray array]};
    [segments addObject: currentSegment];
}

RCT_EXPORT_METHOD(track:(NSDictionary *) inputParameters) {
    NSMutableDictionary *parameters = [inputParameters mutableCopy];
    if ([parameters valueForKey: @"seek"] == nil)
        [parameters setObject:[NSNumber numberWithInteger: 0] forKey: @"seek"];
    if ([parameters valueForKey: @"type"] == nil)
        [parameters setObject: @"AudioVideo" forKey: @"type"];
    [[currentSegment valueForKey:@"tracks"] addObject:parameters];
}

RCT_EXPORT_METHOD(process:(NSString*)outputFilePath resolver:(RCTPromiseResolveBlock)resolve rejecter:(RCTPromiseRejectBlock)reject) {

    NSError *audioVideoError;
    AVMutableComposition *composition = [AVMutableComposition composition];
    
    AVMutableAudioMix *mix = [AVMutableAudioMix audioMix];
    AVMutableAudioMixInputParameters *audioParams = [AVMutableAudioMixInputParameters audioMixInputParameters];
    
    CMTime outputPosition = CMTimeMake(0, 0);
    
    NSMutableArray *audioTracks = [NSMutableArray array];
    NSMutableArray *videoTracks = [NSMutableArray array];
    
    // Loop through each segment
    for (NSUInteger segmentIndex = 0; segmentIndex < [segments count]; segmentIndex++) {
        
        NSMutableDictionary *currentSegment = segments[segmentIndex];
        CMTime segmentDuration = CMTimeMake([[currentSegment valueForKey: @"duration"] integerValue], 1000);

        int videoTrackIndex = 0;
        int audioTrackIndex = 0;
        
        
        // Loop throught the tracks in the segment and add each track to the composition
        for (NSMutableDictionary *currentTrack in [currentSegment valueForKey:@"tracks"]) {
            
            NSString *trackType = [currentTrack valueForKey: @"type"];
            
            // Grab assets
            NSString *assetName = [currentTrack valueForKey:@"asset"];
            NSDictionary *asset = [files valueForKey:assetName];
            AVAsset *avAsset = [asset valueForKey: @"avAsset"];
            
            
            // Compute end time of segment which can't be greater than segment declared duration
            CMTime trackStartTime = CMTimeMake([[currentTrack valueForKey:@"seek"] integerValue], 1000);
            CMTime trackDuration = CMTimeSubtract([avAsset duration], trackStartTime);
            trackDuration = CMTimeMinimum(trackDuration, segmentDuration);
            CMTime trackEndTime = CMTimeAdd(trackStartTime, trackDuration);
            
            // Truncate segment duration to legnth of shortest track
            segmentDuration = CMTimeMinimum(segmentDuration, trackDuration);
            
            // Insert video track segment
            if ([trackType isEqualToString: @"Video"] || [trackType isEqualToString:@"AudioVideo"]) {
                
                AVMutableCompositionTrack *videoTrack;
                int foo = [videoTracks count];
                if (videoTrackIndex >= [videoTracks count]) {
                    videoTrack = [composition addMutableTrackWithMediaType:AVMediaTypeVideo preferredTrackID: kCMPersistentTrackID_Invalid];
                    [videoTracks addObject: videoTrack];
                } else
                    videoTrack = videoTracks[videoTrackIndex];
                
                [videoTrack
                    insertTimeRange:CMTimeRangeMake(trackStartTime, trackEndTime)
                    ofTrack:[asset valueForKey: @"videoTrack"]
                    atTime: outputPosition error: &audioVideoError];
            
                if (audioVideoError) {
                    reject(@"ERROR", [[audioVideoError localizedDescription] stringByAppendingString:@" Adding Video Segment"], audioVideoError);
                    return;
                }
                
                ++videoTrackIndex;
            }

            // Insert audio track segment
            if ([trackType isEqualToString: @"Audio"] || [trackType isEqualToString:@"AudioVideo"]) {

                AVMutableCompositionTrack *audioTrack;
                if (audioTrackIndex >= [audioTracks count]) {
                    audioTrack = [composition addMutableTrackWithMediaType:AVMediaTypeAudio preferredTrackID: kCMPersistentTrackID_Invalid];
                    [audioTracks addObject: audioTrack];
                } else
                    audioTrack = audioTracks[audioTrackIndex];
                
                [audioTrack
                 insertTimeRange:CMTimeRangeMake(trackStartTime, trackEndTime)
                 ofTrack:[asset valueForKey: @"audioTrack"]
                 atTime: outputPosition error: &audioVideoError];
                
                if (audioVideoError) {
                    reject(@"ERROR", [[audioVideoError localizedDescription] stringByAppendingString:@" Adding Audio Segment"], audioVideoError);
                    return;
                }
                
                ++audioTrackIndex;
            }
        }
        outputPosition = CMTimeAdd(outputPosition, segmentDuration);
    }

    NSURL *outputFileURL = [self getURLFromFilePath:outputFilePath];
    NSString *stringOutputFileType = AVFileTypeMPEG4;
    BOOL optimizeForNetworkUse = NO;

    AVAssetExportSession *encoder = [AVAssetExportSession exportSessionWithAsset: composition presetName: AVAssetExportPreset640x480];
    encoder.outputFileType = stringOutputFileType;
    encoder.outputURL = outputFileURL;
    encoder.shouldOptimizeForNetworkUse = optimizeForNetworkUse;

    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        
        [encoder exportAsynchronouslyWithCompletionHandler:^
         {
             if (encoder.status == AVAssetExportSessionStatusCompleted)
             {
                 NSLog(@"Video export succeeded ");
                 NSLog(outputFilePath);
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
