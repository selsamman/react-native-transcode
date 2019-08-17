import React from 'react';
import LoggingTestModule from './LoggingTestModule';
import Transcode from 'react-native-transcode';
import AbstractTest from './AbstractTest';
import RNFetchBlob from 'rn-fetch-blob';

class Mute extends AbstractTest {

    constructor(props) {
        super(props);
    }

    async testBody(progressCallback) {

        var R0 = await this.prepFile('r0.mp4');
        var outputFile = RNFetchBlob.fs.dirs.DocumentDir + '/output_' + Mute.displayName + '.mp4';
        try {await RNFetchBlob.fs.unlink(outputFile)}catch(e){};

        const status = await Transcode.start()
                .asset({name: "A", path: R0})
            .segment(100)
                .track({asset: "A"})
            .segment(1900)
                .track({asset: "A", filter: "Mute"})
            .segment(1000)
                .track({asset: "A"})
            .process("low", outputFile, (progress)=>{progressCallback(progress)});

        LoggingTestModule.assertEqual('Finished', status);
        LoggingTestModule.assertEqual((await RNFetchBlob.fs.stat(outputFile)).size > 0, true);
    }
};

Mute.displayName = 'Mute';

module.exports = Mute;
