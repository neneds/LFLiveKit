//
//  LFLiveDebug.m
//  LaiFeng
//
//  Created by LaiFeng on 16/5/20.
//  Copyright © 2016年 LaiFeng All rights reserved.
//

#import "LFLiveDebug.h"

@implementation LFLiveDebug

- (NSString *)description {
    return [NSString stringWithFormat:@"丢掉的帧数:%ld 总帧数:%ld 上次的音频捕获个数:%ld 上次的视频捕获个数:%ld 未发送个数:%ld 总流量:%0.f",(long)_dropFrame,_totalFrame,(long)_currentCapturedAudioCount,(long)_currentCapturedVideoCount,_unSendCount,_dataFlow];
}


@end
