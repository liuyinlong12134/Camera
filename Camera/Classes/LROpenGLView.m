//
//  LROpenGLView.m
//  LRGPUimage
//
//  Created by liurui on 2016/8/10.
//  Copyright © 2016年 liurui. All rights reserved.
//

#import "LROpenGLView.h"
//使用OpenGL代码必须要导入GLKit/GLKit.h
#import <GLKit/GLKit.h>

/*
 CAEAGLLayer是OpenGL专门用来渲染图层，使用OpenGL必须使用这个图层
 使用OpenGL只能渲染到CAEAGLLayer不能渲染到CALayer上
 kEAGLDrawablePropertyRetainedBacking默认不保存绘制后的东西用来重用
 */
#define STRINGIZE(x) #x
#define STRINGIZE2(x) STRINGIZE(x)
#define SHADER_STRING(text) @ STRINGIZE2(text)

enum {
    ATTRIB_POSITION,
    ATTRIB_TEXCOORD
};

//顶点着色器
NSString *const kVertexShaderString = SHADER_STRING
(
 attribute vec4 position;//传四个
 attribute vec2 inputTextureCoordinate;//传两个
 
 varying vec2 textureCoordinate;
 
 void main()
 {
     gl_Position = position;
     textureCoordinate = inputTextureCoordinate;
 }
 );

// 片段着色器代码
NSString *const kYUVFullRangeConversionForLAFragmentShaderString = SHADER_STRING
(
 varying highp vec2 textureCoordinate;
 
 precision mediump float;
 //uniform表示全局变量
 uniform sampler2D luminanceTexture;
 uniform sampler2D chrominanceTexture;
 uniform mediump mat3 colorConversionMatrix;
 
 void main()
 {
     mediump vec3 yuv;
     lowp vec3 rgb;
     
     yuv.x = texture2D(luminanceTexture, textureCoordinate).r;
     yuv.yz = texture2D(chrominanceTexture, textureCoordinate).ra - vec2(0.5, 0.5);
     rgb = colorConversionMatrix * yuv;
     
     gl_FragColor = vec4(rgb, 1);
 }
 );
//全彩
static const GLfloat kColorConversion601FullRange[] = {
    1.0,    1.0,    1.0,
    0.0,    -0.343, 1.765,
    1.4,    -0.711, 0.0,
};

@interface LROpenGLView ()



//创建OpenGL上下文
@property ( nonatomic,strong) EAGLContext *eaglContext;

//渲染缓冲区
@property (nonatomic,assign) GLuint  colorRenderbuffer;

//帧缓冲区
@property (nonatomic,assign) GLuint  framebuffers;

//OpenGL用的layer
@property (nonatomic, strong) CAEAGLLayer *openGLLayer;

//纹理缓存
@property (nonatomic,assign) CVOpenGLESTextureCacheRef textureCacheRef;

//亮度纹理
@property (nonatomic,assign) CVOpenGLESTextureRef luminanceTextureRef;

//色度纹理
@property (nonatomic,assign) CVOpenGLESTextureRef chrominanceTextureRef;

// 亮度纹理索引
@property (nonatomic, assign) GLuint luminanceTexture;

// 色度纹理索引
@property (nonatomic, assign) GLuint chrominanceTexture;

@property (nonatomic, assign) GLsizei bufferWidth;

@property (nonatomic, assign) GLsizei bufferHeight;

//顶点着色器
@property (nonatomic,assign) GLuint vertexShader;

//片段着色器
@property (nonatomic,assign) GLuint fragmentShader;

//着色器程序
@property (nonatomic,assign) GLuint shaderProgram;

//YUV转RGB的格式   指向数组 加星号表指针指向地0个元素
@property (nonatomic, assign)  GLfloat *preferredConversion;

@property (nonatomic, assign) int luminanceTextureAtt;

@property (nonatomic, assign) int chrominanceTextureAtt;

@property (nonatomic, assign) int colorConversionMatrixAtt;






@end

