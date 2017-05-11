import React from 'react';
import ReactNative from 'react-native';
var {
    AppRegistry
} = ReactNative;

import IntegrationTestsApp from './integration-test/IntegrationTestsApp';
AppRegistry.registerComponent('HelloWorldTests', () => IntegrationTestsApp);
