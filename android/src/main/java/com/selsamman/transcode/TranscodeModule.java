package com.selsamman.transcode;

import android.os.Looper;
import android.os.ParcelFileDescriptor;
import android.util.Log;

import com.facebook.react.bridge.Promise;
import com.facebook.react.bridge.ReactApplicationContext;
import com.facebook.react.bridge.ReactContextBaseJavaModule;
import com.facebook.react.bridge.ReactMethod;
import com.facebook.react.bridge.ReadableMap;
import com.facebook.react.modules.core.DeviceEventManagerModule;
import com.facebook.react.modules.core.ExceptionsManagerModule;

import net.ypresto.androidtranscoder.*;
import net.ypresto.androidtranscoder.engine.TimeLine;
import net.ypresto.androidtranscoder.format.Android16By9FormatStrategy;
import net.ypresto.androidtranscoder.format.MediaFormatStrategyPresets;

import java.io.File;
import java.util.HashMap;


public class TranscodeModule extends ReactContextBaseJavaModule {
  private static final String TAG = "TranscodeModule";
  private TimeLine timeLine;
  private TimeLine.Segment segment;
  public TranscodeModule(ReactApplicationContext reactContext) {
    super(reactContext);
  }
  private int logLevel = 4;
  private String logTags;

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
    if (logTags != null)
        timeLine = new TimeLine(logLevel, logTags);
    else
        timeLine = new TimeLine(logLevel);

  }

  @ReactMethod
  public void asset (ReadableMap params) throws Exception {
    String assetName = params.getString("name");
    String assetFileURI = params.getString("path");
    String assetType = params.hasKey("type") ? params.getString("type") : "AudioVideo";
    ParcelFileDescriptor parcelFD = ParcelFileDescriptor.open(new File(assetFileURI), ParcelFileDescriptor.MODE_READ_ONLY);
    Log.i(TAG,  "asset for TimeLine: " + assetFileURI + " " + parcelFD.getFileDescriptor().toString());
    if (assetType.equals("Audio"))
      timeLine.addAudioOnlyChannel(assetName, parcelFD.getFileDescriptor());
    else if (assetType.equals("Video"))
      timeLine.addVideoOnlyChannel(assetName, parcelFD.getFileDescriptor());
    else
      timeLine.addChannel(assetName, parcelFD.getFileDescriptor());
  }

  @ReactMethod
  public void setLogLevel(int level) {
    logLevel = level;
  }

  @ReactMethod
  public void setLogTags(String tags) {
    logTags = tags;
  }

  @ReactMethod
  public void segment(int duration) {
    segment = timeLine.createSegment();
    if (duration > 0)
      segment.duration(duration);
  }

  @ReactMethod
  public void track (ReadableMap params) {
    String assetName = params.getString("asset");
    if (params.hasKey("seek"))
      segment.seek(assetName, params.getInt("seek"));
    if (params.hasKey("filter")) {
      if (params.getString("filter").equalsIgnoreCase("FadeIn"))
        segment.output(assetName, TimeLine.Filter.OPACITY_UP_RAMP);
      else
        segment.output(assetName, TimeLine.Filter.OPACITY_DOWN_RAMP);
    } else
      segment.output(assetName);
  }

  @ReactMethod
  public void process(String resolution, String outputFileName, final Promise promise) {
    MediaTranscoder.Listener listener = new MediaTranscoder.Listener() {
      @Override
      public void onTranscodeProgress(double progress) {
        Log.d(TAG, "Progress " + progress);
        getReactApplicationContext().getJSModule(DeviceEventManagerModule.RCTDeviceEventEmitter.class)
                .emit("Progress", progress);

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
       MediaTranscoder.getInstance().transcodeVideo(
              timeLine, outputFileName,
              resolution.equals("high")?
                      MediaFormatStrategyPresets.createAndroid16x9Strategy1080P(Android16By9FormatStrategy.AUDIO_BITRATE_AS_IS, Android16By9FormatStrategy.AUDIO_CHANNELS_AS_IS) :
                      MediaFormatStrategyPresets.createAndroid16x9Strategy720P(Android16By9FormatStrategy.AUDIO_BITRATE_AS_IS, 1),
              listener);
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
              MediaFormatStrategyPresets.createAndroid16x9Strategy720P(Android16By9FormatStrategy.AUDIO_BITRATE_AS_IS, Android16By9FormatStrategy.AUDIO_CHANNELS_AS_IS),
              listener)
      ).get();
    } catch (Exception e) {
      promise.reject("Exception", e);
    }

  }

}
