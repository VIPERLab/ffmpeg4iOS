//
//  AudioEngine.m
//  ffmpeg4iOS
//
//  Created by Wayne W. on 15/7/16.
//  Copyright (c) 2015年 github.com/henern. All rights reserved.
//

#import "AudioEngine.h"

@implementation DEF_CLASS(AudioEngine)

- (BOOL)attachTo:(AVStream*)stream err:(int*)errCode
{
    stream->discard = AVDISCARD_NONE;   // AVDISCARD_DEFAULT
    
    return YES;
}

@end
