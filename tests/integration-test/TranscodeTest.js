import React from 'react';
import ReactNative from 'react-native';
import LoggingTestModule from './LoggingTestModule';
import Transcode from '../copies/Transcode';
import RNFetchBlob from 'react-native-fetch-blob'
const { fs, fetch, wrap } = RNFetchBlob

import {
  View,
  TouchableOpacity,
  Text,
  StyleSheet
} from 'react-native';

const TestModule = ReactNative.NativeModules.TestModule;
const invariant = require('fbjs/lib/invariant');
import Video from 'react-native-video';

async function testSayHello() {


    async function prepFile(fileName) {
        var inputFile = fs.dirs.DocumentDir + '/' + fileName;
        try {RNFetchBlob.fs.unlink(inputFile)}catch(e){};
        await RNFetchBlob.fs.cp(fs.asset('video/' + fileName),inputFile)
        LoggingTestModule.assertEqual((await RNFetchBlob.fs.stat(inputFile)).size > 0, true);
        return inputFile;
    }

    var poolCleanerInputFile = await prepFile('poolcleaner.mp4');
    var frogsInputFile = await prepFile('frogs.mp4');
    //var carInputFile = await prepFile('car.mp4');
    //var skateInputFile = await prepFile('skate.mp4');

    var outputFile = fs.dirs.DocumentDir + '/output.mp4'
    try {RNFetchBlob.fs.unlink(outputFile)}catch(e){};

/*
    var status = await Transcode.start()

        .asset({name: "A", path: poolCleanerInputFile})
        .asset({name: "B", path: poolCleanerInputFile})
        .asset({name: "C", path: poolCleanerInputFile})
        .asset({name: "D", path: frogsInputFile, type: "Audio"})

        .segment(2000)
            .track({asset: "A"})
            .track({asset: "D"})

        .segment(1000)
            .track({asset: "A", filter: "FadeOut"})
            .track({asset: "B", filter: "FadeIn"})
            .track({asset: "D"})

        .segment(2000)
            .track({asset: "B"})
            .track({asset: "D"})

        .segment(1000)
            .track({asset: "C", filter: "FadeIn", seek: 1000})
            .track({asset: "B", filter: "FadeOut"})
            .track({asset: "D"})

        .segment(1000)
            .track({asset: "C"})
            .track({asset: "D"})

        .process("low", outputFile);

    var status = await Transcode.transcode2(poolCleanerInputFile, outputFile);
*/
    //var status = await Transcode.transcode3(poolCleanerInputFile, poolCleanerInputFile, outputFile);
    var status = await Transcode.start()

        .asset({name: "A", path: poolCleanerInputFile})
        .asset({name: "B", path: poolCleanerInputFile})
        .asset({name: "C", path: poolCleanerInputFile})

        .segment(2000)
            .track({asset: "A"})

        .segment(1000)
            .track({asset: "A", filter: "FadeOut"})
            .track({asset: "B", filter: "FadeIn"})

        .segment(2000)
            .track({asset: "B"})

        .segment(1000)
            .track({asset: "B", filter: "FadeOut"})
            .track({asset: "C", filter: "FadeIn"})

        .segment(2000)
            .track({asset: "C"})

        .process("low", outputFile);

    LoggingTestModule.assertEqual('Finished', status);
    LoggingTestModule.assertEqual((await RNFetchBlob.fs.stat(outputFile)).size > 0, true);
}
class TranscodeTest extends React.Component {

  constructor(props) {
    super(props);
    this.onLoad = this.onLoad.bind(this);
    this.onEnd = this.onEnd.bind(this);
    this.state = {
      status: 'running',
    }
  }

  onLoad () {
    //this.player.presentFullscreenPlayer();
  }
  onEnd () {
    this.player.presentFullscreenPlayer();
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
                <Video
                    style={styles.fullScreen}
                    source={{uri: fs.dirs.DocumentDir + "/output.mp4"}}
                    resizeMode="contain"
                    paused={false}
                />
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
    videoContainer: {
      flex: 1,
      justifyContent: 'center',
      alignItems: 'center',
      backgroundColor: 'black',
    },
    fullScreen: {
      position: 'absolute',
      top: 0,
      left: 0,
      bottom: 0,
      right: 0,
    },
    container: {
        backgroundColor: 'white',
        marginTop: 40,
        margin: 15,
    }
});
TranscodeTest.displayName = 'TranscodeTest';

module.exports = TranscodeTest;
