<p align="center">
  <a href="https://img.ly/video-sdk?utm_campaign=Projects&utm_source=Github&utm_medium=VESDK&utm_content=Cordova"><img src="https://img.ly/static/logos/VE.SDK_Logo.svg" alt="VideoEditor SDK Logo"/></a>
</p>
<p align="center">
  <a href="https://npmjs.org/package/cordova-plugin-videoeditorsdk">
    <img src="https://img.shields.io/npm/v/cordova-plugin-videoeditorsdk.svg" alt="NPM version">
  </a>
  <img src="https://img.shields.io/badge/platforms-android%20|%20ios-lightgrey.svg" alt="Platform support">
  <a href="http://twitter.com/VideoEditorSDK">
    <img src="https://img.shields.io/badge/twitter-@VideoEditorSDK-blue.svg?style=flat" alt="Twitter">
  </a>
</p>

# Cordova & Ionic plugin for VideoEditor SDK
## Getting started

Add VideoEditor SDK plugin to your project as follows:

```sh
cordova plugin add cordova-plugin-videoeditorsdk
```

### Android

From version `3.0.0` the plugin uses AndroidX. To enable AndroidX in your application please adjust your `config.xml`:

```diff
<platform name="android">
...
+    <preference name="AndroidXEnabled" value="true" />
...
</platform>
```

If your application is using legacy Android Support Libraries you can use the [`cordova-plugin-androidx-adapter`](https://www.npmjs.com/package/cordova-plugin-androidx-adapter) which will migrate the legacy libraries to work with AndroidX.

#### Kotlin Version

If you are using `Cordova Android` version `10.+`, you might need to adjust the Kotlin version of your application in your `config.xml`, if your current Kotlin version is not compatible with our plugin:

```diff
<platform name="android">
...
+    <preference name="GradlePluginKotlinVersion" value="1.4.10" />
...
</platform>
```

#### Module Configuration

You can configure the modules used for the VideoEditor SDK for Android by opening `imglyConfig.gradle` and removing / commenting out the modules you do not need. This will also reduce the size of your application.

Because VideoEditor SDK for Android with all its modules is quite large, there is a high chance that you will need to enable [Multidex](https://developer.android.com/studio/build/multidex) for your project as follows:

```sh
cordova plugin add cordova-plugin-enable-multidex
```

### Usage

Each platform requires a separate license file. Unlock VideoEditor SDK with a single line of code for both platforms via platform-specific file extensions.

Rename your license files:
- Android license: `ANY_NAME.android`
- iOS license: `ANY_NAME.ios`

Pass the file path without the extension to the `unlockWithLicense` function to unlock both iOS and Android:
```js
VESDK.unlockWithLicense('www/assets/ANY_NAME');
```

Open the editor with a video:
```js
VESDK.openEditor(
  successCallback,
  failureCallback,
  VESDK.resolveStaticResource('www/assets/video.mp4')
);
```

Please see the [code documentation](./types/index.d.ts) for more details and additional [customization and configuration options](./types/configuration.ts).

#### Notes for Ionic framework

- Add this line above your class to be able to use `VESDK`.
  ```js
  declare var VESDK;
  ```
- Ionic will generate a `www` folder that will contain your compiled code and your assets. In order to pass resources to VideoEditor SDK you need to use this folder.

## Example

Please see our [example project](https://github.com/imgly/vesdk-cordova-demo) which demonstrates how to use the Cordova plugin for VideoEditor SDK.

## License Terms

Make sure you have a [commercial license](https://img.ly/pricing?product=vesdk&?utm_campaign=Projects&utm_source=Github&utm_medium=VESDK&utm_content=Cordova) for VideoEditor SDK before releasing your app.
A commercial license is required for any app or service that has any form of monetization: This includes free apps with in-app purchases or ad supported applications. Please contact us if you want to purchase the commercial license.

## Support and License

Use our [service desk](https://support.img.ly) for bug reports or support requests. To request a commercial license, please use the [license request form](https://img.ly/pricing?product=vesdk&?utm_campaign=Projects&utm_source=Github&utm_medium=VESDK&utm_content=Cordova) on our website.
