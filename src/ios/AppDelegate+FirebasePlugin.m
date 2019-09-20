#import "AppDelegate+FirebasePlugin.h"
#import "FirebasePlugin.h"
#import "Firebase.h"
#include <CommonCrypto/CommonDigest.h>
#include <CommonCrypto/CommonCryptor.h>
#import <objc/runtime.h>

#if defined(__IPHONE_10_0) && __IPHONE_OS_VERSION_MAX_ALLOWED >= __IPHONE_10_0
@import UserNotifications;

#define FBENCRYPT_ALGORITHM     kCCAlgorithmAES128
#define FBENCRYPT_BLOCK_SIZE    kCCBlockSizeAES128
#define FBENCRYPT_KEY_SIZE      kCCKeySizeAES128

// Implement UNUserNotificationCenterDelegate to receive display notification via APNS for devices
// running iOS 10 and above. Implement FIRMessagingDelegate to receive data message via FCM for
// devices running iOS 10 and above.
@interface AppDelegate () <UNUserNotificationCenterDelegate, FIRMessagingDelegate>
@end
#endif

#define kApplicationInBackgroundKey @"applicationInBackground"
#define kDelegateKey @"delegate"

@implementation AppDelegate (FirebasePlugin)

#if defined(__IPHONE_10_0) && __IPHONE_OS_VERSION_MAX_ALLOWED >= __IPHONE_10_0

