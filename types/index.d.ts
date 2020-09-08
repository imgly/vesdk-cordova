import { Configuration } from './configuration';

/**
 * The result of an export.
 */
interface VideoEditorResult {
    /** The edited video. */
    video: string;
    /** An indicator whether the input video was modified at all. */
    hasChanges: boolean;
    /**
     * All modifications applied to the input video if
     * `export.serialization.enabled` of the `Configuration` was set to `true`.
     */
    serialization?: string | object;
}

declare class VESDK {
    /**
     * Present a video editor.
     * 
     * @param {function} success - The callback returns a {VideoEditorResult} or
     *     `null` if the editor is dismissed without exporting the edited video.
     * @param {function} failure - The callback function that will be called when
     *     an error occurs.
     * @param {string} video The source of the video to be edited.
     * @param {Configuration} configuration The configuration used to initialize the
     *     editor.
     * @param {object} serialization The serialization used to initialize the
     *     editor. This
     * restores a previous state of the editor by re-applying all modifications to
     * the loaded video.
     */
    static openEditor(
        success: (args: VideoEditorResult) => void,
        failure: (error: any) => void,
        video: { uri: string },
        configuration?: Configuration,
        serialization?: object): void

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
    static unlockWithLicense(license: string): void

    /**
    * Get the correct path to each platform
    * It can be used to load local resources
    *
    * @param {string} path The path of the local resource.
    * @returns {string} assets path to deal with it inside VideoEditor SDK
    */
    static loadResource(
        video: string): { uri: string }
}

export { VESDK, VideoEditorResult }
export * from './configuration';