#import "ExceptionCatcher.h"

@implementation ObjC

+ (BOOL)catchException:(NS_NOESCAPE void (^)(void))tryBlock error:(__autoreleasing NSError * _Nullable * _Nullable)error {
    @try {
        tryBlock();
        return YES;
    }
    @catch (NSException *exception) {
        if (error) {
            NSMutableDictionary *userInfo = [NSMutableDictionary dictionary];
            userInfo[NSLocalizedDescriptionKey] = exception.reason ?: @"An Objective-C exception was raised.";
            if (exception.name) { userInfo[@"ExceptionName"] = exception.name; }
            if (exception.userInfo) { userInfo[@"ExceptionUserInfo"] = exception.userInfo; }
            *error = [NSError errorWithDomain:@"com.carebridge.ObjCException" code:0 userInfo:userInfo];
        }
        return NO;
    }
}

@end
