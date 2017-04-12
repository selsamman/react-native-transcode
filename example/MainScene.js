import React from 'react';
import { StyleSheet, View, NativeModules, Text } from 'react-native';
var TranscodeModule = NativeModules.Transcode;
import Transcode from 'react-native-transcode';
export default class MainScene extends React.Component {

  constructor (props) {
    super(props);
    this.sayHello = 'waiting ....';
    this.state = {}
  }

  render() {

    TranscodeModule.sayHello().then((result) => {
      this.sayHello = result;
      this.setState({});
    });

    return (
        <Text>{this.sayHello}</Text>
    );
  }
}

const styles = StyleSheet.create({
  hello: {
    width: 300,
    height: 200,
  },
});
