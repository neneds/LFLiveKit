//
//  LFVideoCapture.m
//  LFLiveKit
//
//  Created by LaiFeng on 16/5/20.
//  Copyright © 2016年 LaiFeng All rights reserved.
//

#import "LFVideoCapture.h"
#import "LFGPUImageBeautyFilter.h"
#import "LFGPUImageEmptyFilter.h"
#import "GPUImageUIElement.h"

#if __has_include(<GPUImage/GPUImage.h>)
#import <GPUImage/GPUImage.h>
#elif __has_include("GPUImage/GPUImage.h")
#import "GPUImage/GPUImage.h"
#else
#import "GPUImage.h"
#endif

@interface LFVideoCapture () <GPUImageVideoCameraDelegate>

@property (nonatomic, strong) GPUImageVideoCamera *videoCamera;
@property (nonatomic, strong) LFGPUImageBeautyFilter *beautyFilter;
@property (nonatomic, strong) GPUImageOutput<GPUImageInput> *filter;
@property (nonatomic, strong) GPUImageCropFilter *cropfilter;
@property (nonatomic, strong) GPUImageOutput<GPUImageInput> *output;
@property (nonatomic, strong) GPUImageView *gpuImageView;
@property (nonatomic, strong) LFLiveVideoConfiguration *configuration;

@property (nonatomic, strong) GPUImageAlphaBlendFilter *blendFilter;
@property (nonatomic, strong) GPUImageUIElement *uiElementInput;
@property (nonatomic, strong) UIView *waterMarkContentView;

@property (nonatomic, strong) GPUImageMovieWriter *movieWriter;
@property (nonatomic) BOOL *isWatermarkActive;


@property (atomic, strong) AVCaptureSession *_captureSession;
@property (atomic, strong) AVCaptureDeviceInput *videoInput;
@property (atomic, strong) AVCaptureVideoDataOutput *videoOutput;
@property (atomic, strong) AVCaptureDeviceInput *audioInput;
@property (atomic, strong) AVCaptureAudioDataOutput  *audioOutput;



@end

@implementation LFVideoCapture
@synthesize torch = _torch;
@synthesize beautyLevel = _beautyLevel;
@synthesize brightLevel = _brightLevel;
@synthesize zoomScale = _zoomScale;

#pragma mark -- LifeCycle
- (instancetype)initWithVideoConfiguration:(LFLiveVideoConfiguration *)configuration {
    if (self = [super init]) {
        _configuration = configuration;

        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(willEnterBackground:) name:UIApplicationWillResignActiveNotification object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(willEnterForeground:) name:UIApplicationDidBecomeActiveNotification object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(statusBarChanged:) name:UIApplicationWillChangeStatusBarOrientationNotification object:nil];
        
        self.beautyFace = NO;
        self.beautyLevel = 0.5;
        self.brightLevel = 0.5;
        self.zoomScale = 1.0;
        self.mirror = YES;
        self.isWatermarkActive = NO;
        [self setSaveLocalVideo:YES];
        
        if(!_videoCamera){
            _videoCamera = [[GPUImageVideoCamera alloc] initWithSessionPreset:_configuration.avSessionPreset cameraPosition:AVCaptureDevicePositionBack];
            _videoCamera.outputImageOrientation = _configuration.outputImageOrientation;
            _videoCamera.horizontallyMirrorFrontFacingCamera = NO;
            _videoCamera.horizontallyMirrorRearFacingCamera = NO;
            _videoCamera.frameRate = (int32_t)_configuration.videoFrameRate;
            _videoCamera.delegate = self;
            __captureSession = _videoCamera.captureSession;
            _videoOutput = _videoCamera.getVideoOutput;
            _videoInput = _videoCamera.getVideoInput;
            _audioOutput = _videoCamera.getAudioOutput;
            _audioInput = _videoCamera.getAudioInput;
        }
        
    }
    return self;
}

