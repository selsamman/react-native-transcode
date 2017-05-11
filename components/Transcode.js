import React from 'react';
import { NativeModules, NativeEventEmitter} from 'react-native'
const TranscodeModule = NativeModules.Transcode;
const TranscodeProgress = NativeModules.TranscodeProgress;

export default class Transcode extends React.Component {

  static propTypes = {
    style: React.PropTypes.any,
  };

  static async sayHello() {
    return await TranscodeModule.sayHello();
  }

  static async transcode(inFilePath, outFilePath, width, height) {
    return TranscodeModule.transcode(inFilePath, outFilePath, width, height);
  }

  static async transcode2(inFilePath, outFilePath) {
    return TranscodeModule.transcode2(inFilePath, outFilePath);
  }

  static async transcode3(inFilePath, inFilePath2, outFilePath) {
    return TranscodeModule.transcode3(inFilePath, inFilePath2, outFilePath);
  }

  static segment(time) {
    TranscodeModule.segment(time || 999999999);
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
            console.log('progress callback ');
            progress(reminder.progress)
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
