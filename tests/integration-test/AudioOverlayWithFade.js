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

class AudioOverlayWithFade extends AbstractTest {

    constructor(props) {
        super(props);
        console.log(JSON.stringify(props));
    }

    async testBody(progressCallback) {

        var poolCleanerInputFile = await this.prepFile('poolcleaner.mp4');
        var frogsInputFile = await this.prepFile('frogs.mp4');
        //var carInputFile = await prepFile('car.mp4');
        //var skateInputFile = await prepFile('skate.mp4');

        var outputFile = fs.dirs.DocumentDir + '/output_' + AudioOverlayWithFade.displayName + '.mp4'
        try {RNFetchBlob.fs.unlink(outputFile)}catch(e){};

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
            .track({asset: "B", filter: "FadeOut"})
            .track({asset: "C", filter: "FadeIn"})

            .segment(2000)
            .track({asset: "C"})
            .track({asset: "D"})

            .process("low", outputFile, (progress)=>{progressCallback(progress)});

        LoggingTestModule.assertEqual('Finished', status);
        LoggingTestModule.assertEqual((await RNFetchBlob.fs.stat(outputFile)).size > 0, true);
    }
};

AudioOverlayWithFade.displayName = 'AudioOverlayWithFade';

module.exports = AudioOverlayWithFade;
