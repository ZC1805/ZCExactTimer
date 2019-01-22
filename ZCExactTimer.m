//
//  ZCExactTimer.m
//  ZCKit
//
//  Created by admin on 2019/1/11.
//  Copyright © 2019 Squat in house. All rights reserved.
//

#import "ZCExactTimer.h"

#pragma mark - Class - ZCExactTimerItem
@interface ZCExactTimerItem : NSObject

@property (nonatomic, weak) id attach;  /**< 依附对象，对象为nil时候，timer_block不执行 */

@property (nonatomic, assign) BOOL isStop;

@property (nonatomic, assign) BOOL isRepeat;

@property (nonatomic, copy) void(^timer_block)(BOOL *stop);

@end

@implementation ZCExactTimerItem

- (instancetype)initWithBlock:(void(^)(BOOL *stop))block repeat:(BOOL)repeat stop:(BOOL)stop attach:(id)attach {
    if (self = [super init]) {
        _isStop = stop;
        _attach = attach;
        _isRepeat = repeat;
        _timer_block = block;
    }
    return self;
}

@end


#pragma mark - Class - ZCExactTimer
@interface ZCExactTimer ()

@property (nonatomic, strong) NSMutableDictionary <NSString *, dispatch_source_t>*timerContainer;

@property (nonatomic, strong) NSMutableDictionary <NSString *, NSMutableArray <ZCExactTimerItem *>*>*timerMaps;

@end

@implementation ZCExactTimer

#pragma mark - Public
+ (ZCExactTimer *)instance {
    static ZCExactTimer *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken,^{
        instance = [[ZCExactTimer alloc] init];
    });
    return instance;
}

+ (void)scheduledTimer:(NSString *)timerName interval:(NSTimeInterval)interval block:(void(^)(BOOL *stop))block {
    [self scheduledTimer:timerName interval:interval queue:nil repeat:YES attach:nil option:ZCExactTimerOptionMerge block:block];
}

+ (void)scheduledTimer:(NSString *)timerName
              interval:(NSTimeInterval)interval
                 queue:(dispatch_queue_t)queue
                repeat:(BOOL)repeat
                option:(ZCExactTimerOption)option
                 block:(void(^)(BOOL *stop))block {
    [self scheduledTimer:timerName interval:interval queue:queue repeat:repeat attach:nil option:option block:block];
}

+ (void)scheduledTimer:(NSString *)timerName
              interval:(NSTimeInterval)interval
                 queue:(dispatch_queue_t)queue
                repeat:(BOOL)repeat
                attach:(id)attach
                option:(ZCExactTimerOption)option
                 block:(void(^)(BOOL *stop))block {
    /** validate */
    if (timerName == nil || timerName.length == 0) {NSAssert(0, @"timer name is invalid"); return;}
    if (block == nil || block == NULL) {NSAssert(0, @"timer block is invalid"); return;}
    if (queue == nil) queue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
    if (attach == nil) attach = [NSNull null];
    
    /** timer */
    ZCExactTimer *handle = [ZCExactTimer instance];
    dispatch_source_t timer = [handle.timerContainer objectForKey:timerName];
    if (!timer) {
        timer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, queue);
        dispatch_resume(timer);
        [handle.timerContainer setObject:timer forKey:timerName];
    }
    
    /** run */
    ZCExactTimerItem *item = [[ZCExactTimerItem alloc] initWithBlock:block repeat:repeat stop:NO attach:attach];
    dispatch_source_set_timer(timer, dispatch_time(DISPATCH_TIME_NOW, interval * NSEC_PER_SEC), interval * NSEC_PER_SEC, 0.01 * NSEC_PER_SEC);
    switch (option) { //精度为0.01秒
        case ZCExactTimerOptionAbandon: //移除之前的block
            [handle.timerMaps removeObjectForKey:timerName];
        case ZCExactTimerOptionMerge: { //存储本次的block
            [handle cacheItem:item name:timerName];
            dispatch_source_set_event_handler(timer, ^{
                __block BOOL isInspect = NO;
                NSMutableArray <ZCExactTimerItem *>*itemArr = [handle.timerMaps objectForKey:timerName];
                [itemArr enumerateObjectsUsingBlock:^(ZCExactTimerItem * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
                    BOOL timer_stop = NO;
                    if (obj.attach && obj.timer_block) {
                        obj.timer_block(&timer_stop);
                    }
                    if (timer_stop) {
                        obj.isStop = timer_stop;
                    }
                    if (!isInspect && (obj.isStop || !obj.isRepeat || !obj.attach || !obj.timer_block)) {
                        isInspect = YES;
                    }
                }];
                if (isInspect) {
                    [handle inspectItemArr:itemArr name:timerName];
                }
            });
        } break;
    }
}

