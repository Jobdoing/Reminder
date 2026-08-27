#import <Flutter/Flutter.h>

NS_ASSUME_NONNULL_BEGIN

@interface PaddleLACPersonDetector : NSObject

- (NSArray<NSString *> *)detectWords:(NSString *)text;

@end

@interface PaddleLACPersonSpanChannel : NSObject

+ (void)registerWithMessenger:(NSObject<FlutterBinaryMessenger> *)messenger;

@end

NS_ASSUME_NONNULL_END
