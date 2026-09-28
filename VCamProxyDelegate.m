#import "VCamProxyDelegate.h"
#import <UIKit/UIKit.h>

@implementation VCamProxyDelegate

static void PreferencesChangedCallback(CFNotificationCenterRef center, void *observer, CFStringRef name, const void *object, CFDictionaryRef userInfo) {
    // Notify all instances (in a real scenario, we might broadcast this)
    // For now, let's just rely on the next capture frame to reload if needed, or we can use a global settings manager.
    // To keep it simple, we'll post an internal NSNotification.
    [[NSNotificationCenter defaultCenter] postNotificationName:@"VCamReloadPrefs" object:nil];
}

+ (void)load {
    CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(), NULL, PreferencesChangedCallback, CFSTR("com.yourcompany.icamv1/ReloadPrefs"), NULL, CFNotificationSuspensionBehaviorDeliverImmediately);
}

- (instancetype)init {
    self = [super init];
    if (self) {
        self.ciContext = [CIContext contextWithOptions:nil];
        [self reloadPreferences:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(reloadPreferences:) name:@"VCamReloadPrefs" object:nil];
    }
    return self;
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    if (self.fakeImageRef) {
        CGImageRelease(self.fakeImageRef);
    }
}

- (void)reloadPreferences:(NSNotification *)notif {
    // Read from NSUserDefaults (sandboxed apps can usually read preference plists this way if they are set up correctly on rootless)
    NSUserDefaults *prefs = [[NSUserDefaults alloc] initWithSuiteName:@"com.yourcompany.icamv1"];
    
    // As a fallback, try to read the plist directly (works in some jailbreaks)
    NSDictionary *plistPrefs = [NSDictionary dictionaryWithContentsOfFile:@"/var/jb/var/mobile/Library/Preferences/com.yourcompany.icamv1.plist"];
    
    if (prefs || plistPrefs) {
        if ([prefs objectForKey:@"kEnabled"]) {
            self.isEnabled = [prefs boolForKey:@"kEnabled"];
        } else if (plistPrefs[@"kEnabled"]) {
            self.isEnabled = [plistPrefs[@"kEnabled"] boolValue];
        } else {
            self.isEnabled = YES;
        }
        
        NSString *customPath = [prefs stringForKey:@"kMediaPath"] ?: plistPrefs[@"kMediaPath"];
        
        NSFileManager *fm = [NSFileManager defaultManager];
        if (customPath && [fm fileExistsAtPath:customPath]) {
            [self loadFakeMediaFromPath:customPath];
            return;
        }
    } else {
        self.isEnabled = YES; // Default
    }
    
    // Fallback paths
    NSFileManager *fm = [NSFileManager defaultManager];
    NSArray *possiblePaths = @[
        @"/var/jb/Library/icamv1/fake_media.mp4",
        @"/var/jb/Library/icamv1/fake_media.mov",
        @"/var/jb/Library/icamv1/fake_media.jpg",
        @"/var/jb/Library/icamv1/fake_media.png",
        @"/Library/icamv1/fake_media.mp4",
        @"/Library/icamv1/fake_media.jpg"
    ];
    
    for (NSString *path in possiblePaths) {
        if ([fm fileExistsAtPath:path]) {
            [self loadFakeMediaFromPath:path];
            break;
        }
    }
}

- (void)loadFakeMediaFromPath:(NSString *)originalPath {
    NSFileManager *fm = [NSFileManager defaultManager];
    if (![fm fileExistsAtPath:originalPath]) {
        NSLog(@"[VCam] File không tồn tại: %@", originalPath);
        return;
    }
    
    // Copy to NSTemporaryDirectory to bypass Sandbox for mediaserverd
    NSString *fileName = [originalPath lastPathComponent];
    NSString *tempPath = [NSTemporaryDirectory() stringByAppendingPathComponent:fileName];
    
    // Remove old temp file if exists
    if ([fm fileExistsAtPath:tempPath]) {
        [fm removeItemAtPath:tempPath error:nil];
    }
    
    NSError *copyError = nil;
    [fm copyItemAtPath:originalPath toPath:tempPath error:&copyError];
    
    NSString *pathToLoad = copyError ? originalPath : tempPath;
    
    @synchronized(self) {
        if (self.fakeImageRef) {
            CGImageRelease(self.fakeImageRef);
            self.fakeImageRef = NULL;
        }
        
        if (self.assetReader) {
            [self.assetReader cancelReading];
            self.assetReader = nil;
            self.assetReaderOutput = nil;
        }
    }

    self.currentMediaPath = originalPath; // keep original path for reloading
    NSString *extension = [[originalPath pathExtension] lowercaseString];
    
    if ([extension isEqualToString:@"png"] || [extension isEqualToString:@"jpg"] || [extension isEqualToString:@"jpeg"]) {
        // Load ảnh tĩnh
        UIImage *image = [UIImage imageWithContentsOfFile:pathToLoad];
        if (image) {
            @synchronized(self) {
                self.fakeImageRef = CGImageRetain(image.CGImage);
            }
        }
    } 
    else if ([extension isEqualToString:@"mp4"] || [extension isEqualToString:@"mov"]) {
        // Load video
        NSURL *videoURL = [NSURL fileURLWithPath:pathToLoad];
        AVURLAsset *asset = [AVURLAsset URLAssetWithURL:videoURL options:nil];
        
        NSError *error = nil;
        AVAssetReader *reader = [AVAssetReader assetReaderWithAsset:asset error:&error];
        if (error) {
            NSLog(@"[VCam] Lỗi tạo AVAssetReader: %@", error);
            return;
        }
        
        NSArray *videoTracks = [asset tracksWithMediaType:AVMediaTypeVideo];
        if (videoTracks.count > 0) {
            AVAssetTrack *videoTrack = videoTracks[0];
            
            NSDictionary *outputSettings = @{
                (id)kCVPixelBufferPixelFormatTypeKey: @(kCVPixelFormatType_32BGRA)
            };
            
            AVAssetReaderTrackOutput *output = [AVAssetReaderTrackOutput assetReaderTrackOutputWithTrack:videoTrack outputSettings:outputSettings];
            [reader addOutput:output];
            [reader startReading];
            
            @synchronized(self) {
                self.assetReader = reader;
                self.assetReaderOutput = output;
            }
        }
    }
}

