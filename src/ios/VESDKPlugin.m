#import "VESDKPlugin.h"
#import <Photos/Photos.h>
#import <objc/message.h>
@import VideoEditorSDK;

@interface NSDictionary (VESDK_IMGLY_Category)

- (nullable id)vesdk_getValueForKeyPath:(nonnull NSString *)keyPath default:(nullable id)defaultValue;
+ (nullable id)vesdk_getValue:(nullable NSDictionary *)dictionary
              valueForKeyPath:(nonnull NSString *)keyPath
                      default:(nullable id)defaultValue;

@end

@interface VESDKPlugin () <PESDKVideoEditViewControllerDelegate>
@property(strong) CDVInvokedUrlCommand *lastCommand;
@end

@implementation VESDKPlugin

#pragma mark - Cordova

/**
 Sends a result back to Cordova.

 @param result
 */
- (void)finishCommandWithResult:(CDVPluginResult *)result {
  if (self.lastCommand != nil) {
    [self.commandDelegate sendPluginResult:result callbackId:self.lastCommand.callbackId];
    self.lastCommand = nil;
  }
}

#pragma mark - Public API

static IMGLYConfigurationBlock _configureWithBuilder = nil;

+ (IMGLYConfigurationBlock)configureWithBuilder {
  return _configureWithBuilder;
}

+ (void)setConfigureWithBuilder:(IMGLYConfigurationBlock)configurationBlock {
  _configureWithBuilder = configurationBlock;
}

static CDV_VESDKWillPresentBlock _willPresentVideoEditViewController = nil;

+ (CDV_VESDKWillPresentBlock)willPresentVideoEditViewController {
  return _willPresentVideoEditViewController;
}

+ (void)setWillPresentVideoEditViewController:(CDV_VESDKWillPresentBlock)willPresentBlock {
  _willPresentVideoEditViewController = willPresentBlock;
}

const struct VESDK_IMGLY_Constants VESDK_IMGLY = { .kErrorUnableToUnlock = @"E_UNABLE_TO_UNLOCK",
                                                   .kErrorUnableToLoad = @"E_UNABLE_TO_LOAD",
                                                   .kErrorUnableToExport = @"E_UNABLE_TO_EXPORT",

                                                   .kExportTypeFileURL = @"file-url",
                                                   .kExportTypeDataURL = @"data-url",
                                                   .kExportTypeObject = @"object" };

- (void)presentComposition:(CDVInvokedUrlCommand *)command {
  if (self.lastCommand == nil) {
    self.lastCommand = command;
    NSDictionary *options = command.arguments[0];
    NSDictionary *configuration = options[@"configuration"];
    NSDictionary *serialization = options[@"serialization"];
    NSDictionary *videoSize = options[@"size"];
    NSArray<NSString *> *videos = options[@"videos"];

    PESDKVideo *video;
    CGSize compositionSize = [self retrieveSize:videoSize];
    NSMutableArray<AVAsset *> *assets = [[NSMutableArray alloc] init];

    if (videos.count > 0) {
      NSMutableArray<NSString *> *array = [[NSMutableArray alloc] init];
      for (NSString *video in videos) {
        if ([video isKindOfClass:[NSNull class]] == false) {
          NSURL *appFolderUrl = [[NSBundle mainBundle] resourceURL];
          NSString *videoPath = [video stringByReplacingOccurrencesOfString:@"imgly_asset:///"
                                                                 withString:appFolderUrl.absoluteString];
          [array addObject:videoPath];
        }
      }
      NSArray *copiedArray = [array mutableCopy];

      for (NSString *video in copiedArray) {
        NSURL *url = [[NSURL alloc] initWithString:video];
        AVAsset *asset = [AVAsset assetWithURL:url];
        [assets addObject:asset];
      }
    }

    if (CGSizeEqualToSize(CGSizeZero, compositionSize)) {
      if (videos.count == 0) {
        NSString *message = @"An editor without any videos must have a valid composition size.";
        CDVPluginResult *result = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:message];
        [self closeControllerWithResult:result];
        return;
      }
      video = [[PESDKVideo alloc] initWithAssets:assets];
    } else {
      if (compositionSize.height <= 0 || compositionSize.width <= 0) {
        NSString *message = @"Invalid video size: width and height must be greater than zero";
        CDVPluginResult *result = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:message];
        [self closeControllerWithResult:result];
        return;
      }
      if (videos.count == 0) {
        video = [[PESDKVideo alloc] initWithSize:compositionSize];
      } else {
        video = [[PESDKVideo alloc] initWithAssets:assets size:compositionSize];
      }
    }
    [self startEditor:video configuration:configuration serialization:serialization];
  }
}

