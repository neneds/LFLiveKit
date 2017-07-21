//
//  LFVideoCapture.h
//  LFLiveKit
//
//  Created by LaiFeng on 16/5/20.
//  Copyright © 2016年 LaiFeng All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>
#import "LFLiveVideoConfiguration.h"
#import "LFGPUImageBeautyFilter.h"
#import "LFGPUImageEmptyFilter.h"
#if __has_include(<GPUImage/GPUImage.h>)
#import <GPUImage/GPUImage.h>
#elif __has_include("GPUImage/GPUImage.h")
#import "GPUImage/GPUImage.h"
#else
#import "GPUImage.h"
#endif

@class LFVideoCapture;
/** LFVideoCapture callback videoData */
@protocol LFVideoCaptureDelegate <NSObject>
- (void)captureOutput:(nullable LFVideoCapture *)capture pixelBuffer:(nullable CVPixelBufferRef)pixelBuffer;
- (void)VideoCaptureOutput:(nullable AVCaptureOutput *)captureOutput didOutputSampleBuffer:(nullable CMSampleBufferRef)sampleBuffer fromConnection:(nullable AVCaptureConnection *)connection;
@end

@interface LFVideoCapture : NSObject

#pragma mark - Attribute
///=============================================================================
/// @name Attribute
///=============================================================================

@property (nonatomic, strong) GPUImageVideoCamera * _Nullable videoCamera;
@property (nonatomic, strong) LFGPUImageBeautyFilter * _Nullable beautyFilter;
@property (nonatomic, strong) GPUImageOutput<GPUImageInput> * _Nullable filter;
@property (nonatomic, strong) GPUImageCropFilter * _Nullable cropfilter;
@property (nonatomic, strong) GPUImageOutput<GPUImageInput> * _Nullable output;
@property (nonatomic, strong) GPUImageView * _Nullable gpuImageView;
@property (nonatomic, strong) LFLiveVideoConfiguration * _Nullable configuration;

@property (nonatomic, strong) GPUImageAlphaBlendFilter * _Nullable blendFilter;
@property (nonatomic, strong) GPUImageBrightnessFilter * _Nullable baseFilter;
@property (nonatomic, strong) GPUImageUIElement * _Nullable uiElementInput;

/** The delegate of the capture. captureData callback */
@property (nullable, nonatomic, weak) id<LFVideoCaptureDelegate> delegate;

/** The running control start capture or stop capture*/
@property (nonatomic, assign) BOOL running;

/** The preView will show OpenGL ES view*/
@property (null_resettable, nonatomic, strong) UIView *preView;

/** The captureDevicePosition control camraPosition ,default front*/
@property (nonatomic, assign) AVCaptureDevicePosition captureDevicePosition;

/** The beautyFace control capture shader filter empty or beautiy */
@property (nonatomic, assign) BOOL beautyFace;

/** The torch control capture flash is on or off */
@property (nonatomic, assign) BOOL torch;

/** The mirror control mirror of front camera is on or off */
@property (nonatomic, assign) BOOL mirror;

/** The beautyLevel control beautyFace Level, default 0.5, between 0.0 ~ 1.0 */
@property (nonatomic, assign) CGFloat beautyLevel;

/** The brightLevel control brightness Level, default 0.5, between 0.0 ~ 1.0 */
@property (nonatomic, assign) CGFloat brightLevel;

/** The torch control camera zoom scale default 1.0, between 1.0 ~ 3.0 */
@property (nonatomic, assign) CGFloat zoomScale;

/** The videoFrameRate control videoCapture output data count */
@property (nonatomic, assign) NSInteger videoFrameRate;

/*** The warterMarkView control whether the watermark is displayed or not ,if set ni,will remove watermark,otherwise add *.*/
@property (nonatomic, strong, nullable) UIView *warterMarkView;

/* The currentImage is videoCapture shot */
@property (nonatomic, strong, nullable) UIImage *currentImage;

/* The saveLocalVideo is save the local video */
@property (nonatomic, assign) BOOL saveLocalVideo;

/* The saveLocalVideoPath is save the local video  path */
@property (nonatomic, strong, nullable) NSURL *saveLocalVideoPath;

#pragma mark - Initializer
///=============================================================================
/// @name Initializer
///=============================================================================
- (nullable instancetype)init UNAVAILABLE_ATTRIBUTE;
+ (nullable instancetype)new UNAVAILABLE_ATTRIBUTE;

/**
   The designated initializer. Multiple instances with the same configuration will make the
   capture unstable.
 */
- (nullable instancetype)initWithVideoConfiguration:(nullable LFLiveVideoConfiguration *)configuration NS_DESIGNATED_INITIALIZER;

- (nullable AVCaptureSession *)getCaptureSession;

- (nullable AVCaptureDeviceInput *)getVideoInput;


- (nullable AVCaptureDeviceInput *)getAudioInput;


- (nullable AVCaptureAudioDataOutput *)getAudioOutput;


- (nullable AVCaptureVideoDataOutput *)getVideoOutput;

- (void)startMovieWriter;

- (void)stopMovieWriter;

@end
