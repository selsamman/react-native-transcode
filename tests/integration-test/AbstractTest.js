import React from 'react';
import ReactNative from 'react-native';
import LoggingTestModule from './LoggingTestModule';
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

export default class AbstractTest extends React.Component {

    async prepFile(fileName) {
        var inputFile = fs.dirs.DocumentDir + '/' + fileName;
        try {RNFetchBlob.fs.unlink(inputFile)}catch(e){};
        await RNFetchBlob.fs.cp(fs.asset('video/' + fileName),inputFile)
        LoggingTestModule.assertEqual((await RNFetchBlob.fs.stat(inputFile)).size > 0, true);
        return inputFile;
    }

    startTime;

    async testBody (progressCallback) {
      throw new Error('Mising testBody override');
    }

  constructor(props) {
    super(props);
     this.state = {
      status: 'loading',
      elapsedTime: 0,
      progress: 0
    }
  }

  componentDidMount() {
    if (this.props.mode == 'run') {
        this.setState({status: 'running', progress: '0', elapsedTime: '0', name: this.props.name})
        this.runTest();
    } else if (this.props.mode == 'view') {
        this.setState({status: 'viewVideo',name: this.props.name});
    } else
        this.setState({status: 'Missing mode parameter on test component'});
  }

  async runTest() {
    try {
      this.startTime = (new Date()).getTime();
      await this.testBody((progress) => this.updateProgress(progress));
      this.updateTime();
      this.setState({status: 'viewResults' });
    } catch (error) {
      console.log(error.message + error.stack);
      LoggingTestModule.logErrorToConsole(error);
      if (TestModule) {
        TestModule.markTestPassed(false);
      }
      this.setState({ status: 'failed' });
    }
    if (TestModule) {
      TestModule.markTestPassed(true);
    }
  }

  updateProgress (progress) {
    console.log("AbstractTest progress" + progress);
    this.setState({progress: Math.floor(progress * 100)});
    this.updateTime();
  }
  updateTime() {
    this.setState({elapsedTime: Math.floor((new Date()).getTime() - this.startTime) / 1000});
  }

  render() {
    console.log('Render AbstractTest status = ' + this.state.status);
    if (this.state.status.match(/^view/))
        return (
            <View style={styles.videoContainer}>
                <TouchableOpacity style={styles.fullScreen} onPress={
                    () => this.props.finished()
                } >
                <Video
                    style={styles.fullScreen}
                    source={{uri: fs.dirs.DocumentDir + '/output_' + this.state.name + '.mp4'}}
                    resizeMode="contain"
                    paused={false}
                />
                </TouchableOpacity>
            </View>
        );
    else if (this.state.status == 'running')
        return (
              <View style={styles.container}>
                  <Text>Elapsed Time: {this.state.elapsedTime} Sec</Text>
                  <View style={styles.separator} />
                  <Text>Progress - {this.state.progress} % </Text>
              </View>
        );
    else
        return (
            <View style={styles.container}>
                <Text>Invalid status: {this.state.status}</Text>
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
