 //
//  LRCamera.m
//  LRGPUimage
//
//  Created by liurui on 2016/8/10.
//  Copyright © 2016年 liurui. All rights reserved.
//

#import "LRCamera.h"

@interface LRCamera ()
<
AVCaptureVideoDataOutputSampleBufferDelegate,
AVCaptureAudioDataOutputSampleBufferDelegate
>
@property(nonatomic,strong) AVCaptureSession *session;
@property(nonatomic,strong) AVCaptureVideoDataOutput *videoOutput;

@end

@implementation LRCamera
+ (instancetype)cameraWithSessionPreset:(NSString *)sessionPreset postion:(AVCaptureDevicePosition)postion
{
    LRCamera * camera = [[LRCamera alloc]init];
    //创建捕捉会话
    [camera setupSession:sessionPreset];
    //添加捕获视频数据
    [camera setupVideo:postion];
    //添加捕获音频数据、
    //音频底层格式是PCM
    return camera;
}

- (instancetype)init
{
    if(self = [super init])
    {
        
        _VideoOrientation = AVCaptureVideoOrientationPortrait;
        _frameRaw = 15;
        _isVedioDataRGB = NO;
    }
    return self;
}
- (void)setIsCaptureAudioData:(BOOL)isCaptureAudioData
{
    _isCaptureAudioData = isCaptureAudioData;
    
    if(_isCaptureAudioData == YES)
    {
            [self setupAudio];
    }
    
}

-(void)setupSession:(NSString *)sessionPreset
{
    AVCaptureSession *session = [[AVCaptureSession alloc]init];
    _session = session;
    
    if(sessionPreset.length == 0)
    {
        sessionPreset = AVCaptureSessionPresetHigh;
    }
    
    session.sessionPreset = sessionPreset;
}
- (void) setupVideo:(AVCaptureDevicePosition)postion
{
    //获取前置摄像头
    
    //活取照相机
    AVCaptureDevice * videoDevice = [self videoDeviceWithposition:postion];
    NSLog(@"%@",videoDevice);
    //捕获视频=》视频输入 视频输出
    //创建视频输入
    //指定一个设备创建对应的设备输入对象
    //    AVCaptureInput *av = [[AVCaptureInput alloc]init];//基础类
    AVCaptureDeviceInput * videoInput = [AVCaptureDeviceInput deviceInputWithDevice:videoDevice error:nil];
    //捕获视频数据
    
    //创建视频输出,获取采集视频数据不写成文件
    AVCaptureVideoDataOutput *videoOutput = [self setupVideoOutput];
    self.videoOutput = videoOutput;

    //给回话添加视频输入（输出）
    if([_session canAddInput:videoInput])
    {
        [_session addInput:videoInput];
    }
    if([_session canAddOutput:videoOutput])
    {
        [_session addOutput:videoOutput];
    }
    
    AVCaptureConnection *videoconnection =  [videoOutput connectionWithMediaType:AVMediaTypeVideo];
    videoconnection.videoMirrored = NO;//镜像
    //下面是竖屏👇    系统给的数据就是竖屏数据
    videoconnection.videoOrientation = AVCaptureVideoOrientationPortraitUpsideDown;

}
-(void)setupAudio
{
    //获取音频设备
    AVCaptureDevice * AudioDeV = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeAudio];
    //转换成音频输入
    AVCaptureDeviceInput * aUdioinput =[[AVCaptureDeviceInput alloc]initWithDevice:AudioDeV error:nil];
    //音频输出
    AVCaptureAudioDataOutput *aUdiooutput = [[AVCaptureAudioDataOutput alloc]init];
    dispatch_queue_t videoQueue = dispatch_queue_create("AudioQueue",DISPATCH_QUEUE_SERIAL);
    [aUdiooutput setSampleBufferDelegate:self queue:videoQueue];
    
    if ([_session canAddInput:aUdioinput]) {
        [_session addInput:aUdioinput];
    }
    if ([_session canAddOutput:aUdiooutput]) {
        [_session addOutput:aUdiooutput];
    }
    
    
}
//指定一个摄像头方向，回去对应摄像设备
-(AVCaptureDevice *)videoDeviceWithposition:(AVCaptureDevicePosition)position
{
    NSArray *videoDevices = [AVCaptureDevice devicesWithMediaType:AVMediaTypeVideo];
    
    for(AVCaptureDevice *device in videoDevices)
    {
        if (device.position == position) {
            return device;
        }
        
    }
    return nil;
    
}
- (AVCaptureVideoDataOutput *)setupVideoOutput
{
    // 创建视频输出
    // 获取采集视频数据,并不是写成文件
    AVCaptureVideoDataOutput *videoOutput = [[AVCaptureVideoDataOutput alloc] init];
    
    //前为第几帧 后为每秒多少帧
    videoOutput.minFrameDuration = CMTimeMake(1,_frameRaw);
    //   minFrameDuration :帧率（最小帧率）(太小不一定成功)
    
    
    //   videoSettings：设置视频格式（YUV、RGB）（苹果开发中提供的渲染只支持RGB（最好用RGB））
    // 但是直播中大多用YUV （流媒体常用编码方式）(将YUV矩阵装换成RGB，美图RGB)
    NSNumber *dataFm = nil;
    if(_isVedioDataRGB)
    {
        dataFm =@(kCVPixelFormatType_32BGRA);
    }else
    {
        dataFm =@(kCVPixelFormatType_420YpCbCr8BiPlanarFullRange);
    }
    
    videoOutput.videoSettings = @{(NSString *)kCVPixelBufferPixelFormatTypeKey:dataFm};
    //   alwaysDiscardsLateVideoFrames 延迟时候是否丢帧
    videoOutput.alwaysDiscardsLateVideoFrames = YES;
    //通过代理获取采集数据  队列要同步队列 因为获取图像帧有顺序
    //创建同步队列
    dispatch_queue_t videoQueue = dispatch_queue_create("videoQueue",DISPATCH_QUEUE_SERIAL);
    [videoOutput setSampleBufferDelegate:self queue:videoQueue];
    return videoOutput;
    
}

