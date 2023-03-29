//
//  PTEConsoleLogger+Category.m
//  LumberjackConsole
//
//  Created by Konstantin Grebelsky on 3/24/23.
//

#import "PTEConsoleLogger+Category.h"

@implementation PTEConsoleLogger (PTEConsoleLogger_Category)
NSFileHandle* pipeReadHandle;
NSFileHandle* pipeReadHandleErr;
DDFileLogger * _Nullable fileLogger;
NSPipe* stdPipe;
NSPipe* pipeErr;
dispatch_source_t source;
dispatch_source_t sourceErr;

int stderrSave;
int stdoutSave;

- (void) startMonitoring:(dispatch_source_t)source pipeReadHandle:(NSFileHandle*)pipeReadHandle  {
    dispatch_source_set_event_handler(source, ^{
        __block void* data = malloc(4096);
        ssize_t readResult = 0;
        do
        {
            errno = 0;
            readResult = read([pipeReadHandle fileDescriptor], data, 4096);
        } while (readResult == -1 && errno == EINTR);
        if (readResult > 0)
        {

            //AppKit UI should only be updated from the main thread
            dispatch_async(dispatch_get_main_queue(),^{
                __block NSString* stdOutString = [[NSString alloc] initWithBytesNoCopy:data length:readResult encoding:NSUTF8StringEncoding freeWhenDone:YES];
                dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
                    DDLogMessage* msg = [[DDLogMessage alloc] initWithMessage:stdOutString level:DDLogLevelInfo flag:DDLogFlagInfo context:0 file:@"" function:@"" line:0 tag:@"STDOUT" options:(DDLogMessageOptions)0 timestamp:[NSDate date]];
                    [self logMessage:msg];
                    if (fileLogger) {
                        [fileLogger logMessage:msg];
                    }
                });
            });
        }
        else{free(data);}
    });
}

- (void)openConsolePipeWith:(DDFileLogger *)fileLogger {
    stdPipe = [NSPipe pipe];
    pipeReadHandle = [stdPipe fileHandleForReading];
    stdoutSave = dup(STDOUT_FILENO);
    stderrSave = dup(STDERR_FILENO);
    setvbuf(stdout, nil, _IONBF, 0);
    dup2([[stdPipe fileHandleForWriting] fileDescriptor], STDOUT_FILENO);
    setvbuf(stderr, nil, _IONBF, 0);
    dup2([[stdPipe fileHandleForWriting] fileDescriptor], STDERR_FILENO);
    if (fileLogger != nil) {
        fileLogger = fileLogger;
    }

    source = dispatch_source_create(DISPATCH_SOURCE_TYPE_READ, [pipeReadHandle fileDescriptor], 0, dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0));
    [self startMonitoring:source pipeReadHandle:pipeReadHandle];
    dispatch_resume(source);
    
    printf("Redirected console");
    printf("******************");
}

- (void)closeConsolePipe {
    dup2(stdoutSave, STDOUT_FILENO);
    close(stdoutSave);
    dup2(stderrSave, STDERR_FILENO);
    close(stderrSave);
    printf("Redirected back to console");
    printf("**************************");
    close(stdPipe);
}
@end
