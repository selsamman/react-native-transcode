This project is used to publish a react-native component.  The project layout is as follows:

* components/Transcode.js - is the javascript component that connects to the native modules
* android is the project for the android native module.  Although a native component requires a view the view is not used and only TranscodeModule.java is used.  The module links to the selsamman/react-native-transcoder module binary library reposited in jitpack.io.  The gradle file should be kept up with the latest version of that library.
* ios is the project for the ios native module and contains all of the code needed to setup transcoding using the AVFoundation classes

Because of the nature of video transcoding automated testing can only go so far so at present we maintain a test app that runs a number of transcoding test cases and displays the result.  That react-native app is kep t in testapp.

The example and tests folders are obsolete and were originally used for some automated testing in accordance with Ben Wixen's [9-project layout](https://github.com/benwixen/9-project-layout) but this has not been kept up with the latest react-native version so is not currently operative. In order to run the test app you need to do a yarn link on the root project 

```
cd <root-of-this-project>
yarn link
cd testapp
yarn install
yarn link react-native-transcode
react-native-link
react-native run-android
react-native run-ios
```