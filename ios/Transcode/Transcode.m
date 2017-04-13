#import "Transcode.h"
#import "SDAVAssetExportSession.h"

@implementation Transcode

+ (NSString*)sayHello {
  return @"Native hello world!";
}

RCT_EXPORT_MODULE()

RCT_EXPORT_METHOD(sayHello:(RCTPromiseResolveBlock)resolve rejecter:(RCTPromiseRejectBlock)reject) {
  resolve([Transcode sayHello]);
}

RCT_EXPORT_METHOD(transcode:(NSString *)inputFilePath videoFileName:(float)videoFileName width:(float)width height:(float)height resolver:(RCTPromiseResolveBlock)resolve rejecter:(RCTPromiseRejectBlock)reject)
{
    NSURL *inputFileURL = [self getURLFromFilePath:inputFilePath];
    enum CDVOutputFileType outputFileType = MPEG4;
    BOOL optimizeForNetworkUse = NO;
    BOOL saveToPhotoAlbum =  YES;
    //float videoDuration = [[options objectForKey:@"duration"] floatValue];
    BOOL maintainAspectRatio = YES;
    int videoBitrate = 1000000; // default to 1 megabit
    int audioChannels =  2;
    int audioSampleRate =  44100;
    int audioBitrate = 128000; // default to 128 kilobits
    
    NSString *stringOutputFileType = Nil;
    NSString *outputExtension = Nil;
    
    switch (outputFileType) {
        case QUICK_TIME:
            stringOutputFileType = AVFileTypeQuickTimeMovie;
            outputExtension = @".mov";
            break;
        case M4A:
            stringOutputFileType = AVFileTypeAppleM4A;
            outputExtension = @".m4a";
            break;
        case M4V:
            stringOutputFileType = AVFileTypeAppleM4V;
            outputExtension = @".m4v";
            break;
        case MPEG4:
        default:
            stringOutputFileType = AVFileTypeMPEG4;
            outputExtension = @".mp4";
            break;
    }
 
    // check if the video can be saved to photo album before going further
    if (saveToPhotoAlbum && !UIVideoAtPathIsCompatibleWithSavedPhotosAlbum([inputFileURL path]))
    {
        NSString *error = @"Video cannot be saved to photo album";
        reject(@"cant_save", @"Cannot Save to Photo Album", error);
        return;
    }

    AVURLAsset *avAsset = [AVURLAsset URLAssetWithURL:inputFileURL options:nil];
    
    NSString *cacheDir = [NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES) objectAtIndex:0];
    NSString *outputPath = [NSString stringWithFormat:@"%@/%@%@", cacheDir, videoFileName, outputExtension];
    NSURL *outputURL = [NSURL fileURLWithPath:outputPath];
    
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
    encoder.outputURL = outputURL;
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
