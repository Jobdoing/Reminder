#import "PaddleLACPersonSpanChannel.h"

#import <TargetConditionals.h>

#include <memory>
#include <string>
#include <vector>

#if !TARGET_OS_SIMULATOR
#include "lac.h"
#endif

@interface PaddleLACPersonDetector () {
#if !TARGET_OS_SIMULATOR
  std::unique_ptr<LAC> _predictor;
#endif
}

@end


@interface PaddleLACPersonSpanChannel ()

@property(nonatomic, strong) dispatch_queue_t worker;
@property(nonatomic, strong) PaddleLACPersonDetector *detector;

@end

@implementation PaddleLACPersonSpanChannel

+ (void)registerWithMessenger:(NSObject<FlutterBinaryMessenger> *)messenger {
  PaddleLACPersonSpanChannel *handler = [[self alloc] init];
  FlutterMethodChannel *channel =
      [FlutterMethodChannel methodChannelWithName:@"reminder/person_spans"
                                  binaryMessenger:messenger];
  [channel setMethodCallHandler:^(FlutterMethodCall *call, FlutterResult result) {
    if (![call.method isEqualToString:@"detect"]) {
      result(FlutterMethodNotImplemented);
      return;
    }
    NSString *text = [call.arguments isKindOfClass:NSString.class] ? call.arguments : nil;
    if (text.length == 0) {
      result(@[]);
      return;
    }
    [handler detect:text completion:result];
  }];
}

- (instancetype)init {
  self = [super init];
  if (self) {
    _worker = dispatch_queue_create("com.pyramius.reminder.person-spans", DISPATCH_QUEUE_SERIAL);
    _detector = [[PaddleLACPersonDetector alloc] init];
  }
  return self;
}

- (void)detect:(NSString *)text completion:(FlutterResult)completion {
  dispatch_async(self.worker, ^{
    NSArray<NSString *> *words = [self.detector detectWords:text];
    dispatch_async(dispatch_get_main_queue(), ^{
      completion(words);
    });
  });
}

@end


@implementation PaddleLACPersonDetector

- (NSArray<NSString *> *)detectWords:(NSString *)text {
#if TARGET_OS_SIMULATOR
  // NOTE(ceiling): Paddle Lite v2.6.0 has no simulator library; use the
  // existing Pinyin fallback until the runtime is replaced with an XCFramework.
  return @[];
#else
  @try {
    try {
      if (!_predictor) {
        NSString *path = [self modelDirectory];
        if (path.length == 0) return @[];
        _predictor = std::make_unique<LAC>(path.UTF8String, 1);
      }

      std::vector<OutputItem> output = _predictor->lexer(text.UTF8String);
      NSMutableArray<NSString *> *people = [NSMutableArray array];
      for (const OutputItem &item : output) {
        if (item.tag != "PER") continue;
        NSString *word = [NSString stringWithUTF8String:item.word.c_str()];
        if (word.length > 0 && [text containsString:word]) [people addObject:word];
      }
      return people;
    } catch (...) {
      return @[];
    }
  } @catch (__unused NSException *exception) {
    return @[];
  }
#endif
}

- (nullable NSString *)modelDirectory {
  NSBundle *frameworkBundle = [NSBundle bundleForClass:self.class];
  NSURL *bundleURL = [frameworkBundle URLForResource:@"PaddleLACModels"
                                       withExtension:@"bundle"];
  NSBundle *modelBundle = bundleURL == nil ? nil : [NSBundle bundleWithURL:bundleURL];
  return modelBundle.resourcePath;
}

@end
