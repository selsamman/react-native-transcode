
#if __has_include(<React/RCTViewManager.h>)
#import <React/RCTViewManager.h>
#elif __has_include("React/RCTViewManager.h")
#import "React/RCTViewManager.h"
#else
#import "RCTViewManager.h"
#endif
#import "TranscodeView.h"

@interface TranscodeViewManager : RCTViewManager
@end

@implementation TranscodeViewManager

RCT_EXPORT_MODULE()

- (UIView *)view
{
  return [TranscodeView new];
}

@end