@implementation LROpenGLView
//修改UIView图层类型让UIView支持OpenGL修改


- (instancetype)initWithFrame:(CGRect)frame
{
    if(self = [super initWithFrame:frame]){
        [self setupView];
    }
    return self;
}
-(void)awakeFromNib
{
    [super awakeFromNib];
    [self setupView];
}
#pragma mark - 1、初始化OpenGLView
-(void)setupView
{
    //设置图层属性
    [self setupLayer];
    
    //创建OpenGl图形上下文
    [self setupOpenGLContext];
    
    //创建渲染缓冲区
    [self setupRenderBuffer];
    
    //创建帧缓冲区
    [self setupFramBuffer];
    
    //5.创建着色器
    [self setupShader];
    
    //6.创建着色器程序
    [self setuoProgram];
    
    //创建纹理缓存
   CVReturn err = CVOpenGLESTextureCacheCreate(kCFAllocatorDefault, NULL, _eaglContext, NULL, &_textureCacheRef);
    if (err) {
        NSLog(@"CVOpenGLESTextureCacheCreate %d",err);
    }
    _preferredConversion = kColorConversion601FullRange;
 
}
- (void)setuoProgram
{
    //创建着色器程序
    _shaderProgram =  glCreateProgram();
    //添加着色器，着色器运行那些着色器代码
    //一般OpenGL添加用attach
    glAttachShader(_shaderProgram, _vertexShader);
    glAttachShader(_shaderProgram, _fragmentShader);
    
    glBindAttribLocation(_shaderProgram, ATTRIB_POSITION, "position");
    glBindAttribLocation(_shaderProgram, ATTRIB_TEXCOORD, "inputTextureCoordinate");
    
    //链接程序
    glLinkProgram(_shaderProgram);
    // 获取全局参数,注意 一定要在连接完成后才行，否则拿不到
    
    _luminanceTextureAtt = glGetUniformLocation(_shaderProgram, "luminanceTexture");
    _chrominanceTextureAtt = glGetUniformLocation(_shaderProgram, "chrominanceTexture");
    _colorConversionMatrixAtt = glGetUniformLocation(_shaderProgram, "colorConversionMatrix");
    //启动程序
    glUseProgram (_shaderProgram);
}
+ (Class)layerClass
{
    //OpenGL专用图层
    return [CAEAGLLayer class];
}

#pragma mark - 2、初始化图层属性
-(void)setupLayer
{
    CAEAGLLayer *openGLLayer = (CAEAGLLayer * )self.layer;
    _openGLLayer = openGLLayer;
    // 设置不透明,CALayer 默认是透明的，必须将它设为不透明才能让其可见
    openGLLayer.opaque = YES;
    //属性可以不设置 GPUImage内部设置了
    // 设置绘图属性drawableProperties
    // kEAGLColorFormatRGBA8 ： red、green、blue、alpha共8位
    //kEAGLDrawablePropertyColorFormat:绘制内容到图层上，用RGB
    //kEAGLDrawablePropertyRetainedBacking:不保存之前绘制内容
    openGLLayer.drawableProperties = @{
                                       kEAGLDrawablePropertyRetainedBacking :[NSNumber numberWithBool:NO],
                                       kEAGLDrawablePropertyColorFormat : kEAGLColorFormatRGBA8
                                       };
    
}
#pragma mark - 3、创建图形上下文
-(void)setupOpenGLContext
{
    //创建OpenGL上下文

    EAGLContext * eaglContext =  [[EAGLContext alloc]initWithAPI:kEAGLRenderingAPIOpenGLES2];
    
    _eaglContext = eaglContext;
    //设置当前上下文为自己创建的OpenGL
    //以后所有绘制都会绘制到这个上下文中（日后线程多了如果多了上下文多了就乱了，统一设置到这个上下文中）
    [EAGLContext setCurrentContext:_eaglContext];
    
}
#pragma mark - 4、创建渲染缓冲区
-(void)setupRenderBuffer
{
     /* ***************
        一般OpenGL函数一般都以GL开头(需要导入头文件)(gen是生成的意思)
        OpenGL : 通过索引去访问（有一个哈希表）通过表找东西（将指针转化为索引概念）
        n:生成几个
       生成一个渲染缓存区(color用颜色渲染好友好几种)（有时间我在调查一下子）
       (把colorRenderbuffer这家伙的地址传给这样已有改动就给这家伙复制)（生成好怎么给找地址给你）
        Renderbuffer : 接受创建好的渲染缓冲区
        GLuint  colorRenderbuffer;
    *******************/
    //   创建渲染缓冲区
    glGenRenderbuffers(1,&_colorRenderbuffer);
    
    //绑定缓存区
    //target:绑定谁
    //renderbuffer:渲染缓冲区
    //只要访问GL_RENDERBUFFER相当于访问colorRenderbuffer是一种绑定形势
    glBindRenderbuffer(GL_RENDERBUFFER, _colorRenderbuffer);
    
    //分配内存
    //target:给谁分配内存
    //Drawable：根据他的讯息去分配内存（比如图层宽高，就是一后面为基准）
    [_eaglContext renderbufferStorage:GL_RENDERBUFFER fromDrawable:_openGLLayer];
    
    
}

