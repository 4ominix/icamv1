#import <AVFoundation/AVFoundation.h>
#import "VCamProxyDelegate.h"
#import <objc/runtime.h>

static const void *kVCamProxyKey = &kVCamProxyKey;

// 1. Hook vào luồng xuất data của camera (Core)
%hook AVCaptureVideoDataOutput

- (void)setSampleBufferDelegate:(id<AVCaptureVideoDataOutputSampleBufferDelegate>)sampleBufferDelegate queue:(dispatch_queue_t)sampleBufferCallbackQueue {
    
    // Create a new proxy for this output if it doesn't exist
    VCamProxyDelegate *proxy = objc_getAssociatedObject(self, kVCamProxyKey);
    if (!proxy) {
        proxy = [[VCamProxyDelegate alloc] init];
        objc_setAssociatedObject(self, kVCamProxyKey, proxy, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    
    proxy.originalDelegate = sampleBufferDelegate;
    
    // Set proxy as the actual delegate
    %orig(proxy, sampleBufferCallbackQueue);
}

// Bắt buộc output phải là BGRA (thay vì YUV mặc định của iOS) để CoreGraphics vẽ đè lên được mà không bị lỗi màu/crash
- (void)setVideoSettings:(NSDictionary *)videoSettings {
    NSMutableDictionary *newSettings = videoSettings ? [videoSettings mutableCopy] : [NSMutableDictionary dictionary];
    newSettings[(id)kCVPixelBufferPixelFormatTypeKey] = @(kCVPixelFormatType_32BGRA);
    %orig(newSettings);
}

%end
