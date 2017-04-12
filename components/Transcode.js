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

  render() {
    return <TranscodeView style={this.props.style} />;
  }
}
