var VESDK = {
  /**
   * Present a video editor.
   *
   * @param {function} success - The callback returns a {VideoEditorResult} or
   *     `null` if the editor is dismissed without exporting the edited video.
   * @param {function} failure - The callback function that will be called when
   *     an error occurs.
   * @param {string} video The source of the video to be edited.
   * @param {object} configuration The configuration used to initialize the
   *     editor.
   * @param {object} serialization The serialization used to initialize the
   *     editor. This
   * restores a previous state of the editor by re-applying all modifications to
   * the loaded video.
   */
  openEditor: function (success, failure, video, configuration, serialization) {
    var options = {};
    options.path = video;
    if (configuration != null) {
      options.configuration = configuration;
    }
    if (serialization != null) {
      options.serialization = serialization;
    }
    cordova.exec(success, failure, "VESDK", "present", [options]);
  },

  /**
   * Unlock VideoEditor SDK with a license.
   *
   * The license should have an extension like this:
   * for iOS: "xxx.ios", example: vesdk_license.ios
   * for Android: "xxx.android", example: vesdk_license.android
   * then pass just the name without the extension to the `unlockWithLicense` function.
   * @example `VESDK.unlockWithLicense('www/assets/vesdk_license')`
   *
   * @param {string} license The path of license used to unlock the SDK.
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
   * Get the correct path to each platform
   * It can be used to load local resources
   *
   * @param {string} path The path of the local resource.
   * @returns {string} assets path to deal with it inside VideoEditor SDK
   */
  loadResource: function (path) {
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
};
module.exports = VESDK;
