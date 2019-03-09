import React from 'react';
import ReactNative from 'react-native';
import LoggingTestModule from './LoggingTestModule';
import Transcode from '../copies/Transcode';
import AbstractTest from './AbstractTest';
import RNFetchBlob from 'react-native-fetch-blob'
const { fs, fetch, wrap } = RNFetchBlob

import {
  View,
  TouchableOpacity,
  Text,
  StyleSheet
} from 'react-native';

const invariant = require('fbjs/lib/invariant');
import Video from 'react-native-video';

class OrientationR0 extends AbstractTest {

    constructor(props) {
        super(props);
    }

    async testBody(progressCallback) {

        var R0 = await this.prepFile('R0.mp4');
        var R90 = await this.prepFile('R90.mp4');
        var R180 = await this.prepFile('R180.mp4');
        var R270 = await this.prepFile('R270.mp4');
        var outputFile = fs.dirs.DocumentDir + '/output_' + OrientationR0.displayName + '.mp4';
        try {RNFetchBlob.fs.unlink(outputFile)}catch(e){};

        await Transcode.start()
                .asset({name: "A", path: R0})
                .asset({name: "B", path: R90})
                .asset({name: "C", path: R180})
                .asset({name: "D", path: R270})
            .segment(1000)
                .track({asset: "A"})
            .segment(1000)
                .track({asset: "A", filter: "FadeOut"})
                .track({asset: "B", filter: "FadeIn"})
            .segment(1000)
                .track({asset: "B"})
            .segment(1000)
                .track({asset: "B", filter: "FadeOut"})
                .track({asset: "C", filter: "FadeIn"})
            .segment(1000)
                .track({asset: "C"})
            .segment(1000)
                .track({asset: "C", filter: "FadeOut"})
                .track({asset: "D", filter: "FadeIn"})
            .segment(1000)
            .track({asset: "D"})
                .process("low", outputFile, (progress)=>{progressCallback(progress)});

        LoggingTestModule.assertEqual('Finished', status);
        LoggingTestModule.assertEqual((await RNFetchBlob.fs.stat(outputFile)).size > 0, true);
    }
};

OrientationR0.displayName = 'OrientatonR0';

module.exports = OrientationR0;
