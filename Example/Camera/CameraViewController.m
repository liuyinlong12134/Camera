//
//  CameraViewController.m
//  Camera
//
//  Created by liuyinlong1992 on 04/18/2017.
//  Copyright (c) 2017 liuyinlong1992. All rights reserved.
//

#import "CameraViewController.h"
#import<VideoToolbox/VideoToolbox.h>
#import "LRCamera.h"
#import "LROpenGLView.h"

@interface CameraViewController ()



@property ( nonatomic,strong) AVCaptureSession *session;

@property ( nonatomic,strong) LRCamera *camera;

@property ( nonatomic,strong) LROpenGLView *LROpenGLVIew;


@end

@implementation CameraViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    
    LROpenGLView * openglView = [[LROpenGLView alloc]initWithFrame:self.view.bounds];
    [self.view addSubview:openglView];
    _camera = [LRCamera cameraWithSessionPreset:AVCaptureSessionPreset1280x720 postion:AVCaptureDevicePositionFront];
    
    [_camera startCapture];
    
    _camera.CaptureVidoesampleBufferBlock= ^(CMSampleBufferRef sampleBuffer) {
        
        [openglView displayWithSampleBuffer:sampleBuffer];
        
    } ;
    _camera.CaptureAudiosampleBufferBlock = ^(CMSampleBufferRef sampleBuffer) {
        NSLog(@"音频");
    };
    
    
    
}

@end