- (CGSize)retrieveSize:(NSDictionary *)dictionary {
  NSNumber *width = [dictionary valueForKey:@"width"];
  NSNumber *height = [dictionary valueForKey:@"height"];
  if ([width isKindOfClass:[NSNull class]] || [height isKindOfClass:[NSNull class]] || width == nil || height == nil) {
    return CGSizeZero;
  } else {
    return CGSizeMake(width.doubleValue, height.doubleValue);
  }
}

- (void)present:(CDVInvokedUrlCommand *)command {

  if (self.lastCommand == nil) {
    self.lastCommand = command;
    NSDictionary *options = command.arguments[0];
    NSDictionary *configuration = options[@"configuration"];
    NSDictionary *serialization = options[@"serialization"];
    NSString *video = options[@"path"];

    if ([video isKindOfClass:[NSNull class]] == false) {
      NSURL *appFolderUrl = [[NSBundle mainBundle] resourceURL];
      NSString *videoPath = [video stringByReplacingOccurrencesOfString:@"imgly_asset:///"
                                                             withString:appFolderUrl.absoluteString];
      NSURL *videoURL = [[NSURL alloc] initWithString:videoPath];
      PESDKVideo *video = [[PESDKVideo alloc] initWithURL:videoURL];
      [self startEditor:video configuration:configuration serialization:serialization];
    } else {
      NSString *message = @"The editor must not be initialized without a video.";
      CDVPluginResult *result = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:message];
      [self closeControllerWithResult:result];
    }
  }
}

