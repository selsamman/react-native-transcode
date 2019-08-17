import React from 'react';
import LoggingTestModule from './LoggingTestModule';
import Transcode from 'react-native-transcode';
import AbstractTest from './AbstractTest';
import RNFetchBlob from 'rn-fetch-blob';

class AudioOverlayWithFade extends AbstractTest {

    constructor(props) {
        super(props);
        console.log(JSON.stringify(props));
    }

    async testBody(progressCallback) {

        const poolCleanerInputFile = await this.prepFile('poolcleaner.mp4');
        const frogsInputFile = await this.prepFile('frogs.mp4');


        const outputFile = RNFetchBlob.fs.dirs.DocumentDir + '/output_' + AudioOverlayWithFade.displayName + '.mp4';
        try {await RNFetchBlob.fs.unlink(outputFile)}catch(e){}

        const status = await Transcode.start()

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
}

AudioOverlayWithFade.displayName = 'AudioOverlayWithFade';

module.exports = AudioOverlayWithFade;