- (void)willOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer{
  
}
- (void)GPUImageCameraCaptureOutput:(AVCaptureOutput *)captureOutput didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer fromConnection:(AVCaptureConnection *)connection{
    [_delegate VideoCaptureOutput:captureOutput didOutputSampleBuffer:sampleBuffer fromConnection:connection];
}

- (void)dealloc {
    [UIApplication sharedApplication].idleTimerDisabled = NO;
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [_videoCamera stopCameraCapture];
    if(_gpuImageView){
        [_gpuImageView removeFromSuperview];
        _gpuImageView = nil;
    }
}

#pragma mark -- GPUImageCameraDelegate



#pragma mark -- Setter Getter

- (GPUImageVideoCamera *)videoCamera{
    return _videoCamera;
}

- (void)setRunning:(BOOL)running {
    if (_running == running) return;
    _running = running;
    
    if (!_running) {
        [UIApplication sharedApplication].idleTimerDisabled = NO;
        [self.videoCamera stopCameraCapture];
        if(self.saveLocalVideo) [self.movieWriter finishRecording];
    } else {
        [UIApplication sharedApplication].idleTimerDisabled = YES;
        [self reloadFilter];
        [self.videoCamera startCameraCapture];
    }
}


- (void)startMovieWriter;{
    if(self.saveLocalVideo) [self.movieWriter startRecording];
}

- (void)stopMovieWriter;{
    if(self.saveLocalVideo) [self.movieWriter finishRecording];
}

- (AVCaptureSession *)getCaptureSession;
{
    return __captureSession;
}

- (AVCaptureDeviceInput *)getVideoInput;
{
    return _videoInput;
}

- (AVCaptureDeviceInput *)getAudioInput;
{
    return _audioInput;
}

- (AVCaptureAudioDataOutput *)getAudioOutput;
{
    return _audioOutput;
}

- (AVCaptureVideoDataOutput *)getVideoOutput;
{
    return _videoOutput;
}

- (void)setPreView:(UIView *)preView {
    if (self.gpuImageView.superview) [self.gpuImageView removeFromSuperview];
    [preView insertSubview:self.gpuImageView atIndex:0];
    self.gpuImageView.frame = CGRectMake(0, 0, preView.frame.size.width, preView.frame.size.height);
}

- (UIView *)preView {
    return self.gpuImageView.superview;
}

- (void)setCaptureDevicePosition:(AVCaptureDevicePosition)captureDevicePosition {
    if(captureDevicePosition == self.videoCamera.cameraPosition) return;
    [self.videoCamera rotateCamera];
    self.videoCamera.frameRate = (int32_t)_configuration.videoFrameRate;
    [self reloadMirror];
}

- (AVCaptureDevicePosition)captureDevicePosition {
    return [self.videoCamera cameraPosition];
}

- (void)setVideoFrameRate:(NSInteger)videoFrameRate {
    if (videoFrameRate <= 0) return;
    if (videoFrameRate == self.videoCamera.frameRate) return;
    self.videoCamera.frameRate = (uint32_t)videoFrameRate;
}

- (NSInteger)videoFrameRate {
    return self.videoCamera.frameRate;
}

- (void)setTorch:(BOOL)torch {
    BOOL ret;
    if (!self.videoCamera.captureSession) return;
    AVCaptureSession *session = (AVCaptureSession *)self.videoCamera.captureSession;
    [session beginConfiguration];
    if (self.videoCamera.inputCamera) {
        if (self.videoCamera.inputCamera.torchAvailable) {
            NSError *err = nil;
            if ([self.videoCamera.inputCamera lockForConfiguration:&err]) {
                [self.videoCamera.inputCamera setTorchMode:(torch ? AVCaptureTorchModeOn : AVCaptureTorchModeOff) ];
                [self.videoCamera.inputCamera unlockForConfiguration];
                ret = (self.videoCamera.inputCamera.torchMode == AVCaptureTorchModeOn);
            } else {
                NSLog(@"Error while locking device for torch: %@", err);
                ret = false;
            }
        } else {
            NSLog(@"Torch not available in current camera input");
        }
    }
    [session commitConfiguration];
    _torch = ret;
}

