#import <UIKit/UIKit.h>

static NSString *const kLogPath = @"/var/mobile/Documents/LiquidMorph.log";

static void LMLog(NSString *format, ...) {
    va_list args;
    va_start(args, format);
    NSString *message = [[NSString alloc] initWithFormat:format arguments:args];
    va_end(args);

    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    formatter.dateFormat = @"yyyy-MM-dd HH:mm:ss.SSS";
    NSString *timestamp = [formatter stringFromDate:[NSDate date]];
    NSString *line = [NSString stringWithFormat:@"[%@] %@\n", timestamp, message];

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

@interface SBIconView : UIView
@end

%hook SBIconView

- (void)touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event {
    @try {
        id icon = [self valueForKey:@"icon"];
        NSString *name = @"unknown";
        if (icon && [icon respondsToSelector:@selector(displayName)]) {
            name = [icon performSelector:@selector(displayName)] ?: @"unknown";
        }
        LMLog(@"Icon tapped: %@", name);
    } @catch (NSException *e) {
        LMLog(@"Exception in touchesEnded hook: %@", e.reason);
    }
    %orig;
}

%end

%ctor {
    LMLog(@"LiquidMorph loaded into process: %@", [[NSProcessInfo processInfo] processName]);
}
