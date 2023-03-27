//
//  PTEConsoleLogger+PTEConsoleLogger.h
//  LumberjackConsole
//
//  Created by Konstantin Grebelsky on 3/24/23.
//

#import <LumberjackConsole/PTEConsoleLogger.h>

NS_ASSUME_NONNULL_BEGIN

@interface PTEConsoleLogger (PTEConsoleLogger_Category)
- (void)openConsolePipeWith:(DDFileLogger*)fileLogger;
- (void)logMessage:(DDLogMessage*)message;
@end

NS_ASSUME_NONNULL_END
