import React from 'react';
import ReactNative from 'react-native';

const TranscodeModule = ReactNative.NativeModules.Transcode;
const TranscodeView = ReactNative.requireNativeComponent('TranscodeView', null);

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

  static process (resolution, outputFile) {
    return TranscodeModule.process(resolution, outputFile)
  }

  render() {
    return <TranscodeView style={this.props.style} />;
  }

  static startTimeLine () {
  }


}