+ (BOOL)existTimer:(NSString *)timerName {
    if (!timerName) return NO;
    if ([[ZCExactTimer instance].timerContainer objectForKey:timerName]) return YES;
    return NO;
}

+ (void)pauseTimer:(NSString *)timerName {
    if (!timerName) return;
    dispatch_source_t timer = [[ZCExactTimer instance].timerContainer objectForKey:timerName];
    if (!timer) return;
    dispatch_suspend(timer);
}

+ (void)resumeTimer:(NSString *)timerName {
    if (!timerName) return;
    dispatch_source_t timer = [[ZCExactTimer instance].timerContainer objectForKey:timerName];
    if (!timer) return;
    dispatch_resume(timer);
}

+ (void)invalidateTimer:(NSString *)timerName {
    if (!timerName) return;
    [[ZCExactTimer instance] invalidateTimerForName:timerName];
}

#pragma mark - Private
- (void)invalidateTimerForName:(NSString *)timerName {
    if (timerName == nil) {
        NSArray *allNames = self.timerContainer.allKeys;
        for (NSString *name in allNames) {
            [self invalidateTimerForName:name];
        }
        return;
    }
    dispatch_source_t timer = [self.timerContainer objectForKey:timerName];
    if (timer) {
        [self.timerContainer removeObjectForKey:timerName];
        dispatch_source_cancel(timer);
        timer = nil;
        [self.timerMaps removeObjectForKey:timerName];
    } else {
        [self.timerContainer removeObjectForKey:timerName];
        [self.timerMaps removeObjectForKey:timerName];
    }
}

- (void)inspectItemArr:(NSMutableArray <ZCExactTimerItem *>*)itemArr name:(NSString *)name {
    NSMutableArray <ZCExactTimerItem *>*invalidArr = [NSMutableArray array];
    for (ZCExactTimerItem *item in itemArr) {
        if (item.isStop || !item.isRepeat || !item.attach || !item.timer_block) {
            [invalidArr addObject:item];
        }
    }
    if (invalidArr.count) {
        [itemArr removeObjectsInArray:invalidArr];
    }
    if (!itemArr.count) {
        [self invalidateTimerForName:name];
    }
}

- (void)cacheItem:(ZCExactTimerItem *)item name:(NSString *)name {
    NSMutableArray <ZCExactTimerItem *>*itemArr = [self.timerMaps objectForKey:name];
    if (itemArr) {
        [itemArr addObject:item];
    } else {
        itemArr = [NSMutableArray arrayWithObject:item];
        [self.timerMaps setObject:itemArr forKey:name];
    }
}

#pragma mark - Getter
- (NSMutableDictionary <NSString *, dispatch_source_t>*)timerContainer {
    if (!_timerContainer) {
        _timerContainer = [[NSMutableDictionary alloc] init];
    }
    return _timerContainer;
}

- (NSMutableDictionary <NSString *, NSMutableArray <ZCExactTimerItem *>*>*)timerMaps {
    if (!_timerMaps) {
        _timerMaps = [[NSMutableDictionary alloc] init];
    }
    return _timerMaps;
}

@end


#pragma mark - Class - NSObject (ZC_Timer)
static NSString *zc_global_timer = @"zc_global_timer";
@implementation NSObject (ZC_Timer)

- (void)scheduledGlobalTimer:(void(^)(BOOL *stop))block {
    if (!self) {NSAssert(0, @"self is nil object"); return;}
    [ZCExactTimer scheduledTimer:zc_global_timer interval:1.0 queue:nil repeat:YES attach:self option:ZCExactTimerOptionMerge block:block];
}

@end
