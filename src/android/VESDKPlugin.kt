package com.photoeditorsdk.cordova

import android.app.Activity
import android.content.Intent
import android.net.Uri
import android.os.Bundle
import android.util.Log
import com.google.gson.Gson
import com.google.gson.reflect.TypeToken
import java.io.File
import ly.img.android.IMGLY
import ly.img.android.VESDK
import ly.img.android.pesdk.VideoEditorSettingsList
import ly.img.android.pesdk.backend.model.EditorSDKResult
import ly.img.android.pesdk.backend.model.state.LoadSettings
import ly.img.android.pesdk.backend.model.state.manager.SettingsList
import ly.img.android.pesdk.backend.encoder.Encoder
import ly.img.android.pesdk.backend.model.state.VideoCompositionSettings
import ly.img.android.pesdk.kotlin_extension.continueWithExceptions
import ly.img.android.pesdk.ui.activity.EditorBuilder
import ly.img.android.pesdk.utils.MainThreadRunnable
import ly.img.android.pesdk.utils.SequenceRunnable
import ly.img.android.pesdk.utils.UriHelper
import ly.img.android.sdk.config.*
import ly.img.android.serializer._3.IMGLYFileReader
import ly.img.android.serializer._3.IMGLYFileWriter
import org.apache.cordova.CallbackContext
import org.apache.cordova.CordovaPlugin
import org.json.JSONArray
import org.json.JSONException
import org.json.JSONObject
import java.util.UUID

/** VESDKPlugin */
class VESDKPlugin : CordovaPlugin() {

    companion object {
        // This number must be unique. It is public to allow client code to change it if the same value is used elsewhere.
        var EDITOR_RESULT_ID = 29065
    }

    /** The callback used for the plugin. */
    private var callback: CallbackContext? = null

    /** The currently used configuration. */
    private var currentConfig: Configuration? = null

    override fun onStart() {
        IMGLY.initSDK(this.cordova.activity)
        IMGLY.authorize()
    }

    @Throws(JSONException::class)
    override fun execute(action: String, data: JSONArray, callbackContext: CallbackContext): Boolean {
        return if (action == "present") { // Extract image path
            val options = data.getJSONObject(0)
            val filepath = options.optString("path", "")
            val configuration = options.optString("configuration", "{}")
            val serialization = options.optString("serialization", null)

            val config: Map<String, Any> = Gson().fromJson(configuration, object : TypeToken<Map<String, Any>>() {}.type)
            present(filepath, config, serialization, callbackContext)
            true
        } else if (action == "presentComposition") {
            val options = data.getJSONObject(0)
            val videos = options.optJSONArray("videos")
            val size = options.optString("size", "")
            val configuration = options.optString("configuration", "{}")
            val serialization = options.optString("serialization", null)

            val videoClips = if (videos != null) {
                Array(videos.length()) { videos.getString(it) }
            } else {
                arrayOf<String>()
            }

            val gson = Gson()
            val config: Map<String, Any> = gson.fromJson(configuration, object : TypeToken<Map<String, Any>>() {}.type)
            val videoSize: Map<String, Any>? = gson.fromJson(size, object : TypeToken<Map<String, Any>?>() {}.type)
            presentComposition(videoClips, config, serialization, videoSize, callbackContext)
            true
        } else if (action == "unlockWithLicense") {
            val license = data[0].toString()
            unlockWithLicense(license)
            true
        } else {
            false
        }
    }

    /**
     * Unlocks the SDK with a stringified license.
     *
     * @param license The license as a *String*.
     */
    fun unlockWithLicense(license: String) {
        val jsonString = this.cordova.activity.assets.open(license).bufferedReader().use {
            it.readText()
        }

        VESDK.initSDKWithLicenseData(jsonString)
        IMGLY.authorize()
    }

    /**
     * Configures and presents the editor.
     *
     * @param filepath The video source as *String* which should be loaded into the editor.
     * @param config The *Configuration* to configure the editor with as if any.
     * @param serialization The serialization to load into the editor if any.
     * @param callbackContext The *CallbackContext* used to communicate with the plugin.
     */
    private fun present(
        filepath: String,
        config: Map<String, Any>,
        serialization: String?,
        callbackContext: CallbackContext
    ) {
        callback = callbackContext
        IMGLY.authorize()
        val configuration = ConfigLoader.readFrom(config)
        val settingsList = VideoEditorSettingsList(configuration.export?.serialization?.enabled == true)
        configuration.applyOn(settingsList)
        currentConfig = configuration

        settingsList.configure<LoadSettings> { loadSettings ->
            loadSettings.source = retrieveURI(filepath)
        }

        readSerialisation(settingsList, serialization)
        startEditor(settingsList)    
    }

    /**
     * Configures and presents the editor.
     *
     * @param videos The video sources as *List<String>* which should be loaded into the editor.
     * @param config The *Configuration* to configure the editor with as if any.
     * @param serialization The serialization to load into the editor if any.
     * @param size The size of the video composition.
     * @param callbackContext The *CallbackContext* used to communicate with the plugin.
     */
    private fun presentComposition(
        videos: Array<String>?,
        config: Map<String, Any>,
        serialization: String?,
        size: Map<String, Any>?,
        callbackContext: CallbackContext
    ) {
        callback = callbackContext
        IMGLY.authorize()

        // Set the video size as the default source.
        var source = resolveSize(size)

        val configuration = ConfigLoader.readFrom(config)
        val settingsList = VideoEditorSettingsList(configuration.export?.serialization?.enabled == true)
        configuration.applyOn(settingsList)
        currentConfig = configuration

        if (videos != null && videos.count() > 0) {
            if (source == null) {
                if (size != null) {
                    throw RuntimeException("Invalid video size: width and height must be greater than zero.")
                }
                source = retrieveURI(videos.first())
            }

            settingsList.configure<VideoCompositionSettings> { loadSettings ->
                videos.forEach {
                    val resolvedSource = retrieveURI(it)
                    loadSettings.addCompositionPart(VideoCompositionSettings.VideoPart(resolvedSource))
                }
            }
        } else {
            // If the source (= video size) is null we can not open the editor.
            if (source == null) {
                throw RuntimeException("The editor requires a valid size when initialized without a video.")
            }
        }

        settingsList.configure<LoadSettings> {
            it.source = source
        }

        readSerialisation(settingsList, serialization)
        startEditor(settingsList)
    }

