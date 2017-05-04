import React from 'react';
import ReactNative from 'react-native';
var {
    AppRegistry,
    ScrollView,
    StyleSheet,
    Text,
    TouchableOpacity,
    View,
} = ReactNative;

var TESTS = [
    require('./integration-test/TranscodeTest'),
];

TESTS.forEach(
    (test) => AppRegistry.registerComponent(test.displayName, () => test)
);

class IntegrationTestsApp extends React.Component {
    state = {
        test: null,
    };

    render() {
        if (this.state.test) {
            return (
                  <this.state.test />
            );
        }
        return (
            <View style={styles.container}>
              <Text style={styles.row}>
                Click on a test to run it in this shell for easier debugging and
                development.  Run all tests in the testing environment with cmd+U in
                Xcode.
              </Text>
              <View style={styles.separator} />
              <ScrollView>
                  {TESTS.map((test) => [
                    <TouchableOpacity
                        onPress={() => this.setState({test})}
                        style={styles.row}>
                      <Text style={styles.testName}>
                          {test.displayName}
                      </Text>
                    </TouchableOpacity>,
                    <View style={styles.separator} />
                  ])}
              </ScrollView>
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

AppRegistry.registerComponent('HelloWorldTests', () => IntegrationTestsApp);
