//
//  ViewController.m
//  AVPlayerDemo
//
//  Created by CaoJie on 14-5-5.
//  Copyright (c) 2014年 yiban. All rights reserved.
//

#import "ViewController.h"
#import <AVFoundation/AVFoundation.h>
#import "PlayerView.h"

// http://v.jxvdy.com/sendfile/w5bgP3A8JgiQQo5l0hvoNGE2H16WbN09X-ONHPq3P3C1BISgf7C-qVs6_c8oaw3zKScO78I--b0BGFBRxlpw13sf2e54QA

@interface ViewController () {
    BOOL _played;
    BOOL _slide;
    BOOL _seek;

    NSDateFormatter *_dateFormatter;
}

@property (nonatomic ,weak) IBOutlet UIButton *stateButton; //播放按钮
@property (nonatomic ,weak) IBOutlet UILabel *timeLabel; //时间信息
@property (nonatomic ,weak) IBOutlet UISlider *videoSlider; // 滑动条
@property (nonatomic ,weak) IBOutlet UIProgressView *videoProgress; // 缓存进度
@property (nonatomic ,weak) IBOutlet UIActivityIndicatorView *indicatorView; // loading状态


@property (nonatomic ,strong) AVPlayer *player;
@property (nonatomic ,strong) AVPlayerItem *playerItem;
@property (nonatomic ,weak) IBOutlet PlayerView *playerView;
@property (nonatomic ,strong) id playbackTimeObserver;


- (IBAction)stateButtonTouched:(id)sender;
- (IBAction)videoSlierChangeValue:(id)sender;
- (IBAction)videoSlierChangeValueEnd:(id)sender;

@property(nonatomic, strong) CADisplayLink *link; //卡顿监控

@end

@implementation ViewController
//static NSString * const kTestURL = @"http://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ForBiggerJoyrides.mp4";
//static NSString * const kTestURL = @"http://v.jxvdy.com/sendfile/w5bgP3A8JgiQQo5l0hvoNGE2H16WbN09X-ONHPq3P3C1BISgf7C-qVs6_c8oaw3zKScO78I--b0BGFBRxlpw13sf2e54QA";
static NSString * const kTestURL = @"http://commondatastorage.googleapis.com/gtv-videos-bucket/sample/BigBuckBunny.mp4";

- (void)removePlayLoadingCheck
{
    [self.link invalidate];
    self.link = nil;
}
- (void)addPlayLoadingCheck
{
    self.link = [CADisplayLink displayLinkWithTarget:self selector:@selector(updateUI)];
    [self.link addToRunLoop:[NSRunLoop mainRunLoop] forMode:NSRunLoopCommonModes];
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    _timeLabel.textAlignment = NSTextAlignmentCenter;
    
    NSURL *videoUrl = [NSURL URLWithString:kTestURL];
    self.playerItem = [AVPlayerItem playerItemWithURL:videoUrl];
    [self.playerItem addObserver:self forKeyPath:@"status" options:NSKeyValueObservingOptionNew context:nil];// 监听status属性
    [self.playerItem addObserver:self forKeyPath:@"loadedTimeRanges" options:NSKeyValueObservingOptionNew context:nil];// 监听loadedTimeRanges属性
    self.player = [AVPlayer playerWithPlayerItem:self.playerItem];
    self.player.automaticallyWaitsToMinimizeStalling = NO;
    self.playerView.player = _player;
    self.stateButton.enabled = NO;
    self.videoSlider.userInteractionEnabled = NO;
    [self.indicatorView startAnimating];

    [self customVideoSlider];
    // 添加视频播放结束通知
    [[NSNotificationCenter defaultCenter]addObserver:self selector:@selector(moviePlayDidEnd:) name:AVPlayerItemDidPlayToEndTimeNotification object:_playerItem];
//    [self monitoringPlayback:self.playerItem];// 监听播放状态
    [self addPlayLoadingCheck];
}

- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    _playerView.frame = self.view.bounds;
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
}

- (void)monitoringPlayback:(AVPlayerItem *)playerItem {
    
    __weak typeof(self) weakSelf = self;
    self.playbackTimeObserver = [self.playerView.player addPeriodicTimeObserverForInterval:CMTimeMake((1/24.0)*600, 600) queue:NULL usingBlock:^(CMTime time) {
        //[weakSelf updateUI];
    }];
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
    double duration = [self safeDouble: CMTimeGetSeconds(self.playerItem.duration)] ?:1;
    double current = [self safeDouble: CMTimeGetSeconds(self.playerItem.currentTime)];
    
    if (!_slide) {
        self.videoSlider.value = current/duration;
        self.timeLabel.text = [NSString stringWithFormat:@"%.fs/%.fs",current,duration];
    }
    
    double availableDuration =  [self safeDouble: [self availableDuration]];// 计算缓冲进度
    [self.videoProgress setProgress:availableDuration / duration animated:NO];

    BOOL isLoad = NO;
    for (NSValue *value in self.playerItem.loadedTimeRanges) {
        if( CMTimeRangeContainsTime(value.CMTimeRangeValue, self.playerItem.currentTime)) {
            isLoad = YES;
            break;
        }
    }

    
    if (_played) {
        if (isLoad) {
            [self.indicatorView stopAnimating];
            if (self.player.rate == 0) {
                self.player.rate = 1;
            }
        } else {
            [self.indicatorView startAnimating];
        }
       
    } else {
        if (!isLoad && _seek) {
            [self.indicatorView startAnimating];
        } else {
            [self.indicatorView stopAnimating];
        }
    }
}

