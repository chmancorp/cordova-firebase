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
    NSDictionary *dict = [FIRApp allApps];
    for (id key in [dict allKeys])
        NSLog(@"%@ - %@", key, dict[key]);
    
    if ([FIRApp defaultApp])
        [[FIRApp defaultApp] deleteApp:^(BOOL sePudoBorrar){
            NSLog(@"App borrada: %d", sePudoBorrar);
        }];
    
    FIROptions *options = [[FIROptions alloc] initWithGoogleAppID:[NSString stringWithFormat: @"1:%@:ios:8784fa2beeaa8732462d22", googleId]
                                                      GCMSenderID:googleId];
    
    NSLog(@"google app id: %@", [options googleAppID]);
    
    [FIRApp configureWithOptions:options];
    //[FIRApp configureWithName:@"privada" options:options];

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
    
    // Inicializo el proyecto privado de Firebase
    //[self inicializaFirebase:@"476818337671"];
    [FIRMessaging messaging].delegate = self;

    self.applicationInBackground = @(YES);
    
    // Para resetear todas las notificaciones guardadas
    /*
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    NSDictionary *dict = [defaults dictionaryRepresentation];
    for (id key in dict) {
        [defaults removeObjectForKey:key];
    }
    [defaults synchronize];
    NSLog(@"Preferencias guardadas para: %@", [defaults objectForKey:@"mensajes"]);
    */

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
    NSLog(@"FCM registration token en didReceiveRegistrationToken: %@", fcmToken);
    NSUserDefaults *prefs = [NSUserDefaults standardUserDefaults];
    [prefs setObject:fcmToken forKey:@"tokenBanxico"];
    [prefs synchronize];

    NSDictionary *dataDict = [NSDictionary dictionaryWithObject:fcmToken forKey:@"token"];
    [[NSNotificationCenter defaultCenter] postNotificationName:
     @"FCMToken" object:nil userInfo:dataDict];
    
    // Notifico a Ionic
    NSLog(@"Enviando a echoResult");
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

    completionHandler(UIBackgroundFetchResultNewData);

    NSDictionary *mutableUserInfo = [userInfo mutableCopy];

    [self procesaNotificacion:mutableUserInfo];

}

- (void)applicationWillTerminate:(UIApplication *)application {
    NSLog(@"Dentro de applicationWillTerminate");
    if ([FIRApp defaultApp])
        [[FIRApp defaultApp] deleteApp:^(BOOL sePudoBorrar){
            NSLog(@"App borrada en applicationWilTerminate: %d", sePudoBorrar);
        }];

    [[FIRMessaging messaging] disconnect];
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
- (void)procesaNotificacion:(NSDictionary *)mutableUserInfo {
    [mutableUserInfo setValue:self.applicationInBackground forKey:@"tap"];
    
    // Print full message.
    NSLog(@"%@", mutableUserInfo);
    
    // Guardo la notificacion en UserDefaults, concatenando con un pipe
    NSUserDefaults *prefs = [NSUserDefaults standardUserDefaults];
    NSArray *array = [prefs objectForKey:@"mcs"];
    if (array == nil) {
        array = [[NSArray alloc] init];
    }
    NSMutableArray *mcs = [array mutableCopy];

    NSArray *arrayAllNot = [prefs objectForKey:@"allNotifications"];
    if (arrayAllNot == nil) {
        arrayAllNot = [[NSArray alloc] init];
    }
    NSMutableArray *allNotifications = [arrayAllNot mutableCopy];

    // Busco en los mensajes anteriores
    NSDictionary *jsonRecibido = [NSJSONSerialization JSONObjectWithData:[mutableUserInfo[@"data"] dataUsingEncoding:NSUTF8StringEncoding] options:0 error:nil];
    NSLog(@"JSON recibido: %@", jsonRecibido);
    bool isPayReq = false;

    // Agrego banderas adicionales para ionic
    //if ([mutableUserInfo objectForKey:@"payreq"]) {
    if (jsonRecibido[@"payreq"] != nil) {
        isPayReq = true;
        [mutableUserInfo setValue:@"true" forKey:@"isPayReq"];
    } else {
        [mutableUserInfo setValue:@"false" forKey:@"isPayReq"];
    }
    NSNumber *tiempo = [NSNumber numberWithDouble:[[NSDate date] timeIntervalSince1970] * 1000];

    // Agrego el timestamp en el campo "hnr"
    [mutableUserInfo setValue:[tiempo stringValue] forKey:@"hnr"];

    // Guardo el nuevo JSON pero primero reviso si es repetido el ID
    int i;
    int encontrado = 0;
    for (i = 0; i<[mcs count]; i++) {
        NSDictionary *jsonMensaje = [mcs objectAtIndex:i];
        NSDictionary *jsonParseado = [NSJSONSerialization JSONObjectWithData:[[jsonMensaje description] dataUsingEncoding:NSUTF8StringEncoding] options:0 error:nil];
        // Si tiene el mismo ID que otro mensaje, lo sustituyo.
        if ([jsonRecibido[@"payreq"][@"infoCif"][@"id"] isEqual:jsonParseado[@"payreq"][@"infoCif"][@"id"]]) {
            NSLog(@"objeto sustituido por id identico: %@", jsonRecibido);
            encontrado = 1;
            [mcs replaceObjectAtIndex:i withObject:[jsonRecibido description]];
            break;
        }
    }
    // Si no fue encontrado, lo agrego al final.
    if (!encontrado) {
        if (isPayReq)
            [mcs addObject:[mutableUserInfo objectForKey:@"data"]];
        [allNotifications addObject:[mutableUserInfo objectForKey:@"data"]];
    }

    [prefs setObject:[mcs copy] forKey:@"mcs"];
    // Por ahora guardo el objeto allNotifications identico al mcs
    [prefs setObject:[allNotifications copy] forKey:@"allNotifications"];
    [prefs synchronize];
    
    NSLog(@"Preferencias guardadas: %@", [prefs objectForKey:@"mcs"]);
    
    // Mando la notificacion via el plugin
    [FirebasePlugin.firebasePlugin sendNotification:mutableUserInfo];
}

- (void)userNotificationCenter:(UNUserNotificationCenter *)center
       willPresentNotification:(UNNotification *)notification
         withCompletionHandler:(void (^)(UNNotificationPresentationOptions))completionHandler {

    NSLog(@"entrando a userNotificationCenter willPresentNotification");
    [self.delegate userNotificationCenter:center
              willPresentNotification:notification
                withCompletionHandler:completionHandler];

    if (![notification.request.trigger isKindOfClass:UNPushNotificationTrigger.class])
        return;
    
    completionHandler(UNNotificationPresentationOptionAlert);

    NSDictionary *mutableUserInfo = [notification.request.content.userInfo mutableCopy];

    [self procesaNotificacion:mutableUserInfo];
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
