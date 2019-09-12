//
//  ZYMediaPlayer.m
//  AVPlayerDemo
//
//  Created by MaJunliang on 2019/9/11.
//  Copyright © 2019 yiban. All rights reserved.
//

#import "ZYMediaPlayer.h"
#import "ZYWeakTarget.h"

@interface ZYMediaPlayer () {
    AVPlayer *_player;
    AVPlayerLayer *_playerLayer;
    AVPlayerItem *_playerItem;
    
    id _playerTimeObserver;
}

@property (nonatomic, strong) NSString *mediaUrl;
@property(nonatomic, strong) CADisplayLink *link; //loading监控
@property(nonatomic, assign) BOOL readyToPlay;

@end

@implementation ZYMediaPlayer

- (instancetype)initWithUrl:(NSString *)mediaUrl
{
    if (self = [super init]) {
        self.mediaUrl = mediaUrl;
        [self setup];
        
    }
    return self;
}

- (void)play {
    if ([self errorCheckNotiDelegate:YES]) {
        return;
    }

    if ([self isPlaying]) {
        return;
    }
    NSError *error;
    AVAudioSession *session = [AVAudioSession sharedInstance];
    [session setCategory:AVAudioSessionCategoryPlayback withOptions:AVAudioSessionCategoryOptionDefaultToSpeaker error:&error];
    if (error) {
        NSLog(@"%@", error);
    }
    [_player play];
}

- (void)replay {
    if ([self errorCheckNotiDelegate:YES]) {
        return;
    }

    [_player seekToTime:kCMTimeZero];
    [self play];
}

- (void)pause {
    if ([self errorCheckNotiDelegate:NO]) {
        return;
    }

    if (![self isPlaying]) {
        return;
    }
    [_player pause];
}

- (BOOL)isPlaying {
    return _player.rate != 0;
}

- (BOOL)isPlayFinish {
    if ([self duration] == 0) {
        return NO;
    }
    BOOL result = [self duration] > [self currentTime];
    return !result;
}

- (void)seekToTime:(NSTimeInterval)seconds complete:(void (^)(BOOL finished))complete{
    if ([self errorCheckNotiDelegate:YES]) {
        return;
    }

    NSTimeInterval time = seconds;
    if (time < 0) {
        time = 0;
    }
    NSTimeInterval duration = [self duration];
    if (time > duration) {
        time = duration;
    }
    
    [_player seekToTime:CMTimeMakeWithSeconds(time, 600) toleranceBefore:kCMTimeZero toleranceAfter:kCMTimeZero completionHandler:complete];
}

- (NSTimeInterval)duration {
    NSTimeInterval duration = CMTimeGetSeconds(_player.currentItem.duration);
    return [self safeDouble:duration];
}

- (NSTimeInterval)currentTime {
    NSTimeInterval time = CMTimeGetSeconds(_player.currentTime);
    return [self safeDouble:time];
}

- (void)mute:(BOOL)mute {
    if ([self errorCheckNotiDelegate:YES]) {
        return;
    }

    _player.muted = mute;
}

- (AVPlayerLayer *)layer {
    return _playerLayer;
}

#pragma mark - Private
- (void)dealloc {
    [_player pause];
    [self removeObserver];
    [self removePlayStatuCheck];
}

- (NSTimeInterval)availableDuration {
    if (!self.readyToPlay) {
        return 0;
    }
    
    NSArray *loadedTimeRanges = [_playerItem loadedTimeRanges];
    CMTimeRange timeRange = [loadedTimeRanges.firstObject CMTimeRangeValue];// 获取缓冲区域
    float startSeconds = CMTimeGetSeconds(timeRange.start);
    float durationSeconds = CMTimeGetSeconds(timeRange.duration);
    NSTimeInterval result = startSeconds + durationSeconds;// 计算缓冲总进度
    return [self safeDouble:result];
}

- (double)safeDouble:(double)value
{
    if (isnan(value)) {
        return 0;
    }
    
    if (value == 0) {
        return 0;
    }
    return value;
}

- (void)updateUI
{
    if ([self errorCheckNotiDelegate:NO]) {
        return;
    }
    
    double currentTime = [self currentTime];
    double availableDuration = [self availableDuration];// 计算缓冲进度
    
    BOOL isLoad = NO;
    for (NSValue *value in _playerItem.loadedTimeRanges) {
        CMTimeRange range = value.CMTimeRangeValue;
        if( CMTimeRangeContainsTime(range, _playerItem.currentTime) &&
           CMTimeGetSeconds(range.duration) > 1 &&
           _playerItem.isPlaybackLikelyToKeepUp
           ) {
            isLoad = YES;
            break;
        }
    }
    
    if (self.delegate && [self.delegate respondsToSelector:@selector(playerUpdate:currentTime:availableDuration:resourceLoaded:)]) {
        [self.delegate playerUpdate:self currentTime:currentTime availableDuration:availableDuration resourceLoaded:isLoad];
    }
}

- (void)removePlayStatuCheck
{
    [self.link invalidate];
    self.link = nil;
}