- (void)startEditor:(PESDKVideo *)video
      configuration:(nullable NSDictionary *)configurationDict
      serialization:(nullable NSDictionary *)serializationDict {

  // Add the app folder path to the beginning of the image path
  NSURL *appFolderUrl = [[NSBundle mainBundle] resourceURL];

  // Convert the pathes form `imgly_asset:///` to a valid pathes
  NSDictionary *withConfiguration;
  NSError *jsonConversionError;
  NSString *jsonString;

  // Convert NSDictionary to JSON string
  if (configurationDict != nil) {
    NSData *jsonTestData = [NSJSONSerialization dataWithJSONObject:configurationDict
                                                           options:NSJSONWritingPrettyPrinted
                                                             error:&jsonConversionError];
    if (jsonConversionError != nil) {
      NSString *message = [NSString stringWithFormat:@"Error while decoding configuration: %@", jsonConversionError];
      CDVPluginResult *result = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:message];
      [self closeControllerWithResult:result];
    } else {
      // here comes the magic, convert the temo schema to a valid iOS URL and
      // also fix `\\/` in the pathes
      jsonString = [[NSString alloc] initWithData:jsonTestData encoding:NSUTF8StringEncoding];
      jsonString = [jsonString stringByReplacingOccurrencesOfString:@"\\/" withString:@"/"];
      jsonString = [jsonString stringByReplacingOccurrencesOfString:@"imgly_asset:///"
                                                         withString:appFolderUrl.absoluteString];
    }
    // convert back the configuration from json to dictionary
    NSData *jsonData = [jsonString dataUsingEncoding:NSUTF8StringEncoding];
    NSError *err;
    withConfiguration = (NSDictionary *)[NSJSONSerialization JSONObjectWithData:jsonData
                                                                        options:NSJSONReadingMutableContainers
                                                                          error:&err];
    if (err != nil) {
      NSString *message = [NSString stringWithFormat:@"Error while decoding configuration: %@", err];
      CDVPluginResult *result = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:message];
      [self closeControllerWithResult:result];
    }
  }
  __block NSError *error = nil;

  IMGLYMediaEditViewControllerBlock createMediaEditViewController = ^PESDKMediaEditViewController *_Nullable(
    PESDKConfiguration *_Nonnull configuration, NSData *_Nullable serializationData) {

    PESDKPhotoEditModel *photoEditModel = [[PESDKPhotoEditModel alloc] init];

    if (serializationData != nil) {
      PESDKDeserializationResult *deserializationResult =
        [PESDKDeserializer deserializeWithData:serializationData
                               imageDimensions:video.size
                                  assetCatalog:configuration.assetCatalog];
      photoEditModel = deserializationResult.model ?: photoEditModel;
    }

    PESDKVideoEditViewController *videoEditViewController =
      [PESDKVideoEditViewController videoEditViewControllerWithVideoAsset:video
                                                            configuration:configuration
                                                           photoEditModel:photoEditModel];

    videoEditViewController.modalPresentationStyle = UIModalPresentationFullScreen;
    videoEditViewController.delegate = self;
    CDV_VESDKWillPresentBlock willPresentVideoEditViewController = VESDKPlugin.willPresentVideoEditViewController;
    if (willPresentVideoEditViewController != nil) {
      willPresentVideoEditViewController(videoEditViewController);
    }
    return videoEditViewController;
  };

  NSData *serializationData = nil;
  if (serializationDict != nil) {
    serializationData = [NSJSONSerialization dataWithJSONObject:serializationDict options:kNilOptions error:&error];
    if (error != nil) {
      NSString *message = [NSString stringWithFormat:@"Invalid serialization: %@", error];
      CDVPluginResult *result = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:message];
      [self closeControllerWithResult:result];
      return;
    }
  }

  PESDKAssetCatalog *assetCatalog = PESDKAssetCatalog.defaultItems;
  PESDKConfiguration *configuration =
    [[PESDKConfiguration alloc] initWithBuilder:^(PESDKConfigurationBuilder *_Nonnull builder) {
      builder.assetCatalog = assetCatalog;
      [builder configureFromDictionary:withConfiguration error:&error];
    }];
  if (error != nil) {
    NSString *message = [NSString stringWithFormat:@"Error while decoding configuration: %@", error];
    CDVPluginResult *result = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:message];
    [self closeControllerWithResult:result];
    return;
  }
  IMGLYUTIBlock getUTI = ^CFStringRef _Nonnull(PESDKConfiguration *_Nonnull configuration) {
    return configuration.videoEditViewControllerOptions.videoContainerFormatUTI;
  };

  // Set default values if necessary
  id valueExportType = [NSDictionary vesdk_getValue:withConfiguration
                                    valueForKeyPath:@"export.image.exportType"
                                            default:VESDK_IMGLY.kExportTypeFileURL];
  id valueExportFile =
    [NSDictionary vesdk_getValue:withConfiguration
                 valueForKeyPath:@"export.filename"
                         default:[NSString stringWithFormat:@"imgly-export/%@", [[NSUUID UUID] UUIDString]]];
  id valueSerializationEnabled = [NSDictionary vesdk_getValue:withConfiguration
                                              valueForKeyPath:@"export.serialization.enabled"
                                                      default:@(NO)];
  id valueSerializationType = [NSDictionary vesdk_getValue:withConfiguration
                                           valueForKeyPath:@"export.serialization.exportType"
                                                   default:VESDK_IMGLY.kExportTypeFileURL];
  id valueSerializationFile = [NSDictionary vesdk_getValue:withConfiguration
                                           valueForKeyPath:@"export.serialization.filename"
                                                   default:valueExportFile];
  id valueSerializationEmbedImage = [NSDictionary vesdk_getValue:withConfiguration
                                                 valueForKeyPath:@"export.serialization.embedSourceImage"
                                                         default:@(NO)];

  NSString *exportType = valueExportType;
  NSURL *exportFile = [VESDKConvert VESDK_IMGLY_ExportFileURL:valueExportFile withExpectedUTI:getUTI(configuration)];
  BOOL serializationEnabled = [valueSerializationEnabled boolValue];
  NSString *serializationType = valueSerializationType;
  NSURL *serializationFile = [VESDKConvert VESDK_IMGLY_ExportFileURL:valueSerializationFile
                                                     withExpectedUTI:kUTTypeJSON];
  BOOL serializationEmbedImage = [valueSerializationEmbedImage boolValue];

  // Make sure that the export settings are valid
  if ((exportType == nil) || (exportFile == nil && [exportType isEqualToString:VESDK_IMGLY.kExportTypeFileURL]) ||
      (serializationFile == nil && [serializationType isEqualToString:VESDK_IMGLY.kExportTypeFileURL])) {
    CDVPluginResult *result = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR
                                                messageAsString:@"Invalid export configuration"];
    [self closeControllerWithResult:result];
    return;
  }

  // Update configuration
  NSMutableDictionary *updatedDictionary = [NSMutableDictionary dictionaryWithDictionary:withConfiguration];
  NSMutableDictionary *exportDictionary = [NSMutableDictionary
    dictionaryWithDictionary:[NSDictionary vesdk_getValue:updatedDictionary valueForKeyPath:@"export" default:@{}]];
  [exportDictionary setValue:exportFile.absoluteString forKeyPath:@"filename"];
  [updatedDictionary setValue:exportDictionary forKeyPath:@"export"];
  // Create intermediate directories for export if necessary
  // TODO: The next PESDK for iOS release (~10.13.0) will also ensure this
  // so that this code can be removed next time we raise the minimum
  // required PESDK for iOS version.
  [[NSFileManager defaultManager] createDirectoryAtURL:exportFile.URLByDeletingLastPathComponent
                           withIntermediateDirectories:YES
                                            attributes:nil
                                                 error:&error];
  if (error != nil) {
    NSString *message = [NSString stringWithFormat:@"Error while preparing export file: %@", error];
    CDVPluginResult *result = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:message];
    [self closeControllerWithResult:result];
    return;
  }
  configuration = [[PESDKConfiguration alloc] initWithBuilder:^(PESDKConfigurationBuilder *_Nonnull builder) {
    builder.assetCatalog = assetCatalog;
    [builder configureFromDictionary:updatedDictionary error:&error];
    IMGLYConfigurationBlock configureWithBuilder = VESDKPlugin.configureWithBuilder;
    if (configureWithBuilder != nil) {
      configureWithBuilder(builder);
    }
  }];
  if (error != nil) {
    NSString *message = [NSString stringWithFormat:@"Error while updating configuration: %@", error];
    CDVPluginResult *result = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:message];
    [self closeControllerWithResult:result];
    return;
  }

  PESDKMediaEditViewController *mediaEditViewController =
    createMediaEditViewController(configuration, serializationData);
  if (mediaEditViewController == nil) {
    return;
  }

  self.exportType = exportType;
  self.exportFile = exportFile;
  self.serializationEnabled = serializationEnabled;
  self.serializationType = serializationType;
  self.serializationFile = serializationFile;
  self.serializationEmbedImage = serializationEmbedImage;
  self.mediaEditViewController = mediaEditViewController;

  [self.viewController presentViewController:self.mediaEditViewController animated:YES completion:nil];
}