    /**
     * Starts the editor.
     * @param settingsList The *VideoEditorSettingsList* used to configure the editor.
     */
    private fun startEditor(settingsList: VideoEditorSettingsList) {
        val currentActivity = cordova.activity ?: throw RuntimeException("Can't start the Editor because there is no current activity")
        cordova.setActivityResultCallback(this)
        MainThreadRunnable {
            EditorBuilder(currentActivity)
                .setSettingsList(settingsList)
                .startActivityForResult(currentActivity, EDITOR_RESULT_ID, arrayOfNulls(0))
            settingsList.release()
        }()
    }

    /**
     * Converts a string into a usable *Uri*.
     * @param source The source of the video as a *String*.
     * @return The converted source as a *Uri*.
     */
    private fun retrieveURI(source: String) : Uri {
        return if (source.startsWith("data:")) {
            UriHelper.createFromBase64String(source.substringAfter("base64,"))
        } else {
            val potentialFile = continueWithExceptions { File(source) }
            if (potentialFile?.exists() == true) {
                Uri.fromFile(potentialFile)
            } else {
                ConfigLoader.parseUri(source)
            }
        }
    }

    /**
     * Resolves a size for the video composition into a usable *Uri?*.
     * @param size The desired size of the video composition as a *Map<String, Any>?*.
     * @return The converted video size as a *Uri?*.
     */
    private fun resolveSize(size: Map<String, Any>?) : Uri? {
        val height = size?.get("height") as? Double ?: 0.0
        val width = size?.get("width") as? Double ?: 0.0
        if (height == 0.0 || width == 0.0) {
            return null
        }
        return LoadSettings.compositionSource(width.toInt(), height.toInt(), 60)
    }

    /**
     * Called when the editor has succeeded exporting the video.
     * @param intent The *Intent?*.
     */
    private fun success(intent: Intent?) {
        val data = try {
            intent?.let { EditorSDKResult(it) }
        } catch (e: EditorSDKResult.NotAnImglyResultException) {
            null
        } ?: return // If data is null the result is not from us.

        SequenceRunnable("Export Done") {
            val sourcePath = data.sourceUri
            val resultPath = data.resultUri

            val serializationConfig = currentConfig?.export?.serialization

            val serialization: Any? = if (serializationConfig?.enabled == true) {
                val settingsList = data.settingsList
                skipIfNotExists {
                    settingsList.let { settingsList ->
                        if (serializationConfig.embedSourceImage == true) {
                            Log.i("ImgLySdk", "EmbedSourceImage is currently not supported by the Android SDK")
                        }
                        when (serializationConfig.exportType) {
                            SerializationExportType.FILE_URL -> {
                                val uri = serializationConfig.filename?.let { 
                                    Uri.parse("$it.json")
                                } ?: Uri.fromFile(File.createTempFile("serialization-" + UUID.randomUUID().toString(), ".json"))
                                Encoder.createOutputStream(uri).use { outputStream ->
                                    IMGLYFileWriter(settingsList).writeJson(outputStream)
                                }
                                uri.toString()
                            }
                            SerializationExportType.OBJECT -> {
                                IMGLYFileWriter(settingsList).writeJsonAsString()
                            }
                        }
                    }
                } ?: run {
                    Log.i("ImgLySdk", "You need to include 'backend:serializer' Module, to use serialisation!")
                    null
                }
                settingsList.release()
            } else {
                null
            }
            val result = createResult(resultPath, sourcePath?.path != resultPath?.path, serialization)
            callback?.success(result)

        }()
    }

    /**
     * Reads the serialization to restore a previous state in the editor.
     * @param settingsList The *SettingsList*.
     * @param serialization The serialization which holds the previous state.
     */
    private fun readSerialisation(settingsList: SettingsList, serialization: String?) {
        if (serialization != null) {
            skipIfNotExists {
                IMGLYFileReader(settingsList).also {
                    it.readJson(serialization, false)
                }
            }
        }
    }

    /**
     * Converts the editor result into a readable *JSONObject*.
     * @param video The output source of the video.
     * @param hasChanges Whether any export operations have been applied to the video.
     * @param serialization The serialization which stores the current state.
     * @return The converted *JSONObject*.
     */
    private fun createResult(video: Uri?, hasChanges: Boolean, serialization: Any?): JSONObject {
        val result = JSONObject()
        result.put("video", video)
        result.put("hasChanges", hasChanges)
        result.put("serialization", serialization)
        return result
    }

    override fun onRestoreStateForActivityResult(state: Bundle?, callbackContext: CallbackContext) {
        this.callback = callbackContext
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent) {
        if (requestCode == EDITOR_RESULT_ID) {
            when (resultCode) {
                Activity.RESULT_OK -> success(data)
                Activity.RESULT_CANCELED -> {
                    val nullValue: String? = null
                    callback?.success(nullValue) // return null
                }
                else -> callback?.error("Media error (code $resultCode)")
            }
        }
    }
}
