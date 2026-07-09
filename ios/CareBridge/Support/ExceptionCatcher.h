#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/// Bridges Objective-C @try/@catch into Swift.
///
/// A whole class of iOS crashes (SIGABRT / "abort signal terminated the
/// process") come from Objective-C exceptions raised deep inside Apple
/// frameworks — most notably AVFoundation's `installTap(onBus:...)`, which
/// raises `NSInvalidArgumentException` for an invalid audio format. Swift's
/// `do/catch` cannot intercept those, so they propagate to the top and abort
/// the process. Wrapping the risky call in `ObjC.catchException { ... }` turns
/// the raised NSException into an ordinary throwing Swift error we can handle.
@interface ObjC : NSObject

+ (BOOL)catchException:(NS_NOESCAPE void (^)(void))tryBlock error:(__autoreleasing NSError * _Nullable * _Nullable)error;

@end

NS_ASSUME_NONNULL_END