- (void)unlockWithLicense:(nonnull CDVInvokedUrlCommand *)json {
  NSURL *appFolderUrl = [[NSBundle mainBundle] resourceURL];
  NSString *tempLicensePath = json.arguments[0];
  NSString *validPath = [tempLicensePath stringByReplacingOccurrencesOfString:@"imgly_asset:///"
                                                                   withString:appFolderUrl.absoluteString];
  NSURL *url = [NSURL URLWithString:validPath];
  NSError *error = nil;
  [VESDK unlockWithLicenseFromURL:url error:&error];
  [self handleLicenseError:error];
}

- (void)handleLicenseError:(nullable NSError *)error {
  self.licenseError = nil;
  if (error != nil) {
    if ([error.domain isEqualToString:@"ImglyKit.IMGLY.Error"]) {
      switch (error.code) {
      case 3:
        NSLog(@"%@: %@", NSStringFromClass(self.class), error.localizedDescription);
        break;
      default:
        self.licenseError = error;
        NSLog(@"%@: %@", NSStringFromClass(self.class), error.localizedDescription);
        break;
      }
    } else {
      self.licenseError = error;
      NSLog(@"Error while unlocking with license: %@", error);
    }
  }
}

/**
 Closes all PESDK view controllers and sends a result
 back to Cordova.

 @param result The result to be sent.
 */
- (void)closeControllerWithResult:(CDVPluginResult *)result {
  [self dismiss:self.mediaEditViewController
       animated:YES
     completion:^{
       [self finishCommandWithResult:result];
     }];
}

