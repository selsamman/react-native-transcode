#import "RCTViewManager.h"
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