#pragma mark -  5、创建帧缓冲区
-(void)setupFramBuffer
{
    //创建生成帧缓冲区
    glGenFramebuffers(1, &_framebuffers);
    
    //绑定缓冲区
    glBindFramebuffer(GL_FRAMEBUFFER, _framebuffers);
    
    //把渲染缓冲区添加到帧缓存区
    //target 给哪个帧缓存区添加渲染缓冲区
    //GL_COLOR_ATTACHMENT0就是把渲染缓冲区放到帧缓冲区的第几层
    // renderbuffertarget ：将那个渲染缓存区绑定需要添加到帧缓存上
    // renderbuffer:那个
    glFramebufferRenderbuffer(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_RENDERBUFFER, _colorRenderbuffer);
    
    
}
- (void)destoryRenderAndFrameBuffer
{
    //销毁渲染缓存
    
    glDeleteRenderbuffers(1, &_colorRenderbuffer);
    _colorRenderbuffer = 0;
    
    glDeleteBuffers(1, &_framebuffers);
    _framebuffers = 0;
}


#pragma mark - 创建亮度纹理对象
#pragma mark - 创建色度纹理对象
-(void)setupYUVTexture:(CMSampleBufferRef)sampleBuffer
{
    
    
    //一个图连个纹理对象 ——YUV一个亮度一个色度
    //allocator分配内存方式CFAllocatorRef(一般这种常量以K开头)kCFAllocatorDefault默认
    //textureCache纹理缓存CVOpenGLESTextureCacheRef
    //CVImageBufferRef sourceImage图片讯息
    //target:创建纹理类型内置
    //internalFormat纹理格式(图片)格式YUV
    //width纹理宽度（图片宽）
    //format纹理格式
    //type纹理类型（图片讯息数据类型）
    //planeIndex ??????（哪个面应用3D的效果）
    //textureOut创建好的纹理对象（指向）
    //获取图片宽度
    //    CVPixelBufferGetPlaneCount(<#CVPixelBufferRef  _Nonnull pixelBuffer#>)做3D效果获取切面
    
    CVPixelBufferRef sourceImage =  CMSampleBufferGetImageBuffer(sampleBuffer);
    
    GLsizei bufferWidth  = (GLsizei) CVPixelBufferGetWidth(sourceImage);
    _bufferWidth = bufferWidth;
    
    GLsizei bufferHight  =(GLsizei) CVPixelBufferGetHeight(sourceImage);
    _bufferHeight = bufferHight;
    
    //激活纹理单元
    glActiveTexture(GL_TEXTURE0);
    
    //图片（YUV） = 亮度纹理 + 色度纹理
    //创建亮度纹理对象
    CVReturn err =  CVOpenGLESTextureCacheCreateTextureFromImage(kCFAllocatorDefault, _textureCacheRef, sourceImage, NULL, GL_TEXTURE_2D, GL_LUMINANCE, bufferWidth, bufferHight, GL_LUMINANCE, GL_UNSIGNED_BYTE,  0,&_luminanceTextureRef);
    
    if(err > 0)
    {
        //创建失败
        NSLog(@"创建失败");
    }
    
    //获取纹理索引
    _luminanceTexture= CVOpenGLESTextureGetName(_luminanceTextureRef);
    
    //绑定纹理   根据纹理索引操作GL_TEXTURE_2D就等于操作纹理
    glBindTexture(GL_TEXTURE_2D, _luminanceTexture);
    
    //设置滤波
    glTexParameterf(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
    glTexParameterf(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
    
    // 激活单元1
    glActiveTexture(GL_TEXTURE1);
    
    // 创建色度纹理除以二是因为有两个
    //    CVReturn err;
    err = CVOpenGLESTextureCacheCreateTextureFromImage(kCFAllocatorDefault, _textureCacheRef, sourceImage, NULL, GL_TEXTURE_2D, GL_LUMINANCE_ALPHA, bufferWidth / 2, bufferHight / 2, GL_LUMINANCE_ALPHA, GL_UNSIGNED_BYTE, 1, &_chrominanceTextureRef);
    
    if (err) {
        NSLog(@"Error at CVOpenGLESTextureCacheCreateTextureFromImage %d", err);
    }
    
    // 获取纹理对象索引
    _chrominanceTexture  = CVOpenGLESTextureGetName(_chrominanceTextureRef);
    
    // 绑定纹理
    glBindTexture(GL_TEXTURE_2D, _chrominanceTexture);
    
    // 设置纹理滤波
    glTexParameterf(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
    glTexParameterf(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
    
}


#pragma mark -  5、创建着色器
- (void)setupShader
{
    //创建定点着色器
   _vertexShader =  [self loadShader:GL_VERTEX_SHADER withString:kVertexShaderString];
    
    //创建片段着色器
   _fragmentShader =  [self loadShader:GL_FRAGMENT_SHADER withString:kYUVFullRangeConversionForLAFragmentShaderString];
}
#pragma mark -  6、加载着色器
//着色器类型 type
// shaderCoder:着色器代码
-(GLuint)loadShader:(GLenum)type withString:(NSString *)shaderCoder
{
    //1.创建着色器(小程序)
    GLuint shader =  glCreateShader(type);
    if(shader == 0)
    {
        return 0;
    }
    
    //2.加载着色器代码
    //shader:给哪个着色器添加代码
    //count :添加几个代码
    //string:着色器代码
   const char * shaderStringUTF8 = [shaderCoder UTF8String];
    glShaderSource(shader,1,&shaderStringUTF8, NULL);
  
    //编译着色器代码
    glCompileShader(shader);
    
    //判断是否编译完成
    GLint compiled = 0;
    
    //获取编译是否完成状态
    glGetShaderiv(shader, GL_COMPILE_STATUS, &compiled);
    
    if(compiled == 0)
    {
        //编译失败
        glDeleteShader(shader);
        return 0;
    }
    return shader;
}
#pragma mark - 每次处理帧数据，展示到OpenGLView
- (void) displayWithSampleBuffer: (CMSampleBufferRef)sampleBuffer
{
    
    // 因为是多线程，每一个线程都有一个上下文，只要在一个上下文绘制就好，设置线程的上下文为我们自己的上下文,就能绘制在一起了，否则会黑屏.
    if ([EAGLContext currentContext] != _eaglContext) {
        [EAGLContext setCurrentContext:_eaglContext];
    }
    
    // 清空之前的纹理，要不然每次都创建新的纹理，耗费资源，造成界面卡顿
    [self cleanUpTextures];
    
    //创建亮度色度纹理对象
    [self setupYUVTexture:sampleBuffer];
    
    //YUV 转 RGB
    [self convertYUVToRGBOutput];
    
    //渲染
    //设置窗口尺寸（渲染多大的屏幕）
    glViewport(0, 0, self.bounds.size.width, self.bounds.size.height);
    
    //把上下文的东西渲染到屏幕上
    [_eaglContext presentRenderbuffer:GL_RENDERBUFFER];
    
    
}
// YUA 转 RGB，里面的顶点和片段都要转换
- (void)convertYUVToRGBOutput
{
    // 在创建纹理之前，有激活过纹理单元，就是那个数字.GL_TEXTURE0,GL_TEXTURE1
    // 指定着色器中亮度纹理对应哪一层纹理单元
    // 这样就会把亮度纹理，往着色器上贴
    glUniform1i(_luminanceTextureAtt, 0);
    
    // 指定着色器中色度纹理对应哪一层纹理单元
    glUniform1i(_chrominanceTextureAtt, 1);
    
    // YUA转RGB矩阵
    glUniformMatrix3fv(_colorConversionMatrixAtt, 1, GL_FALSE, _preferredConversion);
    
    // 计算顶点数据结构
    CGRect vertexSamplingRect = AVMakeRectWithAspectRatioInsideRect(CGSizeMake(self.bounds.size.width, self.bounds.size.height), self.layer.bounds);
    
    CGSize normalizedSamplingSize = CGSizeMake(0.0, 0.0);
    CGSize cropScaleAmount = CGSizeMake(vertexSamplingRect.size.width/self.layer.bounds.size.width, vertexSamplingRect.size.height/self.layer.bounds.size.height);
    
    if (cropScaleAmount.width > cropScaleAmount.height) {
        normalizedSamplingSize.width = 1.0;
        normalizedSamplingSize.height = cropScaleAmount.height/cropScaleAmount.width;
    }
    else {
        normalizedSamplingSize.width = 1.0;
        normalizedSamplingSize.height = cropScaleAmount.width/cropScaleAmount.height;
    }
    
    // 确定顶点数据结构
    GLfloat quadVertexData [] = {
        -1 * normalizedSamplingSize.width, -1 * normalizedSamplingSize.height,
        normalizedSamplingSize.width, -1 * normalizedSamplingSize.height,
        -1 * normalizedSamplingSize.width, normalizedSamplingSize.height,
        normalizedSamplingSize.width, normalizedSamplingSize.height,
    };
    
    // 确定纹理数据结构
    GLfloat quadTextureData[] =  { // 正常坐标
        0, 0,
        1, 0,
        0, 1,
        1, 1
    };
    
    // 激活ATTRIB_POSITION顶点数组
    glEnableVertexAttribArray(ATTRIB_POSITION);
    // 给ATTRIB_POSITION顶点数组赋值
    glVertexAttribPointer(ATTRIB_POSITION, 2, GL_FLOAT, 0, 0, quadVertexData);
    
    // 激活ATTRIB_TEXCOORD顶点数组
    glVertexAttribPointer(ATTRIB_TEXCOORD, 2, GL_FLOAT, 0, 0, quadTextureData);
    // 给ATTRIB_TEXCOORD顶点数组赋值
    glEnableVertexAttribArray(ATTRIB_TEXCOORD);
    
    // 渲染纹理数据数据
    glDrawArrays(GL_TRIANGLE_STRIP, 0, 4);
}

- (void)dealloc
{
    // 清空缓存
    [self destoryRenderAndFrameBuffer];
    
    // 清空纹理
    [self cleanUpTextures];
}


- (void)cleanUpTextures
{
    // 清空亮度引用
    if (_luminanceTextureRef) {
        CFRelease(_luminanceTextureRef);
        _luminanceTextureRef = NULL;
    }
    
    // 清空色度引用
    if (_chrominanceTextureRef) {
        CFRelease(_chrominanceTextureRef);
        _chrominanceTextureRef = NULL;
    }
    
    // 清空纹理缓存（用这个方法）
    CVOpenGLESTextureCacheFlush(_textureCacheRef, 0);
}



@end
