#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <QuartzCore/QuartzCore.h>

static NSString *const kLogPath = @"/var/mobile/Documents/LiquidMorph.log";

static void LMLog(NSString *format, ...) {
    va_list args;
    va_start(args, format);
    NSString *message = [[NSString alloc] initWithFormat:format arguments:args];
    va_end(args);

    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    formatter.dateFormat = @"yyyy-MM-dd HH:mm:ss.SSS";
    NSString *line = [NSString stringWithFormat:@"[%@] %@\n", [formatter stringFromDate:[NSDate date]], message];

    @try {
        NSFileManager *fm = [NSFileManager defaultManager];
        if (![fm fileExistsAtPath:kLogPath]) {
            [fm createFileAtPath:kLogPath contents:nil attributes:nil];
        }
        NSFileHandle *handle = [NSFileHandle fileHandleForWritingAtPath:kLogPath];
        if (handle) {
            [handle seekToEndOfFile];
            [handle writeData:[line dataUsingEncoding:NSUTF8StringEncoding]];
            [handle closeFile];
        }
    } @catch (NSException *e) {
        NSLog(@"[LiquidMorph] Log write failed: %@", e.reason);
    }
    NSLog(@"[LiquidMorph] %@", message);
}

// Tao path bo goc tai 1 rect + ban kinh cho truoc.
static UIBezierPath *LMRoundedPath(CGRect rect, CGFloat radius) {
    if (radius < 0) radius = 0;
    return [UIBezierPath bezierPathWithRoundedRect:rect cornerRadius:radius];
}

// Ve overlay morph tu iconFrame (nho, bo goc nhieu) den fullscreen (bo goc it),
// co overshoot nhe roi settle - chi la lop test hien thi, chua thay the
// transition that cua he thong.
static void LMPlayMorphOverlay(CGRect iconFrame) {
    UIWindow *window = nil;
    for (UIWindow *w in [UIApplication sharedApplication].windows) {
        if (w.isKeyWindow) { window = w; break; }
    }
    if (!window) window = [UIApplication sharedApplication].windows.firstObject;
    if (!window) { LMLog(@"Morph: khong tim thay window"); return; }

    CGRect screenBounds = window.bounds;

    CAShapeLayer *shape = [CAShapeLayer layer];
    shape.fillColor = [UIColor colorWithWhite:1.0 alpha:0.85].CGColor;
    shape.frame = screenBounds;
    shape.zPosition = 9999;
    [window.layer addSublayer:shape];

    // Cac keyframe: [tien do 0..1, rect, ban kinh bo goc]
    // Kich thuoc overshoot nhe o frame giua (~70%) truoc khi settle ve full.
    NSInteger steps = 10;
    NSMutableArray *paths = [NSMutableArray array];

    CGFloat startRadius = 22.0;
    CGFloat endRadius = 0.0;

    for (NSInteger i = 0; i <= steps; i++) {
        CGFloat t = (CGFloat)i / (CGFloat)steps;

        // Easing rieng cho size: bat dau nhanh, overshoot nhe qua fullscreen roi tro lai.
        CGFloat sizeT = t;
        CGFloat overshoot = 0.0;
        if (t > 0.6 && t < 1.0) {
            CGFloat local = (t - 0.6) / 0.4; // 0..1 trong doan overshoot
            overshoot = sinf(local * M_PI) * 0.04; // phinh ra toi da 4%
        }

        CGFloat x = iconFrame.origin.x + (screenBounds.origin.x - iconFrame.origin.x) * sizeT;
        CGFloat y = iconFrame.origin.y + (screenBounds.origin.y - iconFrame.origin.y) * sizeT;
        CGFloat w = iconFrame.size.width + (screenBounds.size.width - iconFrame.size.width) * (sizeT + overshoot);
        CGFloat h = iconFrame.size.height + (screenBounds.size.height - iconFrame.size.height) * (sizeT + overshoot);

        CGRect frame = CGRectMake(x, y, w, h);

        // Ban kinh bo goc giam CHAM hon size luc dau, roi rot nhanh ve cuoi
        // (giong hieu ung trong anh - goc van con bo ro khi kich thuoc da gan full).
        CGFloat radiusT = powf(t, 2.2);
        CGFloat radius = startRadius + (endRadius - startRadius) * radiusT;

        [paths addObject:(id)LMRoundedPath(frame, radius).CGPath];
    }

    CAKeyframeAnimation *anim = [CAKeyframeAnimation animationWithKeyPath:@"path"];
    anim.values = paths;
    anim.duration = 0.55;
    anim.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseOut];
    anim.fillMode = kCAFillModeForwards;
    anim.removedOnCompletion = NO;

    shape.path = (CGPathRef)paths.lastObject;
    [shape addAnimation:anim forKey:@"morph"];

    LMLog(@"Morph overlay played | from: %@ to: %@", NSStringFromCGRect(iconFrame), NSStringFromCGRect(screenBounds));

    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [shape removeFromSuperlayer];
    });
}

@interface SBIconView : UIView
- (id)icon;
@end

@interface SBIcon : NSObject
- (NSString *)displayName;
@end

%hook SBIconView

- (void)_handleTap {
    @try {
        id icon = [self valueForKey:@"icon"];
        NSString *name = @"unknown";
        if (icon && [icon respondsToSelector:@selector(displayName)]) {
            name = [icon performSelector:@selector(displayName)] ?: @"unknown";
        }
        CGRect frameInWindow = [self.window convertRect:self.bounds fromView:self];
        LMLog(@"_handleTap fired | icon: %@ | frame: %@", name, NSStringFromCGRect(frameInWindow));
        LMPlayMorphOverlay(frameInWindow);
    } @catch (NSException *e) {
        LMLog(@"Exception in _handleTap: %@", e.reason);
    }
    %orig;
}

%end

%ctor {
    LMLog(@"=== LiquidMorph loaded | process: %@ | iOS %@ ===",
          [[NSProcessInfo processInfo] processName],
          [[UIDevice currentDevice] systemVersion]);
}
