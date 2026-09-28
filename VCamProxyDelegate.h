#import <AVFoundation/AVFoundation.h>
#import <CoreImage/CoreImage.h>

@interface VCamProxyDelegate : NSObject <AVCaptureVideoDataOutputSampleBufferDelegate>

@property (nonatomic, weak) id<AVCaptureVideoDataOutputSampleBufferDelegate> originalDelegate;

// For static image
@property (nonatomic, assign) CGImageRef fakeImageRef;

// For video playback
@property (nonatomic, strong) AVAssetReader *assetReader;
@property (nonatomic, strong) AVAssetReaderTrackOutput *assetReaderOutput;
@property (nonatomic, strong) NSString *currentMediaPath;
@property (nonatomic, strong) CIContext *ciContext;

- (void)loadFakeMediaFromPath:(NSString *)path;

@property (nonatomic, assign) BOOL isEnabled;

@end
