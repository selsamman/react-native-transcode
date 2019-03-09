import React from 'react';
import ReactNative from 'react-native';
import RNFetchBlob from 'rn-fetch-blob'
const {
  AppRegistry,
  ScrollView,
  StyleSheet,
  Text,
  TouchableOpacity,
  View,
} = ReactNative;

var TEST_REQUIRES = [
  require('./tests/SingleFile'),
  require('./tests/TwoFiles'),
  require('./tests/AudioOverlayWithFade'),
  require('./tests/Hopscotch'),
  require('./tests/OrientationR0'),
  require('./tests/OrientationR90'),
  require('./tests/OrientationR180'),
  require('./tests/OrientationR270')];

TEST_REQUIRES.forEach(
    (test) => {
      AppRegistry.registerComponent(test.displayName, () => test)
      test = {test: test}
    }
);

export default class IntegrationTestsApp extends React.Component {

  state = {
    componentToRun: null,
    status: 'loading',
  };

  tests = [];

  componentDidMount () {
    this.loadTestFiles();
  }

  async loadTestFiles () {
    this.tests = [];
    for (var ix = 0; ix < TEST_REQUIRES.length; ++ix) {
      const component = TEST_REQUIRES[ix];
      const outputFile = 'output_' + component.displayName + '.mp4';
      const statInfo = await this.statFile(outputFile);
      const test = {
        component: component,
        resultSize: statInfo ? statInfo.size : null,
        displayName: component.displayName
      }
      this.tests.push(test);
    }
    this.setState({status: 'ready'})
  }

  async statFile (fileName) {
    const inputFile = RNFetchBlob.fs.dirs.DocumentDir + '/' + fileName;
    try {
      var statInfo = await RNFetchBlob.fs.stat(inputFile);
      return statInfo;
    } catch (e) {
      console.log(inputFile + ' not found');
      return null;
    }
  }

  render() {
    console.log('Render IntegrationTestsApp ' + this.state.status);
    const self = this;
    if (this.state.status == 'loading')
      return (<ScrollView><Text>Loading ....</Text></ScrollView>);
    else if (this.state.status == 'ready')
      return (
          <View style={styles.container}>
            <Text style={styles.row}>
              Click on a test to run it in this shell for easier debugging and
              development.  Run all tests in the testing environment with cmd+U in
              Xcode.
            </Text>
            <View style={styles.separator} />
            <ScrollView>
              {this.tests.map((test) => [
                <TouchableOpacity
                    onPress={() => {
                      this.setState({componentToRun:test.component, status: 'run'});
                    }}
                    style={styles.row}>
                  <Text style={styles.testName}>
                    {test.displayName}
                  </Text>
                </TouchableOpacity>,
                test.resultSize > 0 && <TouchableOpacity
                    onPress={() => {
                      this.setState({componentToRun:test.component, status: 'view'});
                    }}
                    style={styles.row}>
                  <Text style={styles.testName}>View Output</Text>
                </TouchableOpacity>,
                <View style={styles.separator} />
              ])}
            </ScrollView>
          </View>
      );
    else if (this.state.status == 'run' || this.state.status == 'view')
      return (
          <this.state.componentToRun
              mode={this.state.status}
              name={this.state.componentToRun.displayName}
              finished={()=>{
                self.loadTestFiles();
              }} />
      );
    else
      return (
          <ScrollView>
            <Text>Invalid State: {this.state.status}</Text>
          </ScrollView>
      );
  }
}

const styles = StyleSheet.create({
  container: {
    backgroundColor: 'white',
    marginTop: 40,
    margin: 15,
  },
  row: {
    padding: 10,
  },
  testName: {
    fontWeight: '500',
  },
  separator: {
    height: 1,
    backgroundColor: '#bbbbbb',
  },
});

