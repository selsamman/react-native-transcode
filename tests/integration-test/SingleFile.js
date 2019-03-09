import React from 'react';
import ReactNative from 'react-native';
import LoggingTestModule from './LoggingTestModule';
import Transcode from '../copies/Transcode';
import AbstractTest from './AbstractTest';
import RNFetchBlob from 'rn-fetch-blob';

import {
  View,
  TouchableOpacity,
  Text,
  StyleSheet
} from 'react-native';

const invariant = require('fbjs/lib/invariant');
import Video from 'react-native-video';

class SingleFile extends AbstractTest {

    constructor(props) {
        super(props);
    }

    async testBody(progressCallback) {

        var poolCleanerInputFile = await this.prepFile('poolcleaner.mp4');
        var outputFile = RNFetchBlob.fs.dirs.DocumentDir + '/output_' + SingleFile.displayName + '.mp4';
        try {RNFetchBlob.fs.unlink(outputFile)}catch(e){};

        var status = await Transcode.start()
            .asset({name: "A", path: poolCleanerInputFile})

            .segment()
                .track({asset: "A"})

            .process("low", outputFile, (progress)=>{progressCallback(progress)});

        LoggingTestModule.assertEqual('Finished', status);
        LoggingTestModule.assertEqual((await RNFetchBlob.fs.stat(outputFile)).size > 0, true);
    }
};

SingleFile.displayName = 'SingleFile';

module.exports = SingleFile;
