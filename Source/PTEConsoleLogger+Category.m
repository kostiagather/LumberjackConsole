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
NSFileHandle *myHandle;
NSPipe* stdPipe;
NSPipe* pipeErr;
dispatch_source_t source;
dispatch_source_t sourceErr;

- (void) startMonitoring:(dispatch_source_t)source pipeReadHandle:(NSFileHandle*)pipeReadHandle file:(NSFileHandle *)myHandle  {
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
                DDLogMessage* msg = [[DDLogMessage alloc] initWithMessage:stdOutString level:DDLogLevelInfo flag:DDLogFlagInfo context:0 file:@"" function:@"" line:0 tag:@"STDOUT" options:(DDLogMessageOptions)0 timestamp:[NSDate date]];
                [self logMessage:msg];
                dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
                    [myHandle writeData:[stdOutString dataUsingEncoding:NSUTF8StringEncoding]];
                });
            });
        }
        else{free(data);}
    });
}

- (void)openConsolePipeWith:(NSString*)filePath {
    stdPipe = [NSPipe pipe];
    pipeErr = [NSPipe pipe];
    pipeReadHandle = [stdPipe fileHandleForReading];
    pipeReadHandleErr = [pipeErr fileHandleForReading];

    setvbuf(stdout, nil, _IONBF, 0);
    dup2([[stdPipe fileHandleForWriting] fileDescriptor], fileno(stdout));
    setvbuf(stderr, nil, _IONBF, 0);
    dup2([[pipeErr fileHandleForWriting] fileDescriptor], fileno(stderr));
    if (filePath != nil) {
        NSFileManager *fileManager = [NSFileManager defaultManager];
        if(![fileManager fileExistsAtPath:filePath]) {
            [fileManager createFileAtPath:filePath contents:nil attributes:nil];
        }
        myHandle = [NSFileHandle fileHandleForUpdatingAtPath:filePath];
        [myHandle seekToEndOfFile];
    }

    source = dispatch_source_create(DISPATCH_SOURCE_TYPE_READ, [pipeReadHandle fileDescriptor], 0, dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0));
    [self startMonitoring:source pipeReadHandle:pipeReadHandle file:myHandle];
    sourceErr = dispatch_source_create(DISPATCH_SOURCE_TYPE_READ, [pipeReadHandleErr fileDescriptor], 0, dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0));
    [self startMonitoring:sourceErr pipeReadHandle:pipeReadHandleErr file:myHandle];

    dispatch_resume(source);
    dispatch_resume(sourceErr);
}
@end
