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

  static segment(time) {
    TranscodeModule.segment(time || 999999999);
    return this;
  }

  static asset(key, file) {
    TranscodeModule.asset(key, file);
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

  static process (outputFile) {
    return TranscodeModule.process(outputFile)
  }

  render() {
    return <TranscodeView style={this.props.style} />;
  }

  static startTimeLine () {
  }


}
