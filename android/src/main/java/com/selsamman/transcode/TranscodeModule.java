package com.selsamman.transcode;

import android.os.ParcelFileDescriptor;
import android.util.Log;

import com.facebook.react.bridge.Promise;
import com.facebook.react.bridge.ReactApplicationContext;
import com.facebook.react.bridge.ReactContextBaseJavaModule;
import com.facebook.react.bridge.ReactMethod;
import com.facebook.react.modules.core.ExceptionsManagerModule;

import net.ypresto.androidtranscoder.*;
import net.ypresto.androidtranscoder.engine.TimeLine;
import net.ypresto.androidtranscoder.format.MediaFormatStrategyPresets;

import java.io.File;


public class TranscodeModule extends ReactContextBaseJavaModule {
  private static final String TAG = "JUnitTranscoder";

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

  @ReactMethod
  public void transcode(String inputFileName1, String outputFileName, int width, int height, final Promise promise) {
    MediaTranscoder.Listener listener = new MediaTranscoder.Listener() {
      @Override
      public void onTranscodeProgress(double progress) {
        Log.d(TAG, "Progress " + progress);
      }
      @Override
      public void onTranscodeCompleted() {
        promise.resolve("Finished");
      }
      @Override
      public void onTranscodeCanceled() {

        promise.resolve("Cancelled");
      }
      @Override
      public void onTranscodeFailed(Exception e) {
        promise.reject("Exception", e);
      }
    };

    try {
      ParcelFileDescriptor in1 = ParcelFileDescriptor.open(new File(inputFileName1), ParcelFileDescriptor.MODE_READ_ONLY);

      TimeLine timeline = new TimeLine()
              .addChannel("A", in1.getFileDescriptor())
              .createSegment()
                .output("A")
              .timeLine();
      (MediaTranscoder.getInstance().transcodeVideo(
              timeline, outputFileName,
              MediaFormatStrategyPresets.createAndroid720pStrategyMono(),
              listener)
      ).get();
    } catch (Exception e) {
      promise.reject("Exception", e);
    }

  }

}
