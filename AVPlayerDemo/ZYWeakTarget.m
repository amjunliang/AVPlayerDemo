//
//  ZYWeakTarget.m
//  AVPlayerDemo
//
//  Created by MaJunliang on 2019/9/12.
//  Copyright © 2019 yiban. All rights reserved.
//

#import "ZYWeakTarget.h"

@interface ZYWeakTarget ()
@property (nonatomic, weak) id target;
@end

@implementation ZYWeakTarget
+ (instancetype)weakTarget:(id)target;
{
    ZYWeakTarget *weakTarget = [[ZYWeakTarget alloc]initWithTarget:target];
    return weakTarget;
}

- (instancetype)initWithTarget:(id)target {
    self = [super init];
    if (self) {
        self.target = target;
    }
    return self;
}
- (id)forwardingTargetForSelector:(SEL)selector {
    return self.target;
}
@end
