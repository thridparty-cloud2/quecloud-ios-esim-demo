//
//  SceneDelegate.m
//  QuectelEsimDemo
//
//  Created by quectel.tank on 1/22/26.
//

#import "SceneDelegate.h"
#import "QuectelEsimDemo-Swift.h"
#import <QuecLogKit/QuecLogKit.h>
@import QuecFoundationKit;
#import <QuecPayKit/QuecPayKit.h>
#import <DoraemonKit/DoraemonKit.h>

@interface SceneDelegate ()

@end

@implementation SceneDelegate


- (void)scene:(UIScene *)scene willConnectToSession:(UISceneSession *)session options:(UISceneConnectionOptions *)connectionOptions {
    // Use this method to optionally configure and attach the UIWindow `window` to the provided UIWindowScene `scene`.
    // If using a storyboard, the `window` property will automatically be initialized and attached to the scene.
    // This delegate does not imply the connecting scene or session are new (see `application:configurationForConnectingSceneSession` instead).
    if (![scene isKindOfClass:[UIWindowScene class]]) {
        return;
    }
    [self setupLogKit];
    [self registerWeChat];
    UIWindowScene *windowScene = (UIWindowScene *)scene;
    self.window = [[UIWindow alloc] initWithWindowScene:windowScene];
    QuecEsimTestViewController *homeVC = [[QuecEsimTestViewController alloc] init];
    UINavigationController *nav = [[UINavigationController alloc] initWithRootViewController:homeVC];
    self.window.rootViewController = nav;
    [DoraemonManager.shareInstance install];
    [self.window makeKeyAndVisible];
}

- (void)setupLogKit{
    QuecLogConfig *config = [[QuecLogConfig alloc] init];
    config.nameprefix = quec_MainBundleId();
    config.consoleLogOpen = YES;
    [QuecLog setupLogWithConfig:config];
}

- (void)registerWeChat {
    [QuecPaymentService.sharedManager registerApp:@"wx470372efffffffff" universalLink:@"https://your-aasa.iotomp.com/"];
}

- (void)sceneDidDisconnect:(UIScene *)scene {
    // Called as the scene is being released by the system.
    // This occurs shortly after the scene enters the background, or when its session is discarded.
    // Release any resources associated with this scene that can be re-created the next time the scene connects.
    // The scene may re-connect later, as its session was not necessarily discarded (see `application:didDiscardSceneSessions` instead).
}


- (void)sceneDidBecomeActive:(UIScene *)scene {
    // Called when the scene has moved from an inactive state to an active state.
    // Use this method to restart any tasks that were paused (or not yet started) when the scene was inactive.
}


- (void)sceneWillResignActive:(UIScene *)scene {
    // Called when the scene will move from an active state to an inactive state.
    // This may occur due to temporary interruptions (ex. an incoming phone call).
}


- (void)sceneWillEnterForeground:(UIScene *)scene {
    // Called as the scene transitions from the background to the foreground.
    // Use this method to undo the changes made on entering the background.
}


- (void)sceneDidEnterBackground:(UIScene *)scene {
    // Called as the scene transitions from the foreground to the background.
    // Use this method to save data, release shared resources, and store enough scene-specific state information
    // to restore the scene back to its current state.
}

- (void)scene:(UIScene *)scene openURLContexts:(NSSet<UIOpenURLContext *> *)URLContexts {
    UIOpenURLContext *context = URLContexts.allObjects.firstObject;
    NSURL *url = context.URL;
    [QuecPaymentService.sharedManager handleOpenURL:url];
}

- (void)scene:(UIScene *)scene continueUserActivity:(NSUserActivity *)userActivity {
    [QuecPaymentService.sharedManager handleOpenUniversalLink:userActivity];
}


@end
