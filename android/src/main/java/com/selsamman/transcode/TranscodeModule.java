package com.selsamman.transcode;

import android.os.ParcelFileDescriptor;
import android.util.Log;

import com.facebook.react.bridge.Promise;
import com.facebook.react.bridge.ReactApplicationContext;
import com.facebook.react.bridge.ReactContextBaseJavaModule;
import com.facebook.react.bridge.ReactMethod;
import com.facebook.react.bridge.ReadableMap;
import com.facebook.react.modules.core.ExceptionsManagerModule;

import net.ypresto.androidtranscoder.*;
import net.ypresto.androidtranscoder.engine.TimeLine;
import net.ypresto.androidtranscoder.format.MediaFormatStrategyPresets;

import java.io.File;


public class TranscodeModule extends ReactContextBaseJavaModule {
  private static final String TAG = "JUnitTranscoder";
  private TimeLine timeLine;
  private TimeLine.Segment segment;
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
  public void start() {
    timeLine = new TimeLine();
  }

  @ReactMethod
  public void asset (ReadableMap params) throws Exception {
    String assetName = params.getString("name");
    String assetFileURI = params.getString("path");
    String assetType = params.hasKey("type") ? params.getString("type") : "AudioVideo";
    ParcelFileDescriptor parcelFD = ParcelFileDescriptor.open(new File(assetFileURI), ParcelFileDescriptor.MODE_READ_ONLY);
    if (assetType.equals("Audio"))
      timeLine.addAudioOnlyChannel(assetName, parcelFD.getFileDescriptor());
    else if (assetType.equals("Video"))
      timeLine.addVideoOnlyChannel(assetName, parcelFD.getFileDescriptor());
    else
      timeLine.addChannel(assetName, parcelFD.getFileDescriptor());
  }

  @ReactMethod
  public void segment(int duration) {
    segment = timeLine.createSegment();
    segment.duration(duration);
  }

  @ReactMethod
  public void track (ReadableMap params) {
    String assetName = params.getString("asset");
    if (params.hasKey("seek"))
      segment.seek(assetName, params.getInt("seek"));
    segment.output(assetName);
  }

  @ReactMethod
  public void process(String outputFileName, final Promise promise) {
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
       (MediaTranscoder.getInstance().transcodeVideo(
              timeLine, outputFileName,
              MediaFormatStrategyPresets.createAndroid720pStrategyMono(),
              listener)
      ).get();
    } catch (Exception e) {
      promise.reject("Exception", e);
    }

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
