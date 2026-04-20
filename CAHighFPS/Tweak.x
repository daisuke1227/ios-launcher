// Code by Nathan
// https://github.com/verygenericname

%config(generator = internal);
#import <objc/runtime.h>
#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <QuartzCore/QuartzCore.h>
#import <dlfcn.h>
//#import <CydiaSubstrate/CydiaSubstrate.h>

static NSInteger gc_max_refresh_rate(id maybeDisplayLink) {
    NSInteger maxFPS = 120;

    UIScreen* screen = UIScreen.mainScreen;
    if ([maybeDisplayLink respondsToSelector:@selector(screen)]) {
        UIScreen* displayLinkScreen = [maybeDisplayLink screen];
        if (displayLinkScreen) {
            screen = displayLinkScreen;
        }
    }

    if ([screen respondsToSelector:@selector(maximumFramesPerSecond)]) {
        NSInteger screenMaxFPS = screen.maximumFramesPerSecond;
        if (screenMaxFPS > 0) {
            maxFPS = screenMaxFPS;
        }
    }

    return MAX(maxFPS, 60);
}

static CAFrameRateRange gc_make_max_frame_rate_range(id maybeDisplayLink) {
    NSInteger maxFPS = gc_max_refresh_rate(maybeDisplayLink);
    return CAFrameRateRangeMake(maxFPS, maxFPS, maxFPS);
}

static void gc_apply_max_refresh_rate(CADisplayLink* displayLink) {
    NSInteger maxFPS = gc_max_refresh_rate(displayLink);

    if ([displayLink respondsToSelector:@selector(setPreferredFrameRateRange:)]) {
        displayLink.preferredFrameRateRange = gc_make_max_frame_rate_range(displayLink);
    }

    if ([displayLink respondsToSelector:@selector(setPreferredFramesPerSecond:)]) {
        displayLink.preferredFramesPerSecond = maxFPS;
    }
}

%hook CADynamicFrameRateSource

-(void)setPaused:(BOOL)arg1 {
    //
}

-(BOOL)isPaused {
    return NO;
}

- (void)setPreferredFrameRateRange:(CAFrameRateRange)range {
    NSInteger maxFPS = gc_max_refresh_rate(nil);
    range.minimum = maxFPS;
    range.preferred = maxFPS;
    range.maximum = maxFPS;
    %orig;
}

-(void)setHighFrameRateReasons:(const unsigned*)arg1 count:(unsigned long long)arg2 {
    //
}

/*- (double)commitDeadline { // are these really needed?
    double vsyncInterval = 1.0 / 120.0;
    double now = CACurrentMediaTime();
    double nextVsync = ceil(now / vsyncInterval) * vsyncInterval;
    
    return nextVsync;
}

- (double)commitDeadlineAfterTimestamp:(double)arg1 { // ^
    double vsyncInterval = 1.0 / 120.0;
    double now = CACurrentMediaTime();
    double nextVsync = ceil(now / vsyncInterval) * vsyncInterval;
    
    return nextVsync;
}*/

%end

%hook CADisplayLink
+ (CADisplayLink *)displayLinkWithTarget:(id)target selector:(SEL)sel {
    CADisplayLink* displayLink = %orig;
    if (displayLink) {
        gc_apply_max_refresh_rate(displayLink);
    }
    return displayLink;
}

-(void)setPaused:(BOOL)arg1 {
    //
}

-(BOOL)isPaused {
    return NO;
}

- (void)setFrameInterval:(NSInteger)interval {
    %orig(1);
    gc_apply_max_refresh_rate(self);
}

- (void)setPreferredFrameRateRange:(CAFrameRateRange)range {
    NSInteger maxFPS = gc_max_refresh_rate(self);
    range.minimum = maxFPS;
    range.preferred = maxFPS;
    range.maximum = maxFPS;
    %orig;
}

- (void)setPreferredFramesPerSecond:(NSInteger)fps {
    %orig(gc_max_refresh_rate(self));
}

- (void)addToRunLoop:(NSRunLoop*)runloop forMode:(NSRunLoopMode)mode {
    %orig;
    gc_apply_max_refresh_rate(self);
}

-(void)setHighFrameRateReasons:(const unsigned*)arg1 count:(unsigned long long)arg2 {
    //
}

%end
