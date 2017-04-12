#import "Transcode.h"

@implementation Transcode

+ (NSString*)sayHello {
  return @"Native hello world!";
}

RCT_EXPORT_MODULE()

RCT_EXPORT_METHOD(sayHello:(RCTPromiseResolveBlock)resolve rejecter:(RCTPromiseRejectBlock)reject) {
  resolve([Transcode sayHello]);
}

@end
