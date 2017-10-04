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

class Hopscotch extends AbstractTest {

    constructor(props) {
        super(props);
    }

    async testBody(progressCallback) {

        var poolCleanerInputFile = await this.prepFile('poolcleaner.mp4');
        var outputFile = fs.dirs.DocumentDir + '/output_' + Hopscotch.displayName + '.mp4';
        try {RNFetchBlob.fs.unlink(outputFile)}catch(e){};

        var status = await Transcode.start()
            .asset({name: "A", path: poolCleanerInputFile})
            .asset({name: "B", path: poolCleanerInputFile})
            .asset({name: "C", path: poolCleanerInputFile})

            .segment(500)
                .track({asset: "A"})

            .segment(500)
                .track({asset: "A", filter: "FadeOut"})
                .track({asset: "B", filter: "FadeIn", seek: 750})

            .segment(500)
                .track({asset: "B"})

            .segment(500)
                .track({asset: "B", filter: "FadeOut"})
                .track({asset: "A", filter: "FadeIn", seek: 500})

            .segment(500)
                .track({asset: "A"})

            .process("low", outputFile, (progress)=>{progressCallback(progress)});

        LoggingTestModule.assertEqual('Finished', status);
        LoggingTestModule.assertEqual((await RNFetchBlob.fs.stat(outputFile)).size > 0, true);
    }
};

Hopscotch.displayName = 'Hopscotch';

module.exports = Hopscotch;
