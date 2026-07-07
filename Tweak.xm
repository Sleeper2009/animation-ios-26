#import <UIKit/UIKit.h>

// ---------------------------------------------------------------------
// Log file: /var/mobile/Documents/ - mo truc tiep bang Filza, khong can
// biet duong dan jbroot.
// ---------------------------------------------------------------------
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

%ctor {
    LMLog(@"=== LiquidMorph loaded into process: %@ | iOS %@ ===",
          [[NSProcessInfo processInfo] processName],
          [[UIDevice currentDevice] systemVersion]);

    NSNotificationCenter *center = [NSNotificationCenter defaultCenter];

    // Dang ky nhieu ten notification khac nhau cung luc de do xem
    // ten nao thuc su ban ra tren ban iOS ban dang chay.
    NSArray *names = @[
        @"SBApplicationDidLaunchNotification",
        @"SBApplicationDidTerminateNotification",
        @"FBApplicationProcessStateDidChangeNotification",
        @"SBAppSwitcherDidLaunchApplicationNotification",
        @"SBSuspendUserForegroundApplicationsNotification",
        @"FBSceneDidActivateNotification",
        @"FBSceneDidDeactivateNotification"
    ];

    for (NSString *name in names) {
        [center addObserverForName:name
                             object:nil
                              queue:nil
                         usingBlock:^(NSNotification *note) {
            LMLog(@"Notification fired: %@ | object: %@", name, note.object);
        }];
    }
}
