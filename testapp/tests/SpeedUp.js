import React from 'react';
import LoggingTestModule from './LoggingTestModule';
import Transcode from 'react-native-transcode';
import AbstractTest from './AbstractTest';
import RNFetchBlob from 'rn-fetch-blob';

class SpeedUp extends AbstractTest {

    constructor(props) {
        super(props);
    }

    async testBody(progressCallback) {

        var Pool = await this.prepFile('poolcleaner.mp4');
        var outputFile = RNFetchBlob.fs.dirs.DocumentDir + '/output_' + SpeedUp.displayName + '.mp4';
        try {RNFetchBlob.fs.unlink(outputFile)}catch(e){};

        const status = await Transcode.start()
                .asset({name: "A", path: Pool})
            .segment(500)
                .track({asset: "A"})
            .segment(1000)
                .track({asset: "A", duration: 2000})
            .segment()
                .track({asset: "A"})
            .process("low", outputFile, (progress)=>{progressCallback(progress)});

        LoggingTestModule.assertEqual('Finished', status);
        LoggingTestModule.assertEqual((await RNFetchBlob.fs.stat(outputFile)).size > 0, true);
    }
};

SpeedUp.displayName = 'SpeedUp';

module.exports = SpeedUp;
