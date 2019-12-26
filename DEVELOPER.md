This project is used to publish a react-native component.  The project layout is as follows:

* components/Transcode.js - is the javascript component that connects to the native modules
* android is the project for the android native module.  Although a native component requires a view the view is not used and only TranscodeModule.java is used.  The module links to the selsamman/react-native-transcoder module binary library reposited in jitpack.io.  The gradle file should be kept up with the latest version of that library.
* ios is the project for the ios native module and contains all of the code needed to setup transcoding using the AVFoundation classes

Because of the nature of video transcoding automated testing can only go so far so at present we maintain a test app that runs a number of transcoding test cases and displays the result.  That react-native app is kept in testapp.

 The testapp refers to the root project for react-native-transcode.  Therefore you need to do a yarn install --force if you modify the root project until the issues with using yarn link are resolved.
 
 Some notes on recreating the testapp when upgrading react-native versions:
 * Rename testapp to testappxx where xx is the prior version number
 * Start by generating a new react-native project testapp
 * Add in the dependencies in package.json checking each to make sure you reference the latest version of the library.
 * Copy the contents of the old App.js to the new App.js
 * Copy over the tests sub-directory
 * Copy android /app/src/main/assets/video
 * Update minSdkVersion in android/build.gradle to 21
 * Do a yarn install
 * do pod install inside ios folder
 * In Xcode add the video assets from /app/src/main/assets/video by going to Build Phases -> Copy Bundle Resources and adding them with the + and then selecting **Add Other**.  Set copy items if needed and create folder references.
 * Once everything is working just delete testapp and rename your new directory to testapp
  
```
