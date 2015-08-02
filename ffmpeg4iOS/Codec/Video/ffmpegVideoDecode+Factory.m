//
//  ffmpegVideoDecode+Factory.m
//  ffmpeg4iOS
//
//  Created by Wayne W on 15/8/2.
//  Copyright (c) 2015年 github.com/henern. All rights reserved.
//

#import "ffmpegVideoDecode+Factory.h"
#import "ffmpegVideoDecode.h"
#import <UIKit/UIKit.h>
#import "VTBVideoDecode.h"

@implementation DEF_CLASS(ffmpegVideoDecode) (Factory)

+ (REF_CLASS(ffmpegVideoDecode))decoder4codec:(AVCodecContext*)ctxCodec
{
    if ([DEF_CLASS(VTBVideoDecode) supportCodec:ctxCodec])
    {
        return [[DEF_CLASS(VTBVideoDecode) alloc] init];
    }
    
    return [[DEF_CLASS(ffmpegVideoDecode) alloc] init];
}

@end
