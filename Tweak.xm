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
        if (![fm fileExistsAtPath:kLogPath]) [fm createFileAtPath:kLogPath contents:nil attributes:nil];
        NSFileHandle *handle = [NSFileHandle fileHandleForWritingAtPath:kLogPath];
        if (handle) {
            [handle seekToEndOfFile];
            [handle writeData:[line dataUsingEncoding:NSUTF8StringEncoding]];
            [handle closeFile];
        }
    } @catch (NSException *e) { NSLog(@"[LiquidMorph] Log write failed: %@", e.reason); }
    NSLog(@"[LiquidMorph] %@", message);
}

static BOOL gCaptureEnabled = NO;

// Danh sach tu khoa quan tam - lien quan truc tiep den viec phong to/bien
// dang hinh dang. KHONG con loc theo kich thuoc layer nua.
static BOOL LMKeyPathIsInteresting(NSString *keyPath) {
    if (!keyPath) return NO;
    NSArray *keywords = @[@"transform", @"bounds", @"position", @"path",
                           @"cornerRadius", @"frame", @"sublayerTransform"];
    for (NSString *kw in keywords) {
        if ([keyPath rangeOfString:kw options:NSCaseInsensitiveSearch].location != NSNotFound) {
            return YES;
        }
    }
    return NO;
}

static void LMDescribeAnimation(CALayer *layer, NSString *key, CAAnimation *anim) {
    @try {
        NSString *keyPath = nil;
        NSString *extra = @"";

        if ([anim isKindOfClass:[CABasicAnimation class]]) {
            CABasicAnimation *b = (CABasicAnimation *)anim;
            keyPath = b.keyPath;
            extra = [NSString stringWithFormat:@"from:%@ to:%@", b.fromValue, b.toValue];
        } else if ([anim isKindOfClass:[CAKeyframeAnimation class]]) {
            CAKeyframeAnimation *k = (CAKeyframeAnimation *)anim;
            keyPath = k.keyPath;
            extra = [NSString stringWithFormat:@"valuesCount:%lu", (unsigned long)k.values.count];
        } else if ([anim isKindOfClass:[CAAnimationGroup class]]) {
            CAAnimationGroup *g = (CAAnimationGroup *)anim;
            NSMutableArray *subKeyPaths = [NSMutableArray array];
            for (CAAnimation *sub in g.animations) {
                if ([sub isKindOfClass:[CABasicAnimation class]]) {
                    [subKeyPaths addObject:((CABasicAnimation *)sub).keyPath ?: @"?"];
                } else if ([sub isKindOfClass:[CAKeyframeAnimation class]]) {
                    [subKeyPaths addObject:((CAKeyframeAnimation *)sub).keyPath ?: @"?"];
                }
            }
            keyPath = [subKeyPaths componentsJoinedByString:@","];
            extra = [NSString stringWithFormat:@"(group %lu subs)", (unsigned long)g.animations.count];
        } else if ([anim isKindOfClass:[CATransition class]]) {
            keyPath = @"(CATransition)";
        }

        if (!LMKeyPathIsInteresting(keyPath)) return;

        NSString *layerClass = NSStringFromClass([layer class]);
        LMLog(@"[bb2] layer:%@ | key:%@ | keyPath:%@ | dur:%.3f | %@ | bounds:%@ | pos:%@ | anchorPoint:%@",
              layerClass, key, keyPath, anim.duration, extra,
              NSStringFromCGRect(layer.bounds), NSStringFromCGPoint(layer.position),
              NSStringFromCGPoint(layer.anchorPoint));
    } @catch (NSException *e) {
        LMLog(@"[bb2] Exception: %@", e.reason);
    }
}

%hook CALayer

- (void)addAnimation:(CAAnimation *)anim forKey:(NSString *)key {
    if (gCaptureEnabled) {
        LMDescribeAnimation(self, key, anim);
    }
    %orig;
}

%end

@interface SBIconView : UIView
- (id)icon;
@end

%hook SBIconView

- (void)_handleTap {
    @try {
        id icon = [self valueForKey:@"icon"];
        NSString *className = NSStringFromClass([icon class]);
        BOOL isFolderLike = [className.lowercaseString containsString:@"folder"] ||
                             [className.lowercaseString containsString:@"library"] ||
                             [className.lowercaseString containsString:@"cluster"];
        if (isFolderLike) {
            %orig;
            return;
        }

        LMLog(@"=== _handleTap v2 - BAT DAU GHI (khong loc kich thuoc) trong 2 giay ===");
        gCaptureEnabled = YES;
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            gCaptureEnabled = NO;
            LMLog(@"=== KET THUC ghi v2 ===");
        });
    } @catch (NSException *e) {
        LMLog(@"Exception in _handleTap: %@", e.reason);
    }
    %orig;
}

%end

%ctor {
    LMLog(@"=== LiquidMorph ANIM-DUMP v2 (no size filter) loaded | process: %@ | iOS %@ ===",
          [[NSProcessInfo processInfo] processName],
          [[UIDevice currentDevice] systemVersion]);
}
