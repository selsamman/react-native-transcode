import React from 'react';
import ReactNative from 'react-native';
import LoggingTestModule from './LoggingTestModule';
import Transcode from '../copies/Transcode';
import RNFetchBlob from 'react-native-fetch-blob'
const { fs, fetch, wrap } = RNFetchBlob

const View = ReactNative.View;
const Text = ReactNative.Text;
const StyleSheet = ReactNative.StyleSheet;
const TestModule = ReactNative.NativeModules.TestModule;
const invariant = require('fbjs/lib/invariant');
import Video from 'react-native-video';

async function testSayHello() {


    var poolCleanerInputFile = fs.dirs.DocumentDir + '/poolcleaner.mp4';
    try {RNFetchBlob.fs.unlink(poolCleanerInputFile)}catch(e){};
    await RNFetchBlob.fs.cp(fs.asset('video/poolcleaner.mp4'),poolCleanerInputFile)
    LoggingTestModule.assertEqual((await RNFetchBlob.fs.stat(poolCleanerInputFile)).size > 0, true);

    var frogsInputFile = fs.dirs.DocumentDir + '/frogs.mp4';
    try {RNFetchBlob.fs.unlink(frogsInputFile)}catch(e){};
    await RNFetchBlob.fs.cp(fs.asset('video/frogs.mp4'),frogsInputFile)
    LoggingTestModule.assertEqual((await RNFetchBlob.fs.stat(frogsInputFile)).size > 0, true);

    var outputFile = fs.dirs.DocumentDir + '/output.mp4'
    try {RNFetchBlob.fs.unlink(outputFile)}catch(e){};

    var status = await Transcode.start()

        .asset({name: "A", path: poolCleanerInputFile})
        .asset({name: "B", path: poolCleanerInputFile})
        .asset({name: "C", path: poolCleanerInputFile})
        .asset({name: "D", path: frogsInputFile, type: "Audio"})

        .segment(4000)
            .track({asset: "C"})
            .track({asset: "D"})

        .segment(1500)
            .track({asset: "A", seek: 1000})
            .track({asset: "D"})

        .segment(1500)
            .track({asset: "B", seek: 1000})
            .track({asset: "D"})

        .process(outputFile);

    LoggingTestModule.assertEqual('Finished', status);
    LoggingTestModule.assertEqual((await RNFetchBlob.fs.stat(outputFile)).size > 0, true);
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
    if (this.state.status == 'successful')
        return (
            <View style={styles.videoContainer}>
                <Video style={styles.backgroundVideo} source={{uri: fs.dirs.DocumentDir + "/output.mp4"}} />
            </View>
        );
    else
        return (
              <View style={styles.container}>
                  <Text>{this.state.status}</Text>
              </View>
        );
  }
}
var styles = StyleSheet.create({
    backgroundVideo: {
        position: 'absolute',
        top: 0,
        left: 0,
        bottom: 0,
        right: 0,
    },
    videoContainer: {
        marginTop: 40,
        margin: 15,
        height: 400
    },
    container: {
        backgroundColor: 'white',
        marginTop: 40,
        margin: 15,
    }
});
TranscodeTest.displayName = 'TranscodeTest';

module.exports = TranscodeTest;
