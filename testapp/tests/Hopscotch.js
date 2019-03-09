import React from 'react';
import LoggingTestModule from './LoggingTestModule';
import Transcode from 'react-native-transcode';
import AbstractTest from './AbstractTest';
import RNFetchBlob from 'rn-fetch-blob';

class Hopscotch extends AbstractTest {

    constructor(props) {
        super(props);
    }

    async testBody(progressCallback) {

        const poolCleanerInputFile = await this.prepFile('poolcleaner.mp4');
        const outputFile = RNFetchBlob.fs.dirs.DocumentDir + '/output_' + Hopscotch.displayName + '.mp4';
        try {RNFetchBlob.fs.unlink(outputFile)}catch(e){}

        await Transcode.start()
            .asset({name: "A", path: poolCleanerInputFile})
            .asset({name: "B", path: poolCleanerInputFile})

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
}

Hopscotch.displayName = 'Hopscotch';

module.exports = Hopscotch;
