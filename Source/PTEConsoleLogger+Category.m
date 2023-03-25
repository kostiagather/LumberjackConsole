//
//  PTEConsoleLogger+Category.m
//  LumberjackConsole
//
//  Created by Konstantin Grebelsky on 3/24/23.
//

#import "PTEConsoleLogger+Category.h"

@implementation PTEConsoleLogger (PTEConsoleLogger_Category)
-(void)openConsolePipeWith:(NSString*)filePath {
    NSPipe* pipe = [NSPipe pipe];
    NSFileHandle* pipeReadHandle = [pipe fileHandleForReading];
    dup2([[pipe fileHandleForWriting] fileDescriptor], fileno(stdout));
    dispatch_source_t source = dispatch_source_create(DISPATCH_SOURCE_TYPE_READ, [pipeReadHandle fileDescriptor], 0, dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0));
    NSFileHandle *myHandle;
    if (filePath != nil) {
        NSFileManager *fileManager = [NSFileManager defaultManager];
        if(![fileManager fileExistsAtPath:filePath]) {
            [fileManager createFileAtPath:filePath contents:nil attributes:nil];
        } else {
            NSFileHandle *myHandle = [NSFileHandle fileHandleForUpdatingAtPath:filePath];
            [myHandle seekToEndOfFile];
        }
    }
    dispatch_source_set_event_handler(source, ^{
        void* data = malloc(4096);
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
                NSString* stdOutString = [[NSString alloc] initWithBytesNoCopy:data length:readResult encoding:NSUTF8StringEncoding freeWhenDone:YES];
                DDLogMessage* msg = [[DDLogMessage alloc] initWithMessage:stdOutString level:DDLogLevelInfo flag:DDLogFlagInfo context:0 file:nil function:nil line:0 tag:@"STD" options:(DDLogMessageOptions)0 timestamp:[NSDate date]];
                [self logMessage:msg];
                [myHandle writeData:(__bridge NSData * _Nonnull)(data)];
            });
        }
        else{free(data);}
    });
    dispatch_resume(source);
}
@end
