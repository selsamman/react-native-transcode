#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>
#import <AssetsLibrary/ALAssetsLibrary.h>
#import <MediaPlayer/MediaPlayer.h>
#import <React/RCTBridgeModule.h>
#import <React/RCTEventEmitter.h>
enum CDVOutputFileType {
    M4V = 0,
    MPEG4 = 1,
    M4A = 2,
    QUICK_TIME = 3
};

/*

Transcode.startTranscodeDefinititon() 
// Creates the asset composition: AVMutableComposition with an audio and video track using AVCompositionTrack
// Creates the instruction composition: AVMutableAudioComposition and AVMutableVideoComposition
// Create an AVMutableAudioMix object

Transcode.asset("movie1", fd1)
Transcode.asset("movie2", fd2)
Transcode.asset("movie3", fd2)
Transcode.asset("soundtrack", fd3)
// Create AVAssets for each of these and adds them to an NSDictionary
 
Transcode.segment(6000)
    Transcode.track({asset: "movie1"})
    Transcode.track({asset: "soundtrack", type: Transcode.Audio})
// Creates audio and video AVMutableCompositionTrackSegments for "movie1" and and an audio one for "soundtrack"
 
Transcode.segment(2000)
    Transcode.track({asset: "movie1", effect: Transcode.fadeOut})
    Transcode.track({asset: "movie2", seek: 1000, effect Transcode.fadeIn})
    Transcode.track("soundtrack", {type: Transcode.Audio})
// Extends the end time for the "movie1" and "soundtrack" segments
// Creates audio and video AVMutableCompositionTrackSegments for "movie2"
// Creates AVMutableVideoCompositionInstruction and associates a AVVideoCompositionLayerInstruction for both movie1 & movie2
// the layer instructions have opacity ramps in either direction.  
// Create AVMutableAudioMixInputParameters for each of movie1 and movie2 with audio ramps
 
Transcode.segment()
    Transcode.track({asset: "movie2"})
    Transcode.track({asset: "soundtrack", {type: Transcode.Audio})
 // Extends the end time for the "movie1" and "soundtrack" segments

var status = await Transcode.process(progressCallBack);

 */





@interface Transcode : NSObject <RCTBridgeModule>
+ (NSString*)sayHello;
+ (void)transcode2;
+ (void)transcode3;
+ (void)transcodeVideo;
+ (void)asset;
+ (void)segment;
+ (void)track;
+ (void)start;
@end

@interface TranscodeProgress : RCTEventEmitter <RCTBridgeModule>

@end