- (BOOL)torch {
    return self.videoCamera.inputCamera.torchMode;
}

- (void)setMirror:(BOOL)mirror {
    _mirror = mirror;
}

- (void)setBeautyFace:(BOOL)beautyFace{
    _beautyFace = beautyFace;
    [self reloadFilter];
}

- (void)setBeautyLevel:(CGFloat)beautyLevel {
    _beautyLevel = beautyLevel;
    if (self.beautyFilter) {
        [self.beautyFilter setBeautyLevel:_beautyLevel];
    }
}

- (CGFloat)beautyLevel {
    return _beautyLevel;
}

- (void)setBrightLevel:(CGFloat)brightLevel {
    _brightLevel = brightLevel;
    if (self.beautyFilter) {
        [self.beautyFilter setBrightLevel:brightLevel];
    }
}

- (CGFloat)brightLevel {
    return _brightLevel;
}

- (void)setZoomScale:(CGFloat)zoomScale {
    if (self.videoCamera && self.videoCamera.inputCamera) {
        AVCaptureDevice *device = (AVCaptureDevice *)self.videoCamera.inputCamera;
        if ([device lockForConfiguration:nil]) {
            device.videoZoomFactor = zoomScale;
            [device unlockForConfiguration];
            _zoomScale = zoomScale;
        }
    }
}

- (CGFloat)zoomScale {
    return _zoomScale;
}

- (void)setWarterMarkView:(UIView *)warterMarkView{
//    if(_warterMarkView && _warterMarkView.superview){
//        [_warterMarkView removeFromSuperview];
//        _warterMarkView = nil;
//    }
//    _warterMarkView = warterMarkView;
//    _warterMarkView.frame = CGRectMake(0, 0, self.configuration.videoSize.width, self.configuration.videoSize.height);
//    self.blendFilter.mix = warterMarkView.alpha;
//    [self.waterMarkContentView addSubview:_warterMarkView];
//    _warterMarkView.translatesAutoresizingMaskIntoConstraints = false;
//    //Constraints
//    [_warterMarkView.leadingAnchor constraintEqualToAnchor:_waterMarkContentView.leadingAnchor].active = YES;
//    [_warterMarkView.trailingAnchor constraintEqualToAnchor:_waterMarkContentView.trailingAnchor].active = YES;
//    [_warterMarkView.topAnchor constraintEqualToAnchor:_waterMarkContentView.topAnchor].active = YES;
//    [_warterMarkView.bottomAnchor constraintEqualToAnchor:_waterMarkContentView.bottomAnchor].active = YES;
//    [_warterMarkView layoutIfNeeded];
//    if(self.isWatermarkActive == NO){
//        [self reloadFilter];
//    }else{
//      [self reloadFilterSoft];
//    }
    [self reloadFilterTest];
}

- (GPUImageUIElement *)uiElementInput{
    if(!_uiElementInput){
        _uiElementInput = [[GPUImageUIElement alloc] initWithView:self.waterMarkContentView];
    }
    return _uiElementInput;
}

- (GPUImageAlphaBlendFilter *)blendFilter{
    if(!_blendFilter){
        _blendFilter = [[GPUImageAlphaBlendFilter alloc] init];
        _blendFilter.mix = 1.0;
        [_blendFilter disableSecondFrameCheck];
    }
    return _blendFilter;
}

- (UIView *)waterMarkContentView{
    if(!_waterMarkContentView){
        _waterMarkContentView = [UIView new];
        _waterMarkContentView.frame = CGRectMake(0, 0, self.configuration.videoSize.width, self.configuration.videoSize.height);
        _waterMarkContentView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    }
    return _waterMarkContentView;
}

- (GPUImageView *)gpuImageView{
    if(!_gpuImageView){
        _gpuImageView = [[GPUImageView alloc] initWithFrame:[UIScreen mainScreen].bounds];
        [_gpuImageView setFillMode:kGPUImageFillModePreserveAspectRatioAndFill];
        [_gpuImageView setAutoresizingMask:UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight];
    }
    return _gpuImageView;
}

