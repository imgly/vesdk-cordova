var VESDK = {
  /**
   * Modally present a video editor.
   * @note Remote resources are not optimized and therefore should be downloaded
   * in advance and then passed to the editor as local resources.
   *
   * @param {function} success - The callback returns a `VideoEditorResult` or `null` if the editor
   * is dismissed without exporting the edited video.
   * @param {function} failure - The callback function that will be called when an error occurs.
   * @param {string | [string]} video The source of the video to be edited.
   * Can be a local or remote URI. Remote resources should be downloaded in advance and
   * then passed to the editor as local resources. Static local resources which reside, e.g., in the `www`
   * folder of your app, should be resolved by `VESDK.resolveStaticResource("www/path/to/your/video")` 
   * before they can be passed to the editor.
   * 
   * For video compositions an array of video sources is accepted as input. If an empty array is
   * passed to the editor `videoSize` must be set. You need to obtain a **valid license** for this 
   * feature to work.
   * @param {Configuration} configuration The configuration used to initialize the editor.
   * @param {object} serialization The serialization used to initialize the editor. 
   * This restores a previous state of the editor by re-applying all modifications to
   * the loaded video.
   * @param {Size} videoSize **Video composition only:** The size of the video in pixels that is about to be edited.
   * This overrides the natural dimensions of the video(s) passed to the editor. All videos will
   * be fitted to the `videoSize` aspect by adding black bars on the left and right side or top and bottom.
   */
  openEditor: function (success, failure, video, configuration, serialization, videoSize = null) {
    var options = {};

    if (configuration != null) {
      options.configuration = configuration;
    }
    if (serialization != null) {
      options.serialization = serialization;
    }

    if (Array.isArray(video)) {
      if (videoSize != null) {
        options.size = videoSize;
      }
      options.videos = video;
      cordova.exec(success, failure, "VESDK", "presentComposition", [options]);
    } else {
      if (videoSize != null) {
        console.warn("Ignoring the video size. This parameter can only be used in combination with video compositions. If your license includes the video composition feature please wrap your video source into an array instead.")
      }
      options.path = video;
      cordova.exec(success, failure, "VESDK", "present", [options]);
    }
  },

  /**
   * Unlock VideoEditor SDK with a license.
   *
   * @param {string} license The path of the license used to unlock the SDK.
   * The license files should be located within the `www` folder and must have
   * the extension `.ios` for iOS and `.android` for Android. In this way the 
   * licenses get automatically resolved for each platform so that no file-
   * extension is needed in the path.
   * 
   * @example 
   * // Both licenses `vesdk_license.ios` and `vesdk_license.android` 
   * // located in `www/assets/` will be automatically resolved by:
   * VESDK.unlockWithLicense('www/assets/vesdk_license')
   */
  unlockWithLicense: function (license) {
    var platform = window.cordova.platformId;
    if (platform == "android") {
      license += ".android";
    } else if (platform == "ios") {
      license = "imgly_asset:///" + license + ".ios";
    }
    cordova.exec(null, null, "VESDK", "unlockWithLicense", [license]);
  },
  /**
   * Resolves the path of a static local resource.
   *
   * @param {string} path The path of the static local resource.
   * @returns {string} The platform-specific path for a static local resource that can be accessed by the native VideoEditor SDK plugin.
   */
  resolveStaticResource: function (path) {
    var platform = window.cordova.platformId;
    if (platform == "android") return "asset:///" + path;
    else if (platform == "ios") {
      var tempPath = "imgly_asset:///" + path;
      return tempPath;
    }
  },
  getDevice: function () {
    return window.cordova.platformId;
  },  
  /**
   * @deprecated Use `VESDK.resolveStaticResource` instead.
   * Resolves the path of a static local resource.
   *
   * @param {string} path The path of the static local resource.
   * @returns {string} The platform-specific path for a static local resource that can be accessed by the native VideoEditor SDK plugin.
   */
  loadResource: function (path) {
    return this.resolveStaticResource(path);
  },
};
module.exports = VESDK;
