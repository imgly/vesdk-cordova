#import <Cordova/CDV.h>
#import <MobileCoreServices/MobileCoreServices.h>

@import VideoEditorSDK;
@import Foundation;

@interface VESDKPlugin : CDVPlugin

typedef void (^IMGLYConfigurationBlock)(
    PESDKConfigurationBuilder *_Nonnull builder);
typedef PESDKMediaEditViewController *_Nullable (
    ^IMGLYMediaEditViewControllerBlock)(
    PESDKConfiguration *_Nonnull configuration,
    NSData *_Nullable serializationData);
typedef CFStringRef _Nonnull (^IMGLYUTIBlock)(
    PESDKConfiguration *_Nonnull configuration);
typedef void (^IMGLYCompletionBlock)(void);

typedef void (^CDV_VESDKWillPresentBlock)(
    PESDKVideoEditViewController *_Nonnull videoEditViewController);

@property(class, strong, atomic, nullable)
    CDV_VESDKWillPresentBlock willPresentVideoEditViewController;

@property(class, strong, atomic, nullable)
    IMGLYConfigurationBlock configureWithBuilder;

@property(strong, atomic, nullable) NSError *licenseError;
@property(strong, atomic, nullable) NSString *exportType;
@property(strong, atomic, nullable) NSURL *exportFile;
@property(atomic) BOOL serializationEnabled;
@property(strong, atomic, nullable) NSString *serializationType;
@property(strong, atomic, nullable) NSURL *serializationFile;
@property(atomic) BOOL serializationEmbedImage;
@property(strong, atomic, nullable)
    PESDKMediaEditViewController *mediaEditViewController;

- (void)present:(CDVInvokedUrlCommand *_Nonnull)command;
- (void)unlockWithLicense:(nonnull id)json;

extern const struct VESDK_IMGLY_Constants {
  NSString *_Nonnull const kErrorUnableToUnlock;
  NSString *_Nonnull const kErrorUnableToLoad;
  NSString *_Nonnull const kErrorUnableToExport;

  NSString *_Nonnull const kExportTypeFileURL;
  NSString *_Nonnull const kExportTypeDataURL;
  NSString *_Nonnull const kExportTypeObject;
} VESDK_IMGLY;

@end

@interface VESDKConvert : NSObject

typedef NSURL VESDK_IMGLY_ExportURL;
typedef NSURL VESDK_IMGLY_ExportFileURL;

+ (nullable VESDK_IMGLY_ExportURL *)VESDK_IMGLY_ExportURL:(nullable id)json;
+ (nullable VESDK_IMGLY_ExportFileURL *)
    VESDK_IMGLY_ExportFileURL:(nullable id)json
              withExpectedUTI:(nonnull CFStringRef)expectedUTI;

@end

@interface NSData (VESDK_IMGLY_Category)

- (BOOL)VESDK_IMGLY_writeToURL:(nonnull NSURL *)fileURL
    andCreateDirectoryIfNecessary:(BOOL)createDirectory
                            error:(NSError *_Nullable *_Nullable)error;

@end
