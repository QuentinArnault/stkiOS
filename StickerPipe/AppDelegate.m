//
//  AppDelegate.m
//  StickerFactory
//
//  Created by Vadim Degterev on 25.06.15.
//  Copyright (c) 2015 908. All rights reserved.
//

#import "AppDelegate.h"
#import "STKStickersManager.h"
#import <Fabric/Fabric.h>
#import <Crashlytics/Crashlytics.h>
#import "NSString+MD5.h"

NSString *const apiKey = @"72921666b5ff8651f374747bfefaf7b2";

NSString *const testIOSKey = @"f06190d9d63cd2f4e7b124612f63c56c";

@interface AppDelegate ()

@end

@implementation AppDelegate


- (NSString *)userId {
    UIDevice *device = [UIDevice currentDevice];
    NSString  *currentDeviceId = [[device identifierForVendor] UUIDString];
    NSString * appVersionString = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleShortVersionString"];
    return [[currentDeviceId stringByAppendingString:appVersionString] MD5Digest];
}

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {

    // Override point for customization after application launch.
    [Fabric with:@[[Crashlytics class]]];
    [STKStickersManager initWitApiKey: testIOSKey];
    [STKStickersManager setStartTimeInterval];
    [STKStickersManager setUserKey:[self userId]];
    
    [STKStickersManager setPriceBProductId:@"com.priceB.stickerPipe" andPriceCProductId:@"com.priceC.stickerPipe"];
    [STKStickersManager setPriceBWithLabel:@"0.99%20USD" andValue:0.99f];
    [STKStickersManager setPriceCwithLabel:@"1.99%20USD" andValue:1.99f];
    
    return YES;
}

- (void)applicationWillResignActive:(UIApplication *)application {
    // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
    // Use this method to pause ongoing tasks, disable timers, and throttle down OpenGL ES frame rates. Games should use this method to pause the game.
}

- (void)applicationDidEnterBackground:(UIApplication *)application {
    // Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later.
    // If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
}

- (void)applicationWillEnterForeground:(UIApplication *)application {
    // Called as part of the transition from the background to the inactive state; here you can undo many of the changes made on entering the background.
}

- (void)applicationDidBecomeActive:(UIApplication *)application {
    // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
}

- (void)applicationWillTerminate:(UIApplication *)application {
    // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
}

@end
