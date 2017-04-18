import React from 'react';
import ReactNative from 'react-native';
import LoggingTestModule from './LoggingTestModule';
import Transcode from '../copies/Transcode';
import RNFetchBlob from 'react-native-fetch-blob'
const { fs, fetch, wrap } = RNFetchBlob

const View = ReactNative.View;
const Text = ReactNative.Text;
const TestModule = ReactNative.NativeModules.TestModule;
const invariant = require('fbjs/lib/invariant');


async function testSayHello() {
    try {RNFetchBlob.fs.unlink(fs.dirs.DocumentDir + '/foo.mp4')}catch(e){};
    try {RNFetchBlob.fs.unlink(fs.dirs.DocumentDir + '/bar.mp4')}catch(e){};
    await RNFetchBlob.fs.cp(fs.asset('video/sample.mp4'),fs.dirs.DocumentDir + '/foo.mp4')
    var fooStat = await RNFetchBlob.fs.stat(fs.dirs.DocumentDir + '/foo.mp4');
    const status = await Transcode.transcode(fs.dirs.DocumentDir + '/foo.mp4', fs.dirs.DocumentDir + '/bar.mp4', 1280, 720);
    LoggingTestModule.assertEqual('Finished', status);
    var barStat = await RNFetchBlob.fs.stat(fs.dirs.DocumentDir + '/bar.mp4');
    var sizeReasonable = fooStat.size > barStat.size && barStat.size > 0;
    LoggingTestModule.assertEqual(sizeReasonable, true);
    const helloMessage = await Transcode.sayHello();
    LoggingTestModule.assertEqual('Native hello world!', helloMessage);
}

class TranscodeTest extends React.Component {

  constructor(props) {
    super(props);
    this.state = {
      status: 'running',
    }
  }

  componentDidMount() {
    this.runTests();
  }

  async runTests() {
    try {
      await testSayHello();
    } catch (error) {
      LoggingTestModule.logErrorToConsole(error);
      if (TestModule) {
        TestModule.markTestPassed(false);
      }
      this.setState({ status: 'failed' });
      return;
    }
    if (TestModule) {
      TestModule.markTestPassed(true);
    }
    this.setState({ status: 'successful' });
  }

  render() {
    return <View><Text>{this.state.status}</Text></View>;
  }
}

TranscodeTest.displayName = 'TranscodeTest';

module.exports = TranscodeTest;
