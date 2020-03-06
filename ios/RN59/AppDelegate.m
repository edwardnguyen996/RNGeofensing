/**
 * Copyright (c) Facebook, Inc. and its affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

#import "AppDelegate.h"
#import <React/RCTRootView.h>
#import <React/RCTLog.h>
#import <React/RCTUIManager.h>
#import <React/RCTBridgeModule.h>
#import <React/RCTBundleURLProvider.h>
#import <React/RCTBridge.h>
#import <React/RCTRootView.h>
#import "RN59-Swift.h"
#import "MSREventBridge.h"

#pragma mark -
#pragma mark - MSREventBridgeBridgeManager

@interface MSREventBridgeBridgeManager : NSObject<RCTBridgeDelegate>

+ (instancetype)sharedInstance;

@property (readonly) RCTBridge *bridge;

- (RCTRootView *)viewForModuleName:(NSString *)moduleName initialProperties:(NSDictionary *)initialProps;
- (void)rootViewForReactTag:(NSNumber *)reactTag withCompletion:(void (^)(UIView *view))completion;

@end

@implementation MSREventBridgeBridgeManager

#pragma mark Lifecycle

+ (instancetype)sharedInstance
{
    static dispatch_once_t once;
    static id sharedInstance;
    dispatch_once(&once, ^{
        sharedInstance = [[self alloc] init];
    });
    return sharedInstance;
}

#pragma mark Bridge

- (RCTBridge *)bridge
{
    static RCTBridge *bridge = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        bridge = [[RCTBridge alloc] initWithDelegate:self launchOptions:nil];
    });
    return bridge;
}

- (void)rootViewForReactTag:(NSNumber *)reactTag withCompletion:(void (^)(UIView *view))completion
{
  [self.bridge.uiManager rootViewForReactTag:reactTag withCompletion:completion];
}

- (RCTRootView *)viewForModuleName:(NSString *)moduleName initialProperties:(NSDictionary *)initialProps
        {
  return [[RCTRootView alloc] initWithBridge:self.bridge moduleName:moduleName initialProperties:initialProps];
}

#pragma mark RCTBridgeDelegate

- (NSURL *)sourceURLForBridge:(RCTBridge *)bridge
{
#if DEBUG
  return [[RCTBundleURLProvider sharedSettings] jsBundleURLForBundleRoot:@"index" fallbackResource:nil];
#else
  return [[NSBundle mainBundle] URLForResource:@"main" withExtension:@"jsbundle"];
#endif
}
@end

#pragma mark -
#pragma mark - UIViewController(MSREventBridgeModule)

@interface UIViewController (MSREventBridgeModule)

/**
 * Returns the event emitter to send events to the js components
 */
@property (nonatomic, readonly) id<MSREventBridgeEventEmitter> viewControllerEventEmitter;

@end

@implementation UIViewController (MSREventBridgeModule)

- (id<MSREventBridgeEventEmitter>)viewControllerEventEmitter
{
  return MSREventBridgeBridgeManager.sharedInstance.bridge.viewControllerEventEmitter;
}

@end

#pragma mark -
#pragma mark - ViewController

static NSString * const StartGenfensingTrackingEvent = @"StartGenfensingTracking";

@interface ViewController : UIViewController

@end

@interface ViewController () <MSREventBridgeEventReceiver>

// Some UUID to test out the event dispatching and receiving is working per view controller
@property (nonatomic) NSUUID *UUID;

@end

@implementation ViewController

#pragma mark - Lifecycle

- (instancetype)init
{
  self = [super init];
  if (self == nil) {
    return nil;
  }

  _UUID = [NSUUID UUID];

  return self;
}

- (void)loadView
{
  self.view = [[MSREventBridgeBridgeManager sharedInstance] viewForModuleName:@"RN59" initialProperties:nil];
}

#pragma mark - <MSREventBridgeEventReceiver>

// Callback from the JS side. One subview from the root node did send an event
- (void)onEventWithName:(NSString *)eventName info:(NSDictionary *)info
{
  RCTLog(@"%@ - Received event: '%@', with info: %@", self.UUID.UUIDString, eventName, info);
  GeofenseController* client = [[GeofenseController alloc] init];
  
  if ([eventName isEqualToString:StartGenfensingTrackingEvent] ) {
    [client initGeofences];
  }
}

@end

#pragma mark -
#pragma mark - AppDelegate

@implementation AppDelegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
  self.window = [[UIWindow alloc] initWithFrame:[UIScreen mainScreen].bounds];
  self.window.rootViewController = [ViewController new];
  [self.window makeKeyAndVisible];
  return YES;
}

- (NSURL *)sourceURLForBridge:(RCTBridge *)bridge {
  #if DEBUG
    return [[RCTBundleURLProvider sharedSettings] jsBundleURLForBundleRoot:@"index" fallbackResource:nil];
  #else
    return [[NSBundle mainBundle] URLForResource:@"main" withExtension:@"jsbundle"];
  #endif
}

@end
