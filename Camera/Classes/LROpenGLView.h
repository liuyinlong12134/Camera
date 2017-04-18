//
//  LROpenGLView.h
//  LRGPUimage
//
//  Created by liurui on 2016/8/10.
//  Copyright © 2016年 liurui. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <AVFoundation/AVFoundation.h>

@interface LROpenGLView : UIView


- (void)displayWithSampleBuffer: (CMSampleBufferRef)sampleBuffer;



@end
