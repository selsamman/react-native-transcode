# React-Native-Transcoder

This native library provides video composition capabilities for Android and IOS.  With it you can:

 * Combine multiple files
 * Splice out portions of the file at the beginning middle or end
 * Crossfade transitions
 * Do time scaling, both speeding up and slowing down segments
 * Transcode to 1080p or 720p while processing

On IOS the library uses the AVFoundation classes and more specifically the AVVideoComposition class to compose a final composition.  On Android   selsamman/react-native-transcoder is used which transcodes using the MediaCodec native capabilities for hardware accelerated transcoding free of ffmpeg. 
## Usage

```java
    
       const poolCleanerInputFile = await this.prepFile('poolcleaner.mp4');
       const outputFile = RNFetchBlob.fs.dirs.DocumentDir + '/output_' + Hopscotch.displayName + '.mp4';

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
```
### Android and IOS Installation

```groovy
yarn add react-native-transcode
react-native link
```

### API

The API uses function chaining to specify the video composition to be created.  It consists of
* assets that define video files to be decode
* a sequential set of time segments that refer to those assets

To initiate the composition you use ***Transcode.start()*** which returns a promise when the transcode is complete. Then you chain on the assets and segments, finally chaining the process call to initiate the transcoding and create the composition.

````
await Transcode.start()
````

### asset

Any video assets used in the transcoding must first be added using the asset function.

````java
.asset({name: String, path: String, type: String})
````
* ***name*** - the name of the asset that will be referred to in subsequent segment calls
* ***path*** - the full path of the video or audio file
* ***type*** - 
   * ***AudioVideo*** Process both audio and video (default)
   * ***VideoOnly*** Ignore audio
   * ***AudioOnly*** Ignore video


### segment

Multiple segments be attached to the TimeLine to define the individual sequential portions of the composition.  You create a segment by calling createSegment.

````Java
    .segment(Number)
```` 
This creates a time segment with a specific duration specified in milliseconds.  If duration is omitted the entirety of the remaining stream is processed.  ***track*** calls are chained to the ***segment*** call to define the individual tracks to be decoded during this particular segment.


```java
    .track({asset: String, filter: String, seek: Number, duration: Number})
```` 

* ***asset*** the name of asset defined in the ***asset*** call
* ***seek*** the number of milliseconds to skip in the stream.
* ***filter*** a filter to be applied.
 * ***FadeOut*** fade out this segment by reducing the opacity to transparent
 * ***FadeIn*** fade in the segment by starting it as transparent and then fading up
 * ***Mute*** mute the audio in the track
* ***duration*** applies time-scaling by consuming the number of milliseconds specified for the track duration during the course of the duration of the segment.  A larger track duration than the segment duration causes fast motion and the opposite causes slow motion.
 
 Note that multiple filters can be separated by semi-colons. ***Mute*** and ***duration*** can be applied with ***FadeOut***/***FadeIn*** by separating the two filters with a semi-colon.  To perform a cross-fade apply ***FadeOut*** only to one of the tracks in the segment to be cross-faded.  

### process

The last function to be chained is process which defines the output resolution and file.

````Java
    .process (String, String, function);
````
* ***1st Parameter*** the resolution which may be **low** (720P) or **high** (1080P)
* ***2nd Parameter*** the full path of the output file to be created or overwritten
* ***3rd Parameter*** the name of a progress call back that is passed a progress indcator between zero and 1.
 ## License


Copyright (C) 2016-2019 Sam Elsamman


Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.

