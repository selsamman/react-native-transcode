package com.selsamman.transcode;

import com.facebook.react.bridge.Promise;
import com.facebook.react.bridge.ReactApplicationContext;
import com.facebook.react.bridge.ReactContextBaseJavaModule;
import com.facebook.react.bridge.ReactMethod;

public class TranscodeModule extends ReactContextBaseJavaModule {

  public TranscodeModule(ReactApplicationContext reactContext) {
    super(reactContext);
  }

  @Override
  public String getName() {
    return "Transcode";
  }

  public String sayHello() {
    return "Native hello world!";
  }

  @ReactMethod
  public void sayHello(Promise promise) {
    promise.resolve(sayHello());
  }
}
