//
//  ZCExactTimer.h
//  ZCKit
//
//  Created by admin on 2019/1/11.
//  Copyright © 2019 Squat in house. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSUInteger, ZCExactTimerOption) {
    ZCExactTimerOptionAbandon = 0,  /**< 废除之前的同名的任务 */
    ZCExactTimerOptionMerge   = 1,  /**< 合并之前的同名的任务，interval以当前的为准 */
};

@interface ZCExactTimer : NSObject  /**< 精确通用计时器 */

/**
 *  启动一个timer，默认精度为0.01s，不会立即执行，至少会执行一次，repeat或stop且只有一个block时会自动销毁。
 *  @param timerName    timer的名称，作为唯一标识，非空。
 *  @param interval     timer执行的时间间隔。
 *  @param queue        timer将被放入的队列，也就是最终block执行的队列，传入nil将自动放到一个子线程队列中。
 *  @param repeat       timer是否循环调用。
 *  @param option       timer多次schedule同一个timer时的操作选项。
 *  @param block        timer时间间隔到点时执行的block，非空。
 */
+ (void)scheduledTimer:(NSString *)timerName
              interval:(NSTimeInterval)interval
                 queue:(dispatch_queue_t)queue
                repeat:(BOOL)repeat
                option:(ZCExactTimerOption)option
                 block:(void(^)(BOOL *stop))block;

/** block在全局队列中执行，适当时候回到主队列 (repeat: yes，option: merge，queue: global default) */
+ (void)scheduledTimer:(NSString *)timerName interval:(NSTimeInterval)interval block:(void(^)(BOOL *stop))block;

/** 暂停某个timer */
+ (void)pauseTimer:(NSString *)timerName;

/** 恢复某个timer */
+ (void)resumeTimer:(NSString *)timerName;

/** 撤销某个timer，设置nil的话则撤销所有timer */
+ (void)invalidateTimer:(nullable NSString *)timerName;

/** 是否存在某个名称标识的timer */
+ (BOOL)existTimer:(NSString *)timerName;

@end


@interface NSObject (ZC_Timer)  /**< 全局计时器 */

/** 全局的，时间间隔设置为1s，block在self变为nil时候或者stop时候自动销毁，block在全局队列中执行，适当时候回到主队列 */
- (void)scheduledGlobalTimer:(void(^)(BOOL *stop))block;

@end

NS_ASSUME_NONNULL_END
