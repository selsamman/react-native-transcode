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

const video = require('../assets/sample.mp4');

async function testSayHello() {
    await RNFetchBlob.fs.cp(fs.asset('assets/sample.mp4'),fs.dirs.DocumentDir + 'foo.mp4')
    await RNFetchBlob.fs.stat(fs.dirs.DocumentDir + 'foo.mp4')
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
