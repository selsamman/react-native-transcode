import React from 'react';
import { NativeModules, NativeEventEmitter} from 'react-native'
const TranscodeModule = NativeModules.Transcode;
const TranscodeProgress = NativeModules.TranscodeProgress;

export default class Transcode extends React.Component {

  static propTypes = {
    style: React.PropTypes.any,
  };

  static async transcode(inFilePath, outFilePath, width, height) {
    return TranscodeModule.transcode(inFilePath, outFilePath, width, height);
  }

  static segment(time) {
    TranscodeModule.segment(time || 0);
    return this;
  }

  static asset(params) {
    TranscodeModule.asset(params);
    return this;
  }

  static track(params) {
    TranscodeModule.track(params);
    return this;
  }

  static setLogLevel(level) {
    TranscodeModule.setLogLevel(level);
  }

  static setLogTags(tags) {
    TranscodeModule.setLogTags(tags);
  }

  static start () {
    TranscodeModule.start()
    return this;
  }

  static async process (resolution, outputFile, progress) {
    var status;
    if (progress) {
      const transcodeProgress = new NativeEventEmitter(TranscodeProgress);
      const subscription = transcodeProgress.addListener(
          'Progress',  (reminder) => {
		    progress((typeof (reminder.progress) == 'undefined' ? reminder : reminder.progress) * 1);
          }
      );
      status = await TranscodeModule.process(resolution, outputFile);
      subscription.remove();
    } else
      status = await TranscodeModule.process(resolution, outputFile);
    return status;
  }

  static startTimeLine () {
  }


}
