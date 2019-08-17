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
        try {await RNFetchBlob.fs.unlink(outputFile)}catch(e){};

        const status = await Transcode.start()
                .asset({name: "A", path: Pool})
                .asset({name: "B", path: Pool})
            .segment(4000)
                .track({asset: "A", duration:2000})
            .segment(1000)
                .track({asset: "A", duration: 500, filter: "FadeOut"})
                .track({asset: "B", filter: "FadeIn", duration:2000})
            .segment(500)
                .track({asset: "B", duration: 2000})
            .segment(2000)
                .track({asset: "A", duration: 500, seek: 1000})
            .process("low", outputFile, (progress)=>{progressCallback(progress)});
/*
               TimeLine timeline = new TimeLine(LogLevelForTests)
                        .addChannel("A", in1.getFileDescriptor())
                        .addChannel("B", in1.getFileDescriptor())
                        .addChannel("C", in1.getFileDescriptor())
                        .addAudioOnlyChannel("D", in2.getFileDescriptor())
                        .createSegment()
                            .output("A").timeScale(2000)
                            .output("D")
                            .duration(4000)
                        .timeLine().createSegment()
                            .output("A").timeScale(500)
                            .output("B", TimeLine.Filter.OPACITY_UP_RAMP).timeScale(2000)
                            .output("D")
                            .duration(1000)
                        .timeLine().createSegment()
                            .output("B").timeScale(2000)
                            .duration(500)
                        .timeLine().createSegment()
                            .seek("A", 1000)
                            .output("A").timeScale(500)
                            .duration(2000)
                            .output("D")
                        .timeLine();
*/

        LoggingTestModule.assertEqual('Finished', status);
        LoggingTestModule.assertEqual((await RNFetchBlob.fs.stat(outputFile)).size > 0, true);
    }
};

SpeedUp.displayName = 'SpeedUp';

module.exports = SpeedUp;