- (void)dismiss:(nullable PESDKMediaEditViewController *)mediaEditViewController
       animated:(BOOL)animated
     completion:(nullable IMGLYCompletionBlock)completion {
  if (mediaEditViewController != self.mediaEditViewController) {
    NSLog(@"Unregistered %@", NSStringFromClass(mediaEditViewController.class));
  }

  self.exportType = nil;
  self.exportFile = nil;
  self.serializationEnabled = NO;
  self.serializationType = nil;
  self.serializationFile = nil;
  self.serializationEmbedImage = NO;
  self.mediaEditViewController = nil;

  [mediaEditViewController.presentingViewController dismissViewControllerAnimated:animated completion:completion];
}

#pragma mark - PESDKPhotoEditViewControllerDelegate

// The PhotoEditViewController did save an image.
- (void)videoEditViewController:(PESDKVideoEditViewController *)videoEditViewController
        didFinishWithVideoAtURL:(nullable NSURL *)url {

  NSError *error = nil;
  id serialization = nil;

  if (self.serializationEnabled) {
    NSData *serializationData = [videoEditViewController serializedSettings];

    if ([self.serializationType isEqualToString:VESDK_IMGLY.kExportTypeFileURL]) {

      if ([serializationData VESDK_IMGLY_writeToURL:self.serializationFile
                      andCreateDirectoryIfNecessary:YES
                                              error:&error]) {
        serialization = self.serializationFile.absoluteString;
      }
    } else if ([self.serializationType isEqualToString:VESDK_IMGLY.kExportTypeObject]) {

      serialization = [NSJSONSerialization JSONObjectWithData:serializationData options:kNilOptions error:&error];
    }
  }

  if (error == nil) {
    CDVPluginResult *resultAsync;
    NSDictionary *payload = [NSDictionary
      dictionaryWithObjectsAndKeys:(url != nil) ? url.absoluteString : [NSNull null], @"video",
                                   @(videoEditViewController.hasChanges), @"hasChanges",
                                   (serialization != nil) ? serialization : [NSNull null], @"serialization", nil];
    resultAsync = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsDictionary:payload];

    [self closeControllerWithResult:resultAsync];
  } else {
    CDVPluginResult *result = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR
                                                messageAsString:@"Unable to export video or serialization."];
    [self closeControllerWithResult:result];
  }
}

// The VideoEditViewController was cancelled.
- (void)videoEditViewControllerDidCancel:(PESDKVideoEditViewController *)videoEditViewController {
  CDVPluginResult *result = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK];
  [self closeControllerWithResult:result];
}

// The VideoEditViewController could not create an image.
- (void)videoEditViewControllerDidFailToGenerateVideo:(PESDKVideoEditViewController *)videoEditViewController {
  CDVPluginResult *result = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR
                                              messageAsString:@"Unable to generate video."];
  [self closeControllerWithResult:result];
}
@end

@implementation NSDictionary (VESDK_IMGLY_Category)

//// start extract value from path
- (nullable id)vesdk_getValueForKeyPath:(nonnull NSString *)keyPath default:(nullable id)defaultValue {
  id value = [self valueForKeyPath:keyPath];
  if (value == nil || value == [NSNull null]) {
    return defaultValue;
  } else {
    return value;
  }
}

+ (nullable id)vesdk_getValue:(nullable NSDictionary *)dictionary
              valueForKeyPath:(nonnull NSString *)keyPath
                      default:(nullable id)defaultValue {
  if (dictionary == nil) {
    return defaultValue;
  }
  return [dictionary vesdk_getValueForKeyPath:keyPath default:defaultValue];
}
//// end extract value from path
@end

@implementation VESDKConvert

