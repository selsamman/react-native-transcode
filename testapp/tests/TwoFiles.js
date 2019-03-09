import React from 'react';
import LoggingTestModule from './LoggingTestModule';
import Transcode from 'react-native-transcode';
import AbstractTest from './AbstractTest';
import RNFetchBlob from 'rn-fetch-blob';

class TwoFiles extends AbstractTest {

    constructor(props) {
        super(props);
    }

    async testBody(progressCallback) {

        var poolCleanerInputFile = await this.prepFile('poolcleaner.mp4');
        var outputFile = RNFetchBlob.fs.dirs.DocumentDir + '/output_' + TwoFiles.displayName + '.mp4';
        try {RNFetchBlob.fs.unlink(outputFile)}catch(e){};

        var status = await Transcode.start()
            .asset({name: "A", path: poolCleanerInputFile})
            .asset({name: "B", path: poolCleanerInputFile})

            .segment()
                .track({asset: "A"})

            .segment()
                .track({asset: "B"})

            .process("low", outputFile, (progress)=>{progressCallback(progress)});

        LoggingTestModule.assertEqual('Finished', status);
        LoggingTestModule.assertEqual((await RNFetchBlob.fs.stat(outputFile)).size > 0, true);
    }
};

TwoFiles.displayName = 'TwoFiles';

module.exports = TwoFiles;
