//
//  LRCamera.h
//  LRGPUimage
//
//  Created by liurui on 2016/8/10.
//  Copyright © 2016年 liurui. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>


@interface LRCamera : NSObject



//控制帧率
@property ( nonatomic , assign) int frameRaw;
//是否使用RGB数据
@property ( nonatomic , assign) BOOL isVedioDataRGB;
//横竖屏
@property ( nonatomic , assign) AVCaptureVideoOrientation  VideoOrientation;
//是否需要音频
@property ( nonatomic , assign) BOOL  isCaptureAudioData;
//获取视频帧数据
@property ( nonatomic , copy ) void (^CaptureVidoesampleBufferBlock)(CMSampleBufferRef sampleBuffer);
//获取音频帧数据
@property ( nonatomic , copy ) void (^CaptureAudiosampleBufferBlock)(CMSampleBufferRef sampleBuffer);


//创建相机方法
+ (instancetype)cameraWithSessionPreset:(NSString *)sessionPreset postion:(AVCaptureDevicePosition)postion;

//开始捕获数据
- (void)startCapture;



@end