- (void)setDelegate:(id)delegate {
    objc_setAssociatedObject(self, kDelegateKey, delegate, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (id)delegate {
    return objc_getAssociatedObject(self, kDelegateKey);
}

#endif

+ (void)load {
    Method original = class_getInstanceMethod(self, @selector(application:didFinishLaunchingWithOptions:));
    Method swizzled = class_getInstanceMethod(self, @selector(application:swizzledDidFinishLaunchingWithOptions:));
    method_exchangeImplementations(original, swizzled);
}

- (void)setApplicationInBackground:(NSNumber *)applicationInBackground {
    objc_setAssociatedObject(self, kApplicationInBackgroundKey, applicationInBackground, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (NSNumber *)applicationInBackground {
    return objc_getAssociatedObject(self, kApplicationInBackgroundKey);
}

- (void)inicializaFirebase:(NSString *)googleId {
    NSLog(@"Entrando a inicializaFirebase, googleId: %@", googleId);
    
    // Si ya hay una app, la borro.
    if ([FIRApp defaultApp])
        [[FIRApp defaultApp] deleteApp:^(BOOL sePudoBorrar){
            NSLog(@"App borrada: %d", sePudoBorrar);
        }];
    
    /*
    NSString *filePath = [[NSBundle mainBundle] pathForResource:@"GoogleService-Info" ofType:@"plist"];
    // si lo encuentro, lo uso.
    if(filePath){
        NSLog(@"GoogleService-Info.plist found, setup: [FIRApp configureWithOptions]");
        // create firebase configure options passing .plist as content
        //FIROptions *options = [[FIROptions alloc] initWithContentsOfFile:filePath];
        FIROptions *options = [[FIROptions alloc] initWithGoogleAppID:[NSString stringWithFormat: @"1:%@:ios:d681bfac3039b2ea", googleId]
                                                          GCMSenderID:googleId];
        
        //[options setProjectID:@"201247069219"];
        //[options setGoogleAppID:@"1:201247069219:ios:d681bfac3039b2ea"];
        NSLog(@"google app id: %@", [options googleAppID]);
        
        [FIRApp configureWithOptions:options];
    }
    
    // no .plist found, try default App
    if (![FIRApp defaultApp] && !filePath) {
        NSLog(@"GoogleService-Info.plist NOT FOUND, setup: [FIRApp defaultApp]");
        [FIRApp configure];
    }
     */
    FIROptions *options = [[FIROptions alloc] initWithGoogleAppID:[NSString stringWithFormat: @"1:%@:ios:8784fa2beeaa8732462d22", googleId]
                                                      GCMSenderID:googleId];
    
    NSLog(@"google app id: %@", [options googleAppID]);
    
    [FIRApp configureWithOptions:options];

    /*
#if defined(__IPHONE_10_0) && __IPHONE_OS_VERSION_MAX_ALLOWED >= __IPHONE_10_0
    self.delegate = [UNUserNotificationCenter currentNotificationCenter].delegate;
    [UNUserNotificationCenter currentNotificationCenter].delegate = self;
#endif
    
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(tokenRefreshNotification:)
                                                 name:kFIRInstanceIDTokenRefreshNotification object:nil];
     */
}

- (BOOL)application:(UIApplication *)application swizzledDidFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    [self application:application swizzledDidFinishLaunchingWithOptions:launchOptions];
    [FirebasePlugin registraApp:self];
    if ([UNUserNotificationCenter class] != nil) {
        // iOS 10 or later
        // For iOS 10 display notification (sent via APNS)
        [UNUserNotificationCenter currentNotificationCenter].delegate = self;
        UNAuthorizationOptions authOptions = UNAuthorizationOptionAlert |
        UNAuthorizationOptionSound | UNAuthorizationOptionBadge;
        [[UNUserNotificationCenter currentNotificationCenter]
         requestAuthorizationWithOptions:authOptions
         completionHandler:^(BOOL granted, NSError * _Nullable error) {
             NSLog(@"Completion handler requestAuthorization, granted: %d", granted);
         }];
    } else {
        // iOS 10 notifications aren't available; fall back to iOS 8-9 notifications.
        UIUserNotificationType allNotificationTypes =
        (UIUserNotificationTypeSound | UIUserNotificationTypeAlert | UIUserNotificationTypeBadge);
        UIUserNotificationSettings *settings =
        [UIUserNotificationSettings settingsForTypes:allNotificationTypes categories:nil];
        [[UIApplication sharedApplication] registerUserNotificationSettings:settings];
    }
    
    [[UIApplication sharedApplication] registerForRemoteNotifications];
    
    //[self inicializaFirebase];
    [FIRMessaging messaging].delegate = self;

    self.applicationInBackground = @(YES);

    return YES;
}

- (void)applicationDidBecomeActive:(UIApplication *)application {
    [self connectToFcm];
    self.applicationInBackground = @(NO);
    NSString *uniqueIdentifier = [[[UIDevice currentDevice] identifierForVendor] UUIDString];
    NSLog(@"Aplicacion activa, UUID:%@", uniqueIdentifier);
    }

- (void)applicationDidEnterBackground:(UIApplication *)application {
    [[FIRMessaging messaging] disconnect];
    self.applicationInBackground = @(YES);
    NSLog(@"Disconnected from FCM");
}

- (void)messaging:(FIRMessaging *)messaging didReceiveRegistrationToken:(NSString *)fcmToken {
    NSLog(@"FCM registration token: %@", fcmToken);
    // Notify about received token.
    NSDictionary *dataDict = [NSDictionary dictionaryWithObject:fcmToken forKey:@"token"];
    [[NSNotificationCenter defaultCenter] postNotificationName:
     @"FCMToken" object:nil userInfo:dataDict];
    
    // Notifico a Ionic
    [[FirebasePlugin firebasePlugin] echoResult:fcmToken];
}

- (void)tokenRefreshNotification:(NSNotification *)notification {
    // Note that this callback will be fired everytime a new token is generated, including the first
    // time. So if you need to retrieve the token as soon as it is available this is where that
    // should be done.
    NSString *refreshedToken = [[FIRInstanceID instanceID] token];
    NSLog(@"InstanceID token: %@", refreshedToken);

    // Notifico a Ionic
    [[FirebasePlugin firebasePlugin] echoResult:refreshedToken];
    
    // Connect to FCM since connection may have failed when attempted before having a token.
    [self connectToFcm];
    [FirebasePlugin.firebasePlugin sendToken:refreshedToken];
    
}

- (void)connectToFcm {
    /*if ([[FIRMessaging messaging] isDirectChannelEstablished])
        return;
    */
    [[FIRMessaging messaging] connectWithCompletion:^(NSError * _Nullable error) {
        if (error != nil) {
            NSLog(@"Unable to connect to FCM. %@", error);
        } else {
            NSLog(@"Connected to FCM.");
            NSString *refreshedToken = [[FIRInstanceID instanceID] token];
            NSLog(@"InstanceID token: %@", refreshedToken);
            
            //NSLog(@"Version firebase: %ld",(long)[[FIRInstanceID instanceID] goo);
            //NSLog(@"FIRApp Version: %ld", (long)[FIRApp version]);

        }
    }];
}

- (void)application:(UIApplication *)application didRegisterForRemoteNotificationsWithDeviceToken:(NSData *)deviceToken {
    [FIRMessaging messaging].APNSToken = deviceToken;
    NSLog(@"deviceToken1 = %@", deviceToken);
}

- (void)application:(UIApplication *)application didReceiveRemoteNotification:(NSDictionary *)userInfo {
    NSDictionary *mutableUserInfo = [userInfo mutableCopy];

    [mutableUserInfo setValue:self.applicationInBackground forKey:@"tap"];

    // Print full message.
    NSLog(@"Mensaje recibido didReceiveRemoteNotification  %@", mutableUserInfo);
    
    [FirebasePlugin.firebasePlugin sendNotification:mutableUserInfo];
}

- (void)application:(UIApplication *)application didReceiveRemoteNotification:(NSDictionary *)userInfo
    fetchCompletionHandler:(void (^)(UIBackgroundFetchResult))completionHandler {

    NSDictionary *mutableUserInfo = [userInfo mutableCopy];

    [mutableUserInfo setValue:self.applicationInBackground forKey:@"tap"];
    // Print full message.
    NSLog(@"Mensaje recibido didReceiveRemoteNotification fetchCompletionHandler %@", mutableUserInfo);
    completionHandler(UIBackgroundFetchResultNewData);

    NSUserDefaults *prefs = [NSUserDefaults standardUserDefaults];
    //NSString *mensajesAnteriores = [prefs objectForKey:@"mensajes"];
    //[prefs setObject:[NSString stringWithFormat:mensajesAnteriores, @"|", [mutableUserInfo objectForKey:@"data"]] forKey:@"mensajes"];
    //[prefs setObject:[NSString stringWithFormat:mensajesAnteriores, @"|", notification.request.content.userInfo] forKey:@"mensajes"];
    [prefs setObject:mutableUserInfo forKey:@"mensajes"];
    [prefs synchronize];
    
    NSLog(@"Preferencias guardadas: %@", [prefs objectForKey:@"mensajes"]);

    [FirebasePlugin.firebasePlugin sendNotification:mutableUserInfo];
}

// [START ios_10_data_message]
// Receive data messages on iOS 10+ directly from FCM (bypassing APNs) when the app is in the foreground.
// To enable direct data messages, you can set [Messaging messaging].shouldEstablishDirectChannel to YES.
- (void)messaging:(FIRMessaging *)messaging didReceiveMessage:(FIRMessagingRemoteMessage *)remoteMessage {
    NSLog(@"Received data message: %@", remoteMessage.appData);

    // This will allow us to handle FCM data-only push messages even if the permission for push
    // notifications is yet missing. This will only work when the app is in the foreground.
    [FirebasePlugin.firebasePlugin sendNotification:remoteMessage.appData];
}

- (void)application:(UIApplication *)application didFailToRegisterForRemoteNotificationsWithError:(NSError *)error {
  NSLog(@"Unable to register for remote notifications: %@", error);
}

// [END ios_10_data_message]
#if defined(__IPHONE_10_0) && __IPHONE_OS_VERSION_MAX_ALLOWED >= __IPHONE_10_0
- (void)userNotificationCenter:(UNUserNotificationCenter *)center
       willPresentNotification:(UNNotification *)notification
         withCompletionHandler:(void (^)(UNNotificationPresentationOptions))completionHandler {

    NSLog(@"entrando a userNotificationCenter willPresentNotification");
    [self.delegate userNotificationCenter:center
              willPresentNotification:notification
                withCompletionHandler:completionHandler];

    if (![notification.request.trigger isKindOfClass:UNPushNotificationTrigger.class])
        return;

    NSDictionary *mutableUserInfo = [notification.request.content.userInfo mutableCopy];

    [mutableUserInfo setValue:self.applicationInBackground forKey:@"tap"];

    // Print full message.
    NSLog(@"%@", mutableUserInfo);

    completionHandler(UNNotificationPresentationOptionAlert);
    
    // Guardo la notificacion en UserDefaults, concatenando con un pipe
    NSUserDefaults *prefs = [NSUserDefaults standardUserDefaults];
    NSString *mensajesAnteriores = [prefs objectForKey:@"mensajes"];
    NSLog(@"Mensajes anteriores guardados: %@", mensajesAnteriores);
    
    [prefs setObject:[NSString stringWithFormat:@"%@|%@", mensajesAnteriores, [mutableUserInfo objectForKey:@"data"]] forKey:@"mensajes"];
    //[prefs setObject:[NSString stringWithFormat:mensajesAnteriores, @"|", notification.request.content.userInfo] forKey:@"mensajes"];
    //[prefs setObject:mutableUserInfo forKey:@"mensajes"];
    [prefs synchronize];
    
    NSLog(@"Preferencias guardadas: %@", [prefs objectForKey:@"mensajes"]);
    
    // Mando la notificacion via el plugin
    [FirebasePlugin.firebasePlugin sendNotification:mutableUserInfo];
}

- (void) userNotificationCenter:(UNUserNotificationCenter *)center
 didReceiveNotificationResponse:(UNNotificationResponse *)response
          withCompletionHandler:(void (^)(void))completionHandler
{
    NSLog(@"entrando a userNotificationCenter didReceiveNotificationResponse");
    [self.delegate userNotificationCenter:center
       didReceiveNotificationResponse:response
                withCompletionHandler:completionHandler];

    if (![response.notification.request.trigger isKindOfClass:UNPushNotificationTrigger.class])
        return;

    NSDictionary *mutableUserInfo = [response.notification.request.content.userInfo mutableCopy];

    [mutableUserInfo setValue:@YES forKey:@"tap"];

    // Print full message.
    NSLog(@"Response %@", mutableUserInfo);

    [FirebasePlugin.firebasePlugin sendNotification:mutableUserInfo];

    completionHandler();
}

// Receive data message on iOS 10 devices.
- (void)applicationReceivedRemoteMessage:(FIRMessagingRemoteMessage *)remoteMessage {
    // Print full message
    NSLog(@"applicationReceivedRemoteMessage: %@", [remoteMessage appData]);
}
#endif

@end
