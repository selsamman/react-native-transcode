import React from 'react';
import LoggingTestModule from './LoggingTestModule';
import Transcode from 'react-native-transcode';
import AbstractTest from './AbstractTest';
import RNFetchBlob from 'rn-fetch-blob';

class Orientation270 extends AbstractTest {

    constructor(props) {
        super(props);
    }

    async testBody(progressCallback) {

        var R0 = await this.prepFile('r0.mp4');
        var R90 = await this.prepFile('r90.mp4');
        var R180 = await this.prepFile('r180.mp4');
        var R270 = await this.prepFile('r270.mp4');
        var outputFile = RNFetchBlob.fs.dirs.DocumentDir + '/output_' + Orientation270.displayName + '.mp4';
        try {await RNFetchBlob.fs.unlink(outputFile)}catch(e){};

        const status = await Transcode.start()
                .asset({name: "A", path: R270})
                .asset({name: "B", path: R0})
                .asset({name: "C", path: R90})
                .asset({name: "D", path: R180})
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

Orientation270.displayName = 'Orientation270';

module.exports = Orientation270;