// Hàm này sẽ chạy liên tục khi camera hoạt động, t dùng nó để overwrite buffer
- (void)captureOutput:(AVCaptureOutput *)output didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer fromConnection:(AVCaptureConnection *)connection {
    @autoreleasepool {
        if (!self.isEnabled) {
            if ([self.originalDelegate respondsToSelector:@selector(captureOutput:didOutputSampleBuffer:fromConnection:)]) {
                [self.originalDelegate captureOutput:output didOutputSampleBuffer:sampleBuffer fromConnection:connection];
            }
            return;
        }
        
        CVPixelBufferRef targetPixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer);
        
        if (targetPixelBuffer) {
            
            // 1. Trường hợp là Video
            if (self.assetReader && self.assetReader.status == AVAssetReaderStatusReading) {
                CMSampleBufferRef videoSampleBuffer = [self.assetReaderOutput copyNextSampleBuffer];
                
                if (videoSampleBuffer) {
                    CVPixelBufferRef sourcePixelBuffer = CMSampleBufferGetImageBuffer(videoSampleBuffer);
                    if (sourcePixelBuffer) {
                        [self overwriteTarget:targetPixelBuffer withSource:sourcePixelBuffer];
                    }
                    CFRelease(videoSampleBuffer);
                } else {
                    // Hết video -> Loop lại
                    [self.assetReader cancelReading];
                    if (self.currentMediaPath) {
                        [self loadFakeMediaFromPath:self.currentMediaPath];
                    }
                }
            }
            
            // 2. Trường hợp là Ảnh tĩnh
            else if (self.fakeImageRef) {
                CIImage *ciImage = [CIImage imageWithCGImage:self.fakeImageRef];
                if (ciImage && self.ciContext) {
                    size_t targetWidth = CVPixelBufferGetWidth(targetPixelBuffer);
                    size_t targetHeight = CVPixelBufferGetHeight(targetPixelBuffer);
                    
                    // Scale image to fill target buffer
                    CGFloat scaleX = (CGFloat)targetWidth / ciImage.extent.size.width;
                    CGFloat scaleY = (CGFloat)targetHeight / ciImage.extent.size.height;
                    CGFloat scale = MAX(scaleX, scaleY);
                    
                    CIImage *scaledImage = [ciImage imageByApplyingTransform:CGAffineTransformMakeScale(scale, scale)];
                    
                    // Center crop if needed
                    CGFloat xOffset = (scaledImage.extent.size.width - targetWidth) / 2.0;
                    CGFloat yOffset = (scaledImage.extent.size.height - targetHeight) / 2.0;
                    CIImage *croppedImage = [scaledImage imageByCroppingToRect:CGRectMake(xOffset, yOffset, targetWidth, targetHeight)];
                    
                    [self.ciContext render:croppedImage toCVPixelBuffer:targetPixelBuffer];
                }
            }
        }

        // Forward buffer (đã bị fake) cho app
        if ([self.originalDelegate respondsToSelector:@selector(captureOutput:didOutputSampleBuffer:fromConnection:)]) {
            [self.originalDelegate captureOutput:output didOutputSampleBuffer:sampleBuffer fromConnection:connection];
        }
    }
}

- (void)overwriteTarget:(CVPixelBufferRef)targetBuffer withSource:(CVPixelBufferRef)sourceBuffer {
    if (!self.ciContext) return;
    
    CIImage *sourceImage = [CIImage imageWithCVPixelBuffer:sourceBuffer];
    if (!sourceImage) return;
    
    size_t targetWidth = CVPixelBufferGetWidth(targetBuffer);
    size_t targetHeight = CVPixelBufferGetHeight(targetBuffer);
    
    // Calculate aspect fill
    CGFloat scaleX = (CGFloat)targetWidth / sourceImage.extent.size.width;
    CGFloat scaleY = (CGFloat)targetHeight / sourceImage.extent.size.height;
    CGFloat scale = MAX(scaleX, scaleY);
    
    CIImage *scaledImage = [sourceImage imageByApplyingTransform:CGAffineTransformMakeScale(scale, scale)];
    
    // Crop to center
    CGFloat xOffset = (scaledImage.extent.size.width - targetWidth) / 2.0;
    CGFloat yOffset = (scaledImage.extent.size.height - targetHeight) / 2.0;
    CIImage *croppedImage = [scaledImage imageByCroppingToRect:CGRectMake(xOffset, yOffset, targetWidth, targetHeight)];
    
    // Render to target buffer (CIContext automatically handles CVPixelBuffer locking and colorspace)
    [self.ciContext render:croppedImage toCVPixelBuffer:targetBuffer];
}

// Forward các method protocol khác
- (BOOL)respondsToSelector:(SEL)aSelector {
    if (aSelector == @selector(captureOutput:didOutputSampleBuffer:fromConnection:)) return YES;
    return [self.originalDelegate respondsToSelector:aSelector];
}

- (id)forwardingTargetForSelector:(SEL)aSelector {
    return self.originalDelegate;
}

@end
