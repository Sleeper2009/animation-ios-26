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
    } @catch (NSException *e) { NSLog(@"[LiquidMorph-bb] Log write failed: %@", e.reason); }
    NSLog(@"[LiquidMorph-bb] %@", message);
}

// CHI GHI LOG, TUYET DOI KHONG SUA GIA TRI GI - day la buoc do tim, chua
// phai buoc thay the. An toan hon nhieu so voi sua truc tiep ngay tu dau.
%hook CALayer

- (void)addAnimation:(CAAnimation *)anim forKey:(NSString *)key {
    @try {
        NSString *layerClass = NSStringFromClass([self class]);
        NSString *animClass = NSStringFromClass([anim class]);
        NSString *keyPath = @"?";

        if ([anim isKindOfClass:[CABasicAnimation class]]) {
            keyPath = ((CABasicAnimation *)anim).keyPath ?: @"?";
        } else if ([anim isKindOfClass:[CAKeyframeAnimation class]]) {
            keyPath = ((CAKeyframeAnimation *)anim).keyPath ?: @"?";
        } else if ([anim isKindOfClass:[CAAnimationGroup class]]) {
            keyPath = @"(group)";
        }

        // Chi log neu bounds lon hon 100pt de loc bot cac hieu ung nho le
        // (con tro, icon nho...), tap trung vao thu co the la transition
        // toan man hinh.
        if (self.bounds.size.width > 100 || self.bounds.size.height > 100) {
            LMLog(@"[bb-anim] layer:%@ | key:%@ | animClass:%@ | keyPath:%@ | duration:%.3f | bounds:%@ | pos:%@",
                  layerClass, key, animClass, keyPath, anim.duration,
                  NSStringFromCGRect(self.bounds), NSStringFromCGPoint(self.position));
        }
    } @catch (NSException *e) {
        // Nuot loi, KHONG de exception lam crash backboardd
    }
    %orig;
}

%end

%ctor {
    LMLog(@"=== LiquidMorph backboardd-dump loaded | process: %@ ===",
          [[NSProcessInfo processInfo] processName]);
}