// KVO方法
- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context {
    AVPlayerItem *playerItem = (AVPlayerItem *)object;
    if (object == self.playerItem) {
        [self.indicatorView stopAnimating];
        if ([keyPath isEqualToString:@"status"]) {
            if ([playerItem status] == AVPlayerStatusReadyToPlay) {
                NSLog(@"AVPlayerStatusReadyToPlay");
                self.stateButton.enabled = YES;
                self.videoSlider.userInteractionEnabled = YES;
            } else if ([playerItem status] == AVPlayerStatusFailed) {
                NSLog(@"AVPlayerStatusFailed");
            }
        }
    }
}

- (NSTimeInterval)availableDuration {
    NSArray *loadedTimeRanges = [[self.playerView.player currentItem] loadedTimeRanges];
    CMTimeRange timeRange = [loadedTimeRanges.firstObject CMTimeRangeValue];// 获取缓冲区域
    float startSeconds = CMTimeGetSeconds(timeRange.start);
    float durationSeconds = CMTimeGetSeconds(timeRange.duration);
    NSTimeInterval result = startSeconds + durationSeconds;// 计算缓冲总进度
    return result;
}

- (void)customVideoSlider
{
    UIGraphicsBeginImageContextWithOptions((CGSize){ 1, 1 }, NO, 0.0f);
    UIImage *transparentImage = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    [self.videoSlider setMinimumTrackImage:transparentImage forState:UIControlStateNormal];
    [self.videoSlider setMaximumTrackImage:transparentImage forState:UIControlStateNormal];
    [self.videoSlider layoutIfNeeded];
}

- (IBAction)stateButtonTouched:(id)sender {
    if (!_played) {
        [self.playerView.player play];
        [self.stateButton setTitle:@"Stop" forState:UIControlStateNormal];
    } else {
        [self.playerView.player pause];
        [self.stateButton setTitle:@"Play" forState:UIControlStateNormal];
    }
    _played = !_played;
}

- (IBAction)videoSlierChangeValueBegin:(id)sender {
    _slide = YES;
}

- (IBAction)videoSlierChangeValue:(id)sender {
    
}

- (void)seekTo:(CMTime)time complate:(void (^)(void))complate
{
    _seek = YES;
    [self.playerView.player seekToTime:time toleranceBefore:kCMTimeZero toleranceAfter:kCMTimeZero completionHandler:^(BOOL finished) {
        if (complate) {
            complate();
            self->_seek = NO;
        }
    }];
}

- (IBAction)videoSlierChangeValueEnd:(id)sender {
    UIControl *c= nil;
    self->_slide  = NO;
    __weak typeof(self) weakSelf = self;
    [self seekTo:CMTimeMakeWithSeconds(CMTimeGetSeconds(self.playerItem.duration) * self.videoSlider.value, 600) complate:^{
        if (self->_played) {
            [weakSelf.playerView.player play];
            [weakSelf.stateButton setTitle:@"Stop" forState:UIControlStateNormal];
        }
    }];
}

- (void)updateVideoSlider:(CGFloat)currentSecond {
    [self.videoSlider setValue:currentSecond animated:YES];
}


- (void)moviePlayDidEnd:(NSNotification *)notification {
    NSLog(@"Play end");
    [self seekTo:kCMTimeZero complate:nil];
}

- (NSString *)convertTime:(CGFloat)second{
    NSDate *d = [NSDate dateWithTimeIntervalSince1970:second];
    if (second/3600 >= 1) {
        [[self dateFormatter] setDateFormat:@"HH:mm:ss"];
    } else {
        [[self dateFormatter] setDateFormat:@"mm:ss"];
    }
    NSString *showtimeNew = [[self dateFormatter] stringFromDate:d];
    return showtimeNew;
}

- (NSDateFormatter *)dateFormatter {
    if (!_dateFormatter) {
        _dateFormatter = [[NSDateFormatter alloc] init];
    }
    return _dateFormatter;
}

- (void)dealloc {
    [self.playerItem removeObserver:self forKeyPath:@"status" context:nil];
    [self.playerItem removeObserver:self forKeyPath:@"loadedTimeRanges" context:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:AVPlayerItemDidPlayToEndTimeNotification object:self.playerItem];
    [self.playerView.player removeTimeObserver:self.playbackTimeObserver];
    [self removePlayLoadingCheck];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

@end