-(UIImage *)currentImage{
    if(_filter){
        [_filter useNextFrameForImageCapture];
        return _filter.imageFromCurrentFramebuffer;
    }
    return nil;
}

- (GPUImageMovieWriter*)movieWriter{
    if(!_movieWriter){
        _movieWriter = [[GPUImageMovieWriter alloc] initWithMovieURL:self.saveLocalVideoPath size:self.configuration.videoSize];
        _movieWriter.encodingLiveVideo = YES;
        _movieWriter.shouldPassthroughAudio = YES;
        self.videoCamera.audioEncodingTarget = self.movieWriter;
    }
    return _movieWriter;
}

#pragma mark -- Custom Method
- (void)processVideo:(GPUImageOutput *)output {
    __weak typeof(self) _self = self;
    @autoreleasepool {
        GPUImageFramebuffer *imageFramebuffer = output.framebufferForOutput;
        CVPixelBufferRef pixelBuffer = [imageFramebuffer pixelBuffer];
        if (pixelBuffer && _self.delegate && [_self.delegate respondsToSelector:@selector(captureOutput:pixelBuffer:)]) {
            [_self.delegate captureOutput:_self pixelBuffer:pixelBuffer];
        }
    }
}

- (void)reloadFilter{
    [self.filter removeAllTargets];
    [self.blendFilter removeAllTargets];
    [self.uiElementInput removeAllTargets];
    [self.videoCamera removeAllTargets];
    [self.output removeAllTargets];
    [self.cropfilter removeAllTargets];
    
    if (self.beautyFace) {
        self.output = [[LFGPUImageEmptyFilter alloc] init];
        self.filter = [[LFGPUImageBeautyFilter alloc] init];
        self.beautyFilter = (LFGPUImageBeautyFilter*)self.filter;
    } else {
        self.output = [[LFGPUImageEmptyFilter alloc] init];
        self.filter = [[LFGPUImageEmptyFilter alloc] init];
        self.beautyFilter = nil;
    }
    
    ///< 调节镜像
    [self reloadMirror];
    
    //< 480*640 比例为4:3  强制转换为16:9
    if([self.configuration.avSessionPreset isEqualToString:AVCaptureSessionPreset640x480]){
        CGRect cropRect = self.configuration.landscape ? CGRectMake(0, 0.125, 1, 0.75) : CGRectMake(0.125, 0, 0.75, 1);
        self.cropfilter = [[GPUImageCropFilter alloc] initWithCropRegion:cropRect];
        [self.videoCamera addTarget:self.cropfilter];
        [self.cropfilter addTarget:self.filter];
    }else{
        [self.videoCamera addTarget:self.filter];
    }
    
    //< 添加水印
    if(self.warterMarkView){
        [self.filter addTarget:self.blendFilter];
        [self.uiElementInput addTarget:self.blendFilter];
        [self.blendFilter addTarget:self.gpuImageView];
        //if(self.saveLocalVideo) [self.blendFilter addTarget:self.movieWriter];
        [self.filter addTarget:self.output];
        [self.uiElementInput update];
    }else{
        [self.filter addTarget:self.output];
        [self.output addTarget:self.gpuImageView];
        if(self.saveLocalVideo) [self.output addTarget:self.movieWriter];
    }
    
    [self.filter forceProcessingAtSize:self.configuration.videoSize];
    [self.output forceProcessingAtSize:self.configuration.videoSize];
    [self.blendFilter forceProcessingAtSize:self.configuration.videoSize];
    [self.uiElementInput forceProcessingAtSize:self.configuration.videoSize];
    
    
    //< 输出数据
    __weak typeof(self) _self = self;
    [self.output setFrameProcessingCompletionBlock:^(GPUImageOutput *output, CMTime time) {
        [_self processVideo:output];
    }];
    
}

