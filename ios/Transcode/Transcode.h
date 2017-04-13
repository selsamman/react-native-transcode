#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>
#import <AssetsLibrary/ALAssetsLibrary.h>
#import <MediaPlayer/MediaPlayer.h>
#import "RCTBridgeModule.h"
enum CDVOutputFileType {
    M4V = 0,
    MPEG4 = 1,
    M4A = 2,
    QUICK_TIME = 3
};
@interface Transcode : NSObject <RCTBridgeModule>
+ (NSString*)sayHello;
+ (void)transcodeVideo;
@end