#pragma mark - AVCaptureVideoDataOutputSampleBufferDelegate(代理方法)

- (void)captureOutput:(AVCaptureOutput *)captureOutput didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer fromConnection:(AVCaptureConnection *)connection
{
    if(_videoOutput == captureOutput)//视频
    {
        if (_CaptureVidoesampleBufferBlock)
        {
             _CaptureVidoesampleBufferBlock(sampleBuffer);
        }
    }else
    {
        if (_CaptureAudiosampleBufferBlock)//音频
        {
            _CaptureAudiosampleBufferBlock(sampleBuffer);
        }
     }
}
- (void)startCapture
{
    [_session startRunning];
}
@end



/*
 经验：只要苹果原生类属性很少一般都是（基类）；需要寻找子类（根据功能）；
 AVCaptureDevice(摄像头麦克风)(设备)。（本质不能输出东西）
 AVCaptureInput     管理数据采集
 AVCaptureOutput g 管理设备数据输出（文件、图片）
 AVCaptureSession：管理输入到输出数据
 AVCaptureSession：给定一个输入输出设备就会在输入和输出设备中简历链接AVCaptureCnncion
 AVCaptureVideoPreviewLayer:展示采集数据。
 AVCaptureVideoDataOutput:获取设备输出数据（摄像头）
 AVCaptureAudioDataOutput 音频数据
 采集视频：——摄像头AV
 
 采集音频：--------麦克风
 //开始捕获，会把输入设备数据传入到输出设备上
 -（void）startRuning;
 
 //采集到数据后进行——》滤镜处理——》显示
 
 */



//*********************************原始各个数据代表意思**************************************
//获取每一帧播放的时长
// CMSampleBufferGetDuration(<#CMSampleBufferRef  _Nonnull sbuf#>)计算视频时长属性
//CMBlockBufferRef:把图片压缩后的数据；
//CMSampleBufferCreate压缩之后解码显示；
//获取图片讯息
//    CMSampleBufferGetImageBuffer(<#CMSampleBufferRef  _Nonnull sbuf#>);
//获取帧的尺寸
//    CMSampleBufferGetSampleSize(<#CMSampleBufferRef  _Nonnull sbuf#>, <#CMItemIndex sampleIndex#>)
//VideoToolbox:硬编码帧数经过H.264压缩  NAL（PTS,DTS,I,P,B）
//编码
//PTS:展示时间
//    CMSampleBufferGetPresentationTimeStamp(<#CMSampleBufferRef  _Nonnull sbuf#>)
//DTS帧的压缩时间

//    CMSampleBufferGetDecodeTimeStamp(<#CMSampleBufferRef  _Nonnull sbuf#>)
//获取帧格式,通过其获取PTS，DTS
//    CMSampleBufferGetFormatDescription(<#CMSampleBufferRef  _Nonnull sbuf#>)




/*CPU处理**************************滤镜与渲染*********************************************
 //ciimag直接可以获取那些滤镜可以处理图片
 NSArray *filters = [cimg autoAdjustmentFilters];
 for (CIFilter *filter in filters) {
 NSLog(@"%@",filter.name);
 }
 NSLog(@"%@",[filters.firstObject class]);
 
 //先要获 取滤镜名称通过名称找到对应的对象
 //   NSArray *filterNames =   [CIFilter filterNamesInCategory:kCICategoryVideo];
 //    //创建滤镜
 //    //CIFilter通过KVC设置
 //    //attributes：获取属性对应的类型
 //    //inputKeys:获取CIFilter的那些属性可以设置
 CIFilter *filter =  [CIFilter filterWithName:@"CIPhotoEffectTransfer"];
 //    [filter setValue:@4 forKey:@"inputEV"];
 [filter setValue:cimg forKey:@"inputImage"];
 cimg =  filter.outputImage;
 UIImage * image = [UIImage imageWithCIImage:cimg];
 dispatch_sync(dispatch_get_main_queue(), ^{
 self.imageView.image = image;
 });
 */






