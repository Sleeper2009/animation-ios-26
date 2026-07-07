#import <UIKit/UIKit.h>
#import <objc/runtime.h>

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

// Liet ke toan bo method cua 1 class, chi ghi ra nhung ten co chua tu khoa
// can tim (vd "tap", "launch", "invoke") de khong bi qua dai.
static void LMDumpMethods(NSString *className, NSString *keyword) {
    Class cls = NSClassFromString(className);
    if (!cls) {
        LMLog(@"[dump] Class not found: %@", className);
        return;
    }
    unsigned int count = 0;
    Method *methods = class_copyMethodList(cls, &count);
    LMLog(@"[dump] ---- %@ (%u methods) chua '%@' ----", className, count, keyword);
    for (unsigned int i = 0; i < count; i++) {
        SEL sel = method_getName(methods[i]);
        NSString *name = NSStringFromSelector(sel);
        if ([name.lowercaseString containsString:keyword.lowercaseString]) {
            LMLog(@"[dump] %@ -> %@", className, name);
        }
    }
    free(methods);
}

%ctor {
    LMLog(@"=== LiquidMorph loaded | process: %@ | iOS %@ ===",
          [[NSProcessInfo processInfo] processName],
          [[UIDevice currentDevice] systemVersion]);

    NSArray *classesToScan = @[@"SBIconController", @"SBIconView", @"SBIconViewMap", @"SBHomeScreenView"];
    NSArray *keywords = @[@"tap", @"launch", @"invoke", @"activat"];

    for (NSString *cls in classesToScan) {
        for (NSString *kw in keywords) {
            LMDumpMethods(cls, kw);
        }
    }

    LMLog(@"=== Dump xong ===");
}
