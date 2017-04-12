package com.selsamman.transcode;

import com.facebook.react.uimanager.SimpleViewManager;
import com.facebook.react.uimanager.ThemedReactContext;

public class TranscodeViewManager extends SimpleViewManager<TranscodeView> {

  @Override
  public String getName() {
    return "TranscodeView";
  }

  @Override
  protected TranscodeView createViewInstance(ThemedReactContext reactContext) {
    return new TranscodeView(reactContext);
  }
}