- (void)addPlayStatuCheck
{
    if (!self.link) {
        self.link = [CADisplayLink displayLinkWithTarget:[ZYWeakTarget weakTarget:self] selector:@selector(updateUI)];
        [self.link addToRunLoop:[NSRunLoop mainRunLoop] forMode:NSRunLoopCommonModes];
    }
}

- (void)setup {
    _readyToPlay = NO;

    if (_player) {
        [self removeObserver];
        [self removePlayStatuCheck];
    }
    
    NSURL *url = [NSURL URLWithString:self.mediaUrl];
    if (self.mediaUrl.length) {
        url = [NSURL URLWithString:self.mediaUrl];
    }
    
    if (!url) {
       NSError *error = [NSError errorWithDomain:[NSString stringWithFormat:@"com.iReader.%@",NSStringFromClass(self.class)] code:-1 userInfo:[NSDictionary dictionaryWithObjectsAndKeys:@"播放链接无效",NSLocalizedDescriptionKey,nil]];
        if (self.delegate && [self.delegate respondsToSelector:@selector(player:didFailToPlay:)]) {
            [self.delegate player:self didFailToPlay:error];
        }
        return;
    }
    _playerItem = [AVPlayerItem playerItemWithURL:url];
    _player = [AVPlayer playerWithPlayerItem:_playerItem];
    _playerLayer = [AVPlayerLayer playerLayerWithPlayer:_player];
    _playerLayer.videoGravity = AVLayerVideoGravityResizeAspect;
    
    [self addObserver];
    [self addPlayStatuCheck];
}

- (void)addObserver {
    if (!_player) {
        return;
    }
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(playFinished:) name:AVPlayerItemDidPlayToEndTimeNotification object:_player.currentItem];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(playFailed:) name:AVPlayerItemFailedToPlayToEndTimeNotification object:_player.currentItem];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(playStalled:) name:AVPlayerItemPlaybackStalledNotification object:_player.currentItem];
    
    [_playerItem addObserver:self forKeyPath:@"status" options:NSKeyValueObservingOptionOld | NSKeyValueObservingOptionNew context:nil];//播放状态
    [_player addObserver:self forKeyPath:@"rate" options:NSKeyValueObservingOptionNew context:nil];//播放速率
}

- (void)removeObserver {
    if (!_player) {
        return;
    }
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [_playerItem removeObserver:self forKeyPath:@"status"];
    [_player removeObserver:self forKeyPath:@"rate"];
}

- (void)playFinished:(NSNotification *)notification {
    if ([self errorCheckNotiDelegate:YES]) {
        return;
    }

    if (self.delegate && [self.delegate respondsToSelector:@selector(playerDidPlayFinish:)]) {
        [self.delegate playerDidPlayFinish:self];
    }
}

- (void)playStalled:(NSNotification *)notification {
    if (self.delegate && [self.delegate respondsToSelector:@selector(playerDidStalled:)]) {
        [self.delegate playerDidStalled:self];
    }
}

- (void)playFailed:(NSNotification *)notification {
    [self errorCheckNotiDelegate:YES];
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary<NSKeyValueChangeKey,id> *)change context:(void *)context {
    if (_player == nil) {
        return;
    }
    
    if ([keyPath isEqualToString:@"status"]) {//播放状态
        switch (_player.currentItem.status) {
            case AVPlayerItemStatusUnknown:
                //资源尚未载入，不在播放队列中
                [self errorCheckNotiDelegate:YES];
                break;
            case AVPlayerItemStatusReadyToPlay:
                self.readyToPlay = YES;
                if (self.delegate && [self.delegate respondsToSelector:@selector(player:didReadyToPlay:)]) {
                    [self.delegate player:self didReadyToPlay:[self duration]];
                }
                [self updateUI];
                break;
            case AVPlayerItemStatusFailed:
                [self errorCheckNotiDelegate:YES];
                break;
            default:
                break;
        }
    } else if ([keyPath isEqualToString:@"rate"]) {//播放速率
    } else if ([keyPath isEqualToString:@"loadedTimeRanges"]) {//缓冲
    } else if ([keyPath isEqualToString:@"playbackLikelyToKeepUp"]) {//buffer好了，可播放
    } else if ([keyPath isEqualToString:@"playbackBufferEmpty"]) { //buffer空了
    }
}

- (BOOL)errorCheckNotiDelegate:(BOOL)notiDelegate
{
    if (!_player) {
        return NO;
    }
    
    NSError *error = nil;
    BOOL needReset = NO;

    if (!self.readyToPlay) {
        error = [NSError errorWithDomain:[NSString stringWithFormat:@"com.iReader.%@",NSStringFromClass(self.class)] code:-1 userInfo:[NSDictionary dictionaryWithObjectsAndKeys:@"播放器未初始化完成无效",NSLocalizedDescriptionKey,nil]];
    }
    
    if (!error && _player.error) {
        error = _player.error;
        needReset = YES;
    }
    
    if (!error && _playerItem.error) {
        error = _playerItem.error;
        needReset = YES;
    }
    
    if (needReset) {
        [self setup];
    }
    
    if (error) {
        if (notiDelegate && self.delegate && [self.delegate respondsToSelector:@selector(player:didFailToPlay:)]) {
            [self.delegate player:self didFailToPlay:error];
        }
        return YES;
    } else {
        return NO;
    }
}

@end