+ (nullable VESDK_IMGLY_ExportURL *)VESDK_IMGLY_ExportURL:(nullable id)json {
  // This code is identical to the implementation of
  // `+ (NSURL *)NSURL:(id)json`
  // except that it creates a path to a temporary file instead of assuming a
  // resource path as last resort.

  NSString *path = json;
  if (!path) {
    return nil;
  }

  @try { // NSURL has a history of crashing with bad input, so let's be safe

    NSURL *URL = [NSURL URLWithString:path];
    if (URL.scheme) { // Was a well-formed absolute URL
      return URL;
    }

    // Check if it has a scheme
    if ([path rangeOfString:@":"].location != NSNotFound) {
      NSMutableCharacterSet *urlAllowedCharacterSet = [NSMutableCharacterSet new];
      [urlAllowedCharacterSet formUnionWithCharacterSet:[NSCharacterSet URLUserAllowedCharacterSet]];
      [urlAllowedCharacterSet formUnionWithCharacterSet:[NSCharacterSet URLPasswordAllowedCharacterSet]];
      [urlAllowedCharacterSet formUnionWithCharacterSet:[NSCharacterSet URLHostAllowedCharacterSet]];
      [urlAllowedCharacterSet formUnionWithCharacterSet:[NSCharacterSet URLPathAllowedCharacterSet]];
      [urlAllowedCharacterSet formUnionWithCharacterSet:[NSCharacterSet URLQueryAllowedCharacterSet]];
      [urlAllowedCharacterSet formUnionWithCharacterSet:[NSCharacterSet URLFragmentAllowedCharacterSet]];
      path = [path stringByAddingPercentEncodingWithAllowedCharacters:urlAllowedCharacterSet];
      URL = [NSURL URLWithString:path];
      if (URL) {
        return URL;
      }
    }

    // Assume that it's a local path
    path = path.stringByRemovingPercentEncoding;
    if ([path hasPrefix:@"~"]) {
      // Path is inside user directory
      path = path.stringByExpandingTildeInPath;
    } else if (!path.absolutePath) {
      // Create a path to a temporary file
      path = [NSTemporaryDirectory() stringByAppendingPathComponent:path];
    }
    if (!(URL = [NSURL fileURLWithPath:path isDirectory:NO])) {
      NSLog(json, @"a valid URL");
    }
    return URL;
  } @catch (__unused NSException *e) {
    NSLog(json, @"a valid URL");
    return nil;
  }
}

+ (nullable VESDK_IMGLY_ExportFileURL *)VESDK_IMGLY_ExportFileURL:(nullable id)json
                                                  withExpectedUTI:(nonnull CFStringRef)expectedUTI {
  // This code is similar to the implementation of
  // `+ (RCTFileURL *)RCTFileURL:(id)json`.

  NSURL *fileURL = [self VESDK_IMGLY_ExportURL:json];
  if (!fileURL.fileURL) {
    NSLog(@"URI must be a local file, '%@' isn't.", fileURL);
    return nil;
  }

  // Append correct file extension if necessary
  NSString *fileUTI = CFBridgingRelease(UTTypeCreatePreferredIdentifierForTag(
    kUTTagClassFilenameExtension, (__bridge CFStringRef)(fileURL.pathExtension.lowercaseString), nil));
  if (fileUTI == nil || !UTTypeEqual((__bridge CFStringRef)(fileUTI), expectedUTI)) {
    NSString *extension = CFBridgingRelease(UTTypeCopyPreferredTagWithClass(expectedUTI, kUTTagClassFilenameExtension));
    if (extension != nil) {
      fileURL = [fileURL URLByAppendingPathExtension:extension];
    }
  }

  BOOL isDirectory = false;
  if ([[NSFileManager defaultManager] fileExistsAtPath:fileURL.path isDirectory:&isDirectory]) {
    if (isDirectory) {
      NSLog(@"File '%@' must not be a directory.", fileURL);
    } else {
      NSLog(@"File '%@' will be overwritten on export.", fileURL);
    }
  }
  return fileURL;
}

@end

@implementation NSData (VESDK_IMGLY_Category)

- (BOOL)VESDK_IMGLY_writeToURL:(nonnull NSURL *)fileURL
  andCreateDirectoryIfNecessary:(BOOL)createDirectory
                          error:(NSError *_Nullable *_Nullable)error {
  if (createDirectory) {
    if (![[NSFileManager defaultManager] createDirectoryAtURL:fileURL.URLByDeletingLastPathComponent
                                  withIntermediateDirectories:YES
                                                   attributes:nil
                                                        error:error]) {
      return NO;
    }
  }
  return [self writeToURL:fileURL options:NSDataWritingAtomic error:error];
}

@end
