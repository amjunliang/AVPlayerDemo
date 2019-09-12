//
//  ZYMediaPlayView.m
//  AVPlayerDemo
//
//  Created by MaJunliang on 2019/9/11.
//  Copyright © 2019 yiban. All rights reserved.
//

#import "ViewController.h"
#import <AVFoundation/AVFoundation.h>
#import "PlayerView.h"
#import "ZYMediaPlayer.h"

// http://v.jxvdy.com/sendfile/w5bgP3A8JgiQQo5l0hvoNGE2H16WbN09X-ONHPq3P3C1BISgf7C-qVs6_c8oaw3zKScO78I--b0BGFBRxlpw13sf2e54QA

@interface ViewController () <ZYMediaPlayerDelegate> {
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
@property(nonatomic, strong) ZYMediaPlayer *player;

@end

@implementation ViewController
static NSString * const kTestURL = @"http://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ForBiggerJoyrides.mp4";
//static NSString * const kTestURL = @"http://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ElephantsDream.mp4";

- (void)viewDidLoad
{
    self.view.backgroundColor =
    self.view.window.backgroundColor =
    UIColor.blackColor;
    [super viewDidLoad];
    _timeLabel.textAlignment = NSTextAlignmentCenter;
    self.stateButton.enabled = NO;
    self.videoSlider.userInteractionEnabled = NO;
    [self.indicatorView startAnimating];
    [self customVideoSlider];

    self.player = [[ZYMediaPlayer alloc] initWithUrl:kTestURL];
    if (self.player) {
        [self.view.layer insertSublayer:self.player.layer atIndex:0];
        self.player.delegate = self;
    }
}

- (void)viewDidLayoutSubviews {
    self.view.backgroundColor =
    self.view.window.backgroundColor =
    UIColor.blackColor;
    [super viewDidLayoutSubviews];
    self.player.layer.frame = self.view.bounds;
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    [self.player pause];
}


#pragma mark - # ZYMediaPlayerDelegate
- (void)player:(ZYMediaPlayer *)player didReadyToPlay:(NSTimeInterval)duration
{
    [self.indicatorView stopAnimating];
    self.stateButton.enabled = YES;
    self.videoSlider.userInteractionEnabled = YES;
    [self stateButtonTouched:nil];
}

- (void)player:(ZYMediaPlayer *)player didFailToPlay:(NSError *)error
{
    NSLog(@"error: %@",error.localizedDescription);
}

- (void)playerDidPlayFinish:(ZYMediaPlayer *)player
{
    [self.player replay];
}

- (void)playerDidStalled:(ZYMediaPlayer *)player
{
    
}

- (void)playerUpdate:(ZYMediaPlayer *)player
         currentTime:(NSTimeInterval)currentTime
   availableDuration:(NSTimeInterval)availableDuration
      resourceLoaded:(BOOL)isLoad
{
    
    if (!_slide) {
        self.videoSlider.value = currentTime/(self.player.duration ?:1);
        self.timeLabel.text = [NSString stringWithFormat:@"%.fs/%.fs",currentTime,self.player.duration];
    }
    
    [self.videoProgress setProgress:availableDuration/(self.player.duration?:1) animated:NO];
    
    if (_played) {
        if (isLoad) {
            [self.indicatorView stopAnimating];
            if (!self.player.isPlaying) {
                [self.player play];
            }
        } else {
            [self.indicatorView startAnimating];
        }
    }
}

#pragma mark - # ---

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
        [self.player play];
        [self.stateButton setTitle:@"Stop" forState:UIControlStateNormal];
    } else {
        [self.player pause];
        [self.indicatorView stopAnimating];
        [self.stateButton setTitle:@"Play" forState:UIControlStateNormal];
    }
    _played = !_played;
}

- (IBAction)videoSlierChangeValueBegin:(id)sender {
    _slide = YES;
}

- (IBAction)videoSlierChangeValue:(id)sender {
    
}

- (IBAction)videoSlierChangeValueEnd:(id)sender {
    _slide = NO;
    _seek = YES;
    __weak typeof(self) weakSelf = self;
    [self.player seekToTime:self.player.duration * self.videoSlider.value  complete:^(BOOL finished) {
        if (self->_played) {
            [weakSelf.player play];
            [weakSelf.stateButton setTitle:@"Stop" forState:UIControlStateNormal];
        }
        self->_seek = NO;
    }];
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

@end