/***********************原始处理法************************************
 -(void)prosesssampleBuffer:(CMSampleBufferRef)sampleBuffer
 {
 @autoreleasepool {
 
 //其实这个方法用来GPU用的更高还是直接转ciimage好亲测
 
 //OpenGL
 //EAGLContext:上下文底层是通过openGL渲染的
 //获取原图片信息
 CVImageBufferRef imageref =  CMSampleBufferGetImageBuffer(sampleBuffer);
 //获取CIimage
 CIImage * cimg = [CIImage imageWithCVImageBuffer:imageref];
 //    CIContext
 //创建opengl上下文
 EAGLContext *openGLcontext = [[EAGLContext alloc]initWithAPI:kEAGLRenderingAPIOpenGLES2];
 //创建coreImage上下文
 CIContext *context =   [CIContext contextWithEAGLContext:openGLcontext];
 //ciimage extent可以直接去除bounds 拿到了通过OPenGL渲染的图片
 CGImageRef  imgref =   [context createCGImage:cimg fromRect:cimg.extent];
 UIImage * image =  [UIImage imageWithCGImage:imgref];
 dispatch_sync(dispatch_get_main_queue(), ^{
 self.imageView.image = image;
 });
 //*********************不管理可能直接爆掉
 //    CGImageRelease(imgref);
 }
 }
 */







/**************代理方法一些小处理和一些小东西**************************
 //协议
 //获取一针就会调用
 //CVImageBufferRef = CVPixelBufferRef图片的缓存数据
 //采集到数据后进行——》滤镜处理（CIFIlter，苹果的，）（GPUImage）——》显示（实际都是对每一个点的处理）
 - (void)captureOutput:(AVCaptureOutput *)captureOutput didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer fromConnection:(AVCaptureConnection *)connection
 {//此方法在子线程无法更新UI
 //    NSLog(@"获取一帧的数据");
 //判断音频还是视频
 
 
 //AVCaptureVideoPreViewLayer:展示采集页面
 //sampleBuffer:一帧数据
 //sampleBuffer->UIImage
 //CoreImage:处理底层图片
 if(_AVoutput == captureOutput )
 {
 //        [self dealVideoData:sampleBuffer];
 [self prosesssampleBuffer:sampleBuffer];
 }else
 {
 //            NSLog(@"获取音频数据的数据");
 }
 }
 
 
 //丢帧代理
 - (void)captureOutput:(AVCaptureOutput *)captureOutput didDropSampleBuffer:(CMSampleBufferRef)sampleBuffer fromConnection:(AVCaptureConnection *)connection NS_AVAILABLE(10_7, 6_0)
 {
 
 }
 
 */
/**************代理方法一些小处理和一些小东西(————图片————)**************************
 //处理数据
 //显示原生图片
 -(void)dealVideoData:(CMSampleBufferRef)sampleBuffer
 {
 CVImageBufferRef imageRef = CMSampleBufferGetImageBuffer(sampleBuffer);
 
 
 CIImage *img = [CIImage imageWithCVImageBuffer:imageRef];
 
 UIImage *iage =  [UIImage imageWithCIImage:img];
 dispatch_async(dispatch_get_main_queue(), ^{
 self.imageView.image = iage;
 });
 
 
 }
 */


/***********************处理图片显示一些小东西（UIImageView有关）***************************
 
 
 -(UIImageView *)imageView
 {
 if(_imageView == nil)
 {//底层拿到是反的
 UIImageView *ima = [[UIImageView alloc] initWithFrame:self.view.bounds];
 
 
 
 ////        设置锚点 自己搞
 //        ima.transform = CGAffineTransformMakeRotation(M_PI_2);
 //        UIImageView *ima = [[UIImageView alloc] initWithFrame:CGRectMake(0, 0, self.view.bounds.size.height, self.view.bounds.size.width)];
 //        ima.layer.anchorPoint = CGPointMake(0, 0);
 //        ima.layer.position = CGPointMake(self.view.bounds.size.width,0);
 [self.view addSubview:ima];
 _imageView = ima;
 }
 return _imageView;
 }
 
 */


/*****************************已经封装进入相机*******************************
 Do any additional setup after loading the view, typically from a nib.
 创建捕捉绘画
 AVCaptureSession *session = [[AVCaptureSession alloc] init];
 图片尺寸大小
 session.sessionPreset = AVCaptureSessionPreset1280x720;
 _session  = session;
 开始捕获数据
 [_session startRunning];
 把捕获的数据展示在屏幕上
 //预览
 AVCaptureVideoPreviewLayer *av =[AVCaptureVideoPreviewLayer layerWithSession:_session];
 //    av.automaticallyAdjustsMirroring 调节镜像（默认自动调节）AVCaptureVideoOrientation摄像头方向
 
 av.frame = self.view.bounds;
 [self.view.layer addSublayer:av];
 */