- (void)reloadFilterSoft{
    //< 输出数据
    __weak typeof(self) _self = self;
    [self.output setFrameProcessingCompletionBlock:^(GPUImageOutput *output, CMTime time) {
        [_self processVideo:output];
    }];
    
}

- (void)reloadFilterTest{
    //GPUImageAlphaBlendFilter *blendFilter = [[GPUImageAlphaBlendFilter alloc] init];
    self.blendFilter.mix = 1.0;
    
    NSDate *startTime = [NSDate date];
    
    UILabel *timeLabel = [[UILabel alloc] initWithFrame:CGRectMake(0.0, 0.0, 240.0f, 320.0f)];
    timeLabel.font = [UIFont systemFontOfSize:17.0f];
    timeLabel.text = @"Time: 0.0 s";
    timeLabel.textAlignment = UITextAlignmentCenter;
    timeLabel.backgroundColor = [UIColor clearColor];
    timeLabel.textColor = [UIColor whiteColor];
    
    _uiElementInput = [[GPUImageUIElement alloc] initWithView:timeLabel];
    [self.filter addTarget:self.blendFilter];
    [self.uiElementInput addTarget:self.blendFilter];
    [self.blendFilter addTarget:self.gpuImageView];
    //if(self.saveLocalVideo) [self.blendFilter addTarget:self.movieWriter];
    [self.filter addTarget:self.output];    
    
    [self.filter forceProcessingAtSize:self.configuration.videoSize];
    [self.output forceProcessingAtSize:self.configuration.videoSize];
    [self.blendFilter forceProcessingAtSize:self.configuration.videoSize];
    [self.uiElementInput forceProcessingAtSize:self.configuration.videoSize];
    
    __unsafe_unretained GPUImageUIElement *weakUIElementInput = _uiElementInput;
    __weak typeof(self) weakSelf = self;
    [_filter setFrameProcessingCompletionBlock:^(GPUImageOutput * filter, CMTime frameTime){
        timeLabel.text = [NSString stringWithFormat:@"Recording Time: %f s", -[startTime timeIntervalSinceNow]];
        [weakUIElementInput update];
        [weakSelf processVideo:_output];
    }];
    
}



- (void)reloadMirror{
    if(self.mirror && self.captureDevicePosition == AVCaptureDevicePositionFront){
        self.videoCamera.horizontallyMirrorFrontFacingCamera = YES;
    }else{
        self.videoCamera.horizontallyMirrorFrontFacingCamera = NO;
    }
}

#pragma mark Notification

- (void)willEnterBackground:(NSNotification *)notification {
    [UIApplication sharedApplication].idleTimerDisabled = NO;
    [self.videoCamera pauseCameraCapture];
    runSynchronouslyOnVideoProcessingQueue(^{
        glFinish();
    });
}

- (void)willEnterForeground:(NSNotification *)notification {
    [self.videoCamera resumeCameraCapture];
    [UIApplication sharedApplication].idleTimerDisabled = YES;
}

- (void)statusBarChanged:(NSNotification *)notification {
    NSLog(@"UIApplicationWillChangeStatusBarOrientationNotification. UserInfo: %@", notification.userInfo);
    UIInterfaceOrientation statusBar = [[UIApplication sharedApplication] statusBarOrientation];

    if(self.configuration.autorotate){
        if (self.configuration.landscape) {
            if (statusBar == UIInterfaceOrientationLandscapeLeft) {
                self.videoCamera.outputImageOrientation = UIInterfaceOrientationLandscapeRight;
            } else if (statusBar == UIInterfaceOrientationLandscapeRight) {
                self.videoCamera.outputImageOrientation = UIInterfaceOrientationLandscapeLeft;
            }
        } else {
            if (statusBar == UIInterfaceOrientationPortrait) {
                self.videoCamera.outputImageOrientation = UIInterfaceOrientationPortraitUpsideDown;
            } else if (statusBar == UIInterfaceOrientationPortraitUpsideDown) {
                self.videoCamera.outputImageOrientation = UIInterfaceOrientationPortrait;
            }
        }
    }
}

@end
