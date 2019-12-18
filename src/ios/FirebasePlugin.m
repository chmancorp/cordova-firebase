#import "FirebasePlugin.h"
#import <Cordova/CDV.h>
#import "AppDelegate.h"
#import "AppDelegate+FirebasePlugin.h"
#import "Firebase.h"
#import <Fabric/Fabric.h>
#import <Crashlytics/Crashlytics.h>
@import FirebaseInstanceID;
@import FirebaseMessaging;
@import FirebaseAnalytics;
@import FirebaseRemoteConfig;
@import FirebasePerformance;
@import FirebaseAuth;

#if defined(__IPHONE_10_0) && __IPHONE_OS_VERSION_MAX_ALLOWED >= __IPHONE_10_0
@import UserNotifications;
#endif

#ifndef NSFoundationVersionNumber_iOS_9_x_Max
#define NSFoundationVersionNumber_iOS_9_x_Max 1299
#endif

@implementation FirebasePlugin

@synthesize notificationCallbackId;
@synthesize tokenRefreshCallbackId;
@synthesize notificationStack;
@synthesize traces;
@synthesize tokenPrivado;
@synthesize tokenBanxico;
@synthesize idFirebaseBanxico;

static NSInteger const kNotificationStackSize = 10;
static FirebasePlugin *firebasePlugin;
static NSString *callbackId;
static AppDelegate *appDelegate;

+ (FirebasePlugin *) firebasePlugin {
    return firebasePlugin;
}

+ (void)registraApp:(AppDelegate *) app {
    appDelegate = app;
}


- (void)pluginInitialize {
    NSLog(@"Starting Firebase plugin");
    firebasePlugin = self;
}

- (void)getId:(CDVInvokedUrlCommand *)command {
    __block CDVPluginResult *pluginResult;

    FIRInstanceIDHandler handler = ^(NSString *_Nullable instID, NSError *_Nullable error) {
        if (error) {
            pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR];
        } else {
            pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsString:instID];
        }

        [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
    };

    [[FIRInstanceID instanceID] getIDWithHandler:handler];
}

- (void)echoResult:(NSString *)idN {
    NSLog(@"Entrando a echoResult con idN %@", idN);
    CDVPluginResult *pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsString:idN];
    [self.commandDelegate sendPluginResult:pluginResult callbackId:callbackId];
}

- (void)messaging:(FIRMessaging *)messaging didReceiveRegistrationToken:(NSString *)fcmToken {
    NSLog(@"FCM registration token desde FirebasePlugin (1a vez): %@", fcmToken);
    // Notify about received token.
    NSDictionary *dataDict = [NSDictionary dictionaryWithObject:fcmToken forKey:@"token"];
    [[NSNotificationCenter defaultCenter] postNotificationName:
     @"FCMToken" object:nil userInfo:dataDict];
    
    if (self.tokenBanxico == nil) {
        self.tokenBanxico = fcmToken;
        NSUserDefaults *prefs = [NSUserDefaults standardUserDefaults];
        [prefs setObject:fcmToken forKey:@"tokenBanxico"];
        [prefs synchronize];
        AppDelegate *miDelegate = [[UIApplication sharedApplication] delegate];
        
        // Inicializo el proyecto de Firebase privado
        NSLog(@"Llamando a inicializaFirebase por segunda vez");
        [miDelegate inicializaFirebase:@"476818337671"];
    } else {
        self.tokenPrivado = fcmToken;
        // Notifico a Ionic
        NSLog(@"Enviando a echoResult en didReceiveRegistrationToken");

        [[FirebasePlugin firebasePlugin] echoResult:fcmToken];
    }
}

- (void)postponeChargeRequest:(CDVInvokedUrlCommand *)command {
    NSLog(@"1. Entrando a postponeChargeRequest de nuevo");
    NSString *mensajeCobro  = [command.arguments objectAtIndex:0]; // El 1er argumento es el mensaje de cobro
    NSLog(@"1.1 Clase mensajeCobro: %@", [mensajeCobro class]);
    NSLog(@"2. despues de inicializar");
    if (mensajeCobro == nil) {
        CDVPluginResult *pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:@"No se encontró ningún mc con el id recibido"];
        NSLog(@"2.1. Mensajecobro nil");
        [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
        NSLog(@"2.2. Despues de commandDelegate");
        return;
    }

    // Parseo el mensaje normalmente
    NSDictionary *jsonMensajeCobro = [NSJSONSerialization JSONObjectWithData:[mensajeCobro dataUsingEncoding:NSUTF8StringEncoding] options:0 error:nil];
    NSLog(@"3. Despues de parseo normal");

    // Parseo manualmente el mensaje porque trae caracteres raros
    /*
    NSMutableDictionary *jsonMensajeCobro = [[NSMutableDictionary alloc] init];
    NSLog(@"3. Despues de init dictionary");
    mensajeCobro = [mensajeCobro stringByReplacingOccurrencesOfString:@"}" withString:@""];
    NSLog(@"4. Despues de 1er replace: %@", mensajeCobro);
    mensajeCobro = [mensajeCobro stringByReplacingOccurrencesOfString:@"{" withString:@""];
    NSLog(@"5. Despues de 2do replace: %@", mensajeCobro);

    NSError *error = nil;
    NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:@"\\s+" options:NSRegularExpressionCaseInsensitive error:&error];
    mensajeCobro = [regex stringByReplacingMatchesInString:mensajeCobro options:0 range:NSMakeRange(0, [mensajeCobro length]) withTemplate:@""];
    
    NSLog(@"6. mensajeCobro despues de parsear: %@", mensajeCobro);
    
    // Inicio ciclo sobre la cadena
    NSArray *arr = [mensajeCobro componentsSeparatedByString:@";"];
    NSLog(@"6. despues de init arreglo");
    NSLog(@"6.0.1 arreglo: %@", arr);
    for (id cadena in arr) {
        NSArray *variables = [cadena componentsSeparatedByString:@"="];
        NSLog(@"6.1 arreglo separado por = ");
        NSLog(@"6.2 arreglo local: %@", variables);
        if (variables == nil || [variables count] < 2)
            continue;
        [jsonMensajeCobro setObject:variables[1] forKey:variables[0]];
        NSLog(@"6.3 despues de asignar a jsonMensajeCobro ");
        NSLog(@"6.4 despues de setObject, variable: %@, key %@", variables[1], variables[0]);
    }
    NSLog(@"7. Saliendo de ciclo dentro de array ");
    */
    NSLog(@"8. mensajeCobro parseado: %@", jsonMensajeCobro);

    NSUserDefaults *prefs = [NSUserDefaults standardUserDefaults];
    NSArray *array = [prefs objectForKey:@"mcs"];
    if (array == nil) { // Si no hay nada en el objeto, regreso error.
        CDVPluginResult *pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:[NSString stringWithFormat:@"No se encontró ningún mc con el id %@", jsonMensajeCobro[@"id"]]];
        [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
        return;
    }
    NSLog(@"9. array not nil");
    NSMutableArray *mcs = [array mutableCopy];

    int i = 0;
    int encontrado = 0;
    NSLog(@"10. antes de entrar al for");
    for (i = 0; i<[mcs count]; i++) {
        NSDictionary *jsonMensaje = [mcs objectAtIndex:i];
        NSLog(@"11. jsonmensaje local #%d: %@", i, jsonMensaje);
        NSDictionary *jsonParseado = [NSJSONSerialization JSONObjectWithData:[[jsonMensaje description] dataUsingEncoding:NSUTF8StringEncoding] options:0 error:nil];
        NSLog(@"12. despues de jsonParseado");
        NSLog(@"objetos: %@, %@", jsonMensajeCobro[@"id"], jsonParseado[@"payreq"][@"infoCif"][@"id"]);

        // Si tiene el mismo ID que otro mensaje, lo sustituyo.
        if ([jsonMensajeCobro[@"id"] isEqual:jsonParseado[@"payreq"][@"infoCif"][@"id"]]) {
            NSLog(@"13. objeto sustituido por id identico: %@", jsonMensajeCobro);
            encontrado = 1;

            NSMutableDictionary *jsonModificado = [jsonParseado mutableCopy];
            NSMutableDictionary *payreq = [jsonParseado[@"payreq"] mutableCopy];
            NSMutableDictionary *infoCif = [payreq[@"infoCif"] mutableCopy];
            infoCif[@"mc"] = jsonMensajeCobro[@"mc"];
            infoCif[@"s"] = jsonMensajeCobro[@"s"];
            infoCif[@"isPayReq"] = jsonMensajeCobro[@"isPayReq"];
            infoCif[@"hnr"] = jsonMensajeCobro[@"hnr"];
            payreq[@"infoCif"] = infoCif;
            jsonModificado[@"payreq"] = payreq;
            [mcs replaceObjectAtIndex:i withObject:[jsonModificado copy]];
            
            NSLog(@"Nuevo objeto mcs: %@", mcs);

            [prefs setObject:[mcs copy] forKey:@"mcs"];
            [prefs synchronize];

            break;
        }
    }
    NSLog(@"13.1 Preferencias guardadas: %@", [prefs objectForKey:@"mcs"]);
    for (i=0; i<[mcs count]; i++)
        NSLog(@"13.2.%d preferencia: %@", i, [mcs objectAtIndex:i]);

    NSLog(@"14. encontrado: %d", encontrado);

    CDVPluginResult *pluginResult;
    if (encontrado) {
        // Si lo encuentro, devuelvo OK y el arreglo nuevo con los mensajes (incluyendo el sustituido)
        pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsArray:[mcs copy]];
    } else {
        pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:@"No se encontró ningún mc con el id %@"];
    }
    [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
}

/** echo del idN */
- (void)echo:(CDVInvokedUrlCommand *)command {
    NSLog(@"Entrando a echo");
    
    NSString *googleId  = [command.arguments objectAtIndex:3]; // Solamente tomo el 4o parametro, los demas no se usan
    
    NSLog(@"googleId: %@", googleId);
    self.idFirebaseBanxico = googleId;      // Guardo este ID porque primero voy a inicializar el proyecto privado
    // Guardo el callbackId y mando a llamar al init de Firebase
    callbackId = command.callbackId;

    // Si aun no inicializo el tokenPrivado, inicializo Firebase, de lo contrario me lo salto.
    if ([[FIRInstanceID instanceID] token] == nil) {
        AppDelegate *miDelegate = [[UIApplication sharedApplication] delegate];
        [miDelegate inicializaFirebase:googleId];
    } else {
        NSLog(@"Segunda / tercera llamada a echo, NO inicializo Firebase");
        NSUserDefaults *prefs = [NSUserDefaults standardUserDefaults];
        NSString *tokenGuardado = [prefs objectForKey:@"tokenBanxico"];
        NSLog(@"Recuperando token banxico desde disco: %@", tokenGuardado);
        [[FirebasePlugin firebasePlugin] echoResult:tokenGuardado];
    }
}

- (void)getMCSaved:(CDVInvokedUrlCommand *)command {
    NSLog(@"Entrando a getMCSaved");

    NSUserDefaults *prefs = [NSUserDefaults standardUserDefaults];
    NSArray *array = [prefs objectForKey:@"mcs"];
    
    NSLog(@"Array guardado: %@", array);

    NSData *json = [NSJSONSerialization dataWithJSONObject:array options:0 error:nil];
    NSLog(@"json convertido: %@", json);
    NSString *mensajes = [[NSString alloc] initWithData:json encoding:NSUTF8StringEncoding];
    NSLog(@"mensajes decodificados: %@", mensajes);
    CDVPluginResult *pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsString:mensajes];
    [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
}

- (void)getAllNotifications:(CDVInvokedUrlCommand *)command {
    NSLog(@"Entrando a getAllNotifications");

    NSUserDefaults *prefs = [NSUserDefaults standardUserDefaults];
    NSArray *array = [prefs objectForKey:@"allNotifications"];

    NSData *json = [NSJSONSerialization dataWithJSONObject:array options:0 error:nil];
    NSString *mensajes = [[NSString alloc] initWithData:json encoding:NSUTF8StringEncoding];
    CDVPluginResult *pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsString:mensajes];
    [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
}

// DEPRECATED - alias of getToken
- (void)getInstanceId:(CDVInvokedUrlCommand *)command {
    CDVPluginResult *pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsString:[[FIRInstanceID instanceID] token]];
    [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
}

- (void)getToken:(CDVInvokedUrlCommand *)command {
    CDVPluginResult *pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsString:[[FIRInstanceID instanceID] token]];
    [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
}

- (void)hasPermission:(CDVInvokedUrlCommand *)command {
    BOOL enabled = NO;
    UIApplication *application = [UIApplication sharedApplication];

    if ([[UIApplication sharedApplication] respondsToSelector:@selector(registerUserNotificationSettings:)]) {
        enabled = application.currentUserNotificationSettings.types != UIUserNotificationTypeNone;
    } else {
#pragma GCC diagnostic push
#pragma GCC diagnostic ignored "-Wdeprecated-declarations"
        enabled = application.enabledRemoteNotificationTypes != UIRemoteNotificationTypeNone;
#pragma GCC diagnostic pop
    }

    NSMutableDictionary* message = [NSMutableDictionary dictionaryWithCapacity:1];
    [message setObject:[NSNumber numberWithBool:enabled] forKey:@"isEnabled"];
    CDVPluginResult *commandResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsDictionary:message];
    [self.commandDelegate sendPluginResult:commandResult callbackId:command.callbackId];
}

- (void)grantPermission:(CDVInvokedUrlCommand *)command {
    
    if (floor(NSFoundationVersionNumber) <= NSFoundationVersionNumber_iOS_9_x_Max) {
        if ([[UIApplication sharedApplication]respondsToSelector:@selector(registerUserNotificationSettings:)]) {
            UIUserNotificationType notificationTypes =
            (UIUserNotificationTypeSound | UIUserNotificationTypeAlert | UIUserNotificationTypeBadge);
            UIUserNotificationSettings *settings = [UIUserNotificationSettings settingsForTypes:notificationTypes categories:nil];
            [[UIApplication sharedApplication] registerUserNotificationSettings:settings];
            [[UIApplication sharedApplication] registerForRemoteNotifications];
        } else {
#pragma GCC diagnostic push
#pragma GCC diagnostic ignored "-Wdeprecated-declarations"
            [[UIApplication sharedApplication] registerForRemoteNotificationTypes:(UIRemoteNotificationTypeAlert | UIRemoteNotificationTypeBadge | UIRemoteNotificationTypeSound)];
#pragma GCC diagnostic pop
        }

        CDVPluginResult *pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK];
        [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];

        return;
    }


#if defined(__IPHONE_10_0) && __IPHONE_OS_VERSION_MAX_ALLOWED >= __IPHONE_10_0
    UNAuthorizationOptions authOptions = UNAuthorizationOptionAlert|UNAuthorizationOptionSound|UNAuthorizationOptionBadge;
    [[UNUserNotificationCenter currentNotificationCenter]
        requestAuthorizationWithOptions:authOptions
                      completionHandler:^(BOOL granted, NSError * _Nullable error) {

            if (![NSThread isMainThread]) {
                dispatch_sync(dispatch_get_main_queue(), ^{
                    [[FIRMessaging messaging] setDelegate:self];
                    [[UIApplication sharedApplication] registerForRemoteNotifications];

                    CDVPluginResult *pluginResult = [CDVPluginResult resultWithStatus: granted ? CDVCommandStatus_OK : CDVCommandStatus_ERROR];
                    [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
                });
            } else {
                [[FIRMessaging messaging] setDelegate:self];
                [[UIApplication sharedApplication] registerForRemoteNotifications];
                CDVPluginResult *pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK];
                [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
            }
        }
    ];
#else
    [[UIApplication sharedApplication] registerForRemoteNotifications];
    CDVPluginResult *pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK];
    [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
#endif

    return;
     
    /*
    if ([UNUserNotificationCenter class] != nil) {
        // iOS 10 or higher
        [UNUserNotificationCenter currentNotificationCenter].delegate = self;
        UNAuthorizationOptions authOptions = UNAuthorizationOptionAlert | UNAuthorizationOptionSound | UNAuthorizationOptionBadge;
        [[UNUserNotificationCenter currentNotificationCenter]
         requestAuthorizationWithOptions:authOptions
         completionHandler:^(BOOL granted, NSError * _Nullable error) {
             
             if (![NSThread isMainThread]) {
                 dispatch_sync(dispatch_get_main_queue(), ^{

                     [[UIApplication sharedApplication] registerForRemoteNotifications];
                     CDVPluginResult *pluginResult = [CDVPluginResult resultWithStatus: granted ? CDVCommandStatus_OK : CDVCommandStatus_ERROR];
                     [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
                 });
             } else {
                 [[UIApplication sharedApplication] registerForRemoteNotifications];
                 CDVPluginResult *pluginResult = [CDVPluginResult resultWithStatus: granted ? CDVCommandStatus_OK : CDVCommandStatus_ERROR];
                 [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
             }
         }];
    } else {
        // iOS 10 notifications aren't available
        // fall back to iOS 8-9 notifications
        UIUserNotificationType allNotificationTypes = (UIUserNotificationTypeSound | UIUserNotificationTypeAlert | UIUserNotificationTypeBadge);
        UIUserNotificationSettings *settings = [UIUserNotificationSettings settingsForTypes:allNotificationTypes categories:nil];
        [[UIApplication sharedApplication] registerUserNotificationSettings:settings];
        [[UIApplication sharedApplication] registerForRemoteNotifications];
        CDVPluginResult *pluginResult = [CDVPluginResult resultWithStatus: CDVCommandStatus_OK];
        [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
    }
    return;
     */
}

- (void)verifyPhoneNumber:(CDVInvokedUrlCommand *)command {
    [self getVerificationID:command];
}

- (void)getVerificationID:(CDVInvokedUrlCommand *)command {
    NSString* number = [command.arguments objectAtIndex:0];

    [[FIRPhoneAuthProvider provider]
    verifyPhoneNumber:number
           UIDelegate:nil
           completion:^(NSString *_Nullable verificationID, NSError *_Nullable error) {

    NSDictionary *message;

    if (error) {
        // Verification code not sent.
        message = @{
            @"code": [NSNumber numberWithInteger:error.code],
            @"description": error.description == nil ? [NSNull null] : error.description
        };

        CDVPluginResult *pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsDictionary:message];

        [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
    } else {
        // Successful.
        CDVPluginResult *pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsString:verificationID];
        [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
    }
  }];
}

- (void)setBadgeNumber:(CDVInvokedUrlCommand *)command {
    int number = [[command.arguments objectAtIndex:0] intValue];

    [self.commandDelegate runInBackground:^{
        [[UIApplication sharedApplication] setApplicationIconBadgeNumber:number];

        CDVPluginResult *pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK];
        [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
    }];
}

- (void)getBadgeNumber:(CDVInvokedUrlCommand *)command {
    [self.commandDelegate runInBackground:^{
        long badge = [[UIApplication sharedApplication] applicationIconBadgeNumber];

        CDVPluginResult *pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsDouble:badge];
        [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
    }];
}

- (void)subscribe:(CDVInvokedUrlCommand *)command {
    NSString* topic = [NSString stringWithFormat:@"/topics/%@", [command.arguments objectAtIndex:0]];

    [[FIRMessaging messaging] subscribeToTopic: topic];

    CDVPluginResult *pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK];
    [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
}

- (void)unsubscribe:(CDVInvokedUrlCommand *)command {
    NSString* topic = [NSString stringWithFormat:@"/topics/%@", [command.arguments objectAtIndex:0]];

    [[FIRMessaging messaging] unsubscribeFromTopic: topic];

    CDVPluginResult *pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK];
    [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
}

- (void)unregister:(CDVInvokedUrlCommand *)command {
    [[FIRInstanceID instanceID] deleteIDWithHandler:^void(NSError *_Nullable error) {
        if (error) {
            NSLog(@"Unable to delete instance");
        } else {
            CDVPluginResult *pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK];
            [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
        }
    }];
}

- (void)onNotificationOpen:(CDVInvokedUrlCommand *)command {
    NSLog(@"En onNotificationOpen");
    self.notificationCallbackId = command.callbackId;

    if (self.notificationStack != nil && [self.notificationStack count]) {
        for (NSDictionary *userInfo in self.notificationStack) {
            [self sendNotification:userInfo];
        }
        [self.notificationStack removeAllObjects];
    }
}

- (void)onTokenRefresh:(CDVInvokedUrlCommand *)command {
    self.tokenRefreshCallbackId = command.callbackId;
    NSString* currentToken = [[FIRInstanceID instanceID] token];

    if (currentToken != nil) {
        [self sendToken:currentToken];
    }
}

- (void)sendNotification:(NSDictionary *)userInfo {
    if (self.notificationCallbackId != nil) {
        CDVPluginResult *pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsDictionary:userInfo];
        [pluginResult setKeepCallbackAsBool:YES];
        [self.commandDelegate sendPluginResult:pluginResult callbackId:self.notificationCallbackId];
    } else {
        if (!self.notificationStack) {
            self.notificationStack = [[NSMutableArray alloc] init];
        }

        // stack notifications until a callback has been registered
        [self.notificationStack addObject:userInfo];

        if ([self.notificationStack count] >= kNotificationStackSize) {
            [self.notificationStack removeLastObject];
        }
    }
}

- (void)sendToken:(NSString *)token {
    if (self.tokenRefreshCallbackId != nil) {
        CDVPluginResult *pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsString:token];
        [pluginResult setKeepCallbackAsBool:YES];
        [self.commandDelegate sendPluginResult:pluginResult callbackId:self.tokenRefreshCallbackId];
    }
}

- (void)logEvent:(CDVInvokedUrlCommand *)command {
    [self.commandDelegate runInBackground:^{
        NSString* name = [command.arguments objectAtIndex:0];
        NSDictionary *parameters;
        @try {
            NSString *description = NSLocalizedString([command argumentAtIndex:1 withDefault:@"No Message Provided"], nil);
            parameters = @{ NSLocalizedDescriptionKey: description };
        }
        @catch (NSException *execption) {
            parameters = [command argumentAtIndex:1];
        }

        [FIRAnalytics logEventWithName:name parameters:parameters];

        CDVPluginResult *pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK];
        [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
    }];
}

- (void)logError:(CDVInvokedUrlCommand *)command {
    [self.commandDelegate runInBackground:^{
        NSString* errorMessage = [command.arguments objectAtIndex:0];
        CLSNSLog(@"%@", errorMessage);
        CDVPluginResult *pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK];
        [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
    }];
}

- (void)setCrashlyticsUserId:(CDVInvokedUrlCommand *)command {
    NSString* userId = [command.arguments objectAtIndex:0];

    [CrashlyticsKit setUserIdentifier:userId];
    CDVPluginResult *pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK];
    [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
}

- (void)setScreenName:(CDVInvokedUrlCommand *)command {
    NSString* name = [command.arguments objectAtIndex:0];

    [FIRAnalytics setScreenName:name screenClass:NULL];
    CDVPluginResult *pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK];
    [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
}

- (void)setUserId:(CDVInvokedUrlCommand *)command {
    [self.commandDelegate runInBackground:^{
        NSString* id = [command.arguments objectAtIndex:0];

        [FIRAnalytics setUserID:id];

        CDVPluginResult *pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK];
        [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
    }];
}

- (void)setUserProperty:(CDVInvokedUrlCommand *)command {
    [self.commandDelegate runInBackground:^{
        NSString* name = [command.arguments objectAtIndex:0];
        NSString* value = [command.arguments objectAtIndex:1];

        [FIRAnalytics setUserPropertyString:value forName:name];

        CDVPluginResult *pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK];
        [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
    }];
}

- (void)fetch:(CDVInvokedUrlCommand *)command {
    [self.commandDelegate runInBackground:^{
          FIRRemoteConfig* remoteConfig = [FIRRemoteConfig remoteConfig];

          if ([command.arguments count] > 0) {
              int expirationDuration = [[command.arguments objectAtIndex:0] intValue];

              [remoteConfig fetchWithExpirationDuration:expirationDuration completionHandler:^(FIRRemoteConfigFetchStatus status, NSError * _Nullable error) {
                  CDVPluginResult *pluginResult;
                  if (status == FIRRemoteConfigFetchStatusSuccess) {
                      pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK];
                  } else {
                      pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR];
                  }
                  [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
              }];
          } else {
              [remoteConfig fetchWithCompletionHandler:^(FIRRemoteConfigFetchStatus status, NSError * _Nullable error) {
                  CDVPluginResult *pluginResult;
                  if (status == FIRRemoteConfigFetchStatusSuccess) {
                      pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK];
                  } else {
                      pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR];
                  }
                  [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
              }];
          }
    }];
}

- (void)activateFetched:(CDVInvokedUrlCommand *)command {
     [self.commandDelegate runInBackground:^{
        FIRRemoteConfig* remoteConfig = [FIRRemoteConfig remoteConfig];
         BOOL activated = [remoteConfig activateFetched];
         CDVPluginResult *pluginResult;

         if (activated) {
             pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK];
         } else {
             pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR];
         }

         [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
     }];
}

- (void)getValue:(CDVInvokedUrlCommand *)command {
    [self.commandDelegate runInBackground:^{
        NSString* key = [command.arguments objectAtIndex:0];
        FIRRemoteConfig* remoteConfig = [FIRRemoteConfig remoteConfig];
        NSString* value = remoteConfig[key].stringValue;
        CDVPluginResult *pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsString:value];
        [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
    }];
}

//
// Performace
//
- (void)startTrace:(CDVInvokedUrlCommand *)command {

    [self.commandDelegate runInBackground:^{
        NSString* traceName = [command.arguments objectAtIndex:0];
        FIRTrace *trace = [self.traces objectForKey:traceName];

        if ( self.traces == nil) {
            self.traces = [NSMutableDictionary new];
        }

        if (trace == nil) {
            trace = [FIRPerformance startTraceWithName:traceName];
            [self.traces setObject:trace forKey:traceName ];

        }

        CDVPluginResult *pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK];
        [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];

    }];
}

- (void)incrementCounter:(CDVInvokedUrlCommand *)command {
    [self.commandDelegate runInBackground:^{
        NSString* traceName = [command.arguments objectAtIndex:0];
        NSString* counterNamed = [command.arguments objectAtIndex:1];
        CDVPluginResult *pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK];
        FIRTrace *trace = (FIRTrace*)[self.traces objectForKey:traceName];

        if (trace != nil) {
            [trace incrementCounterNamed:counterNamed];
            [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
        } else {
            pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:@"Trace not found"];
        }

        [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];

    }];
}

- (void)stopTrace:(CDVInvokedUrlCommand *)command {
    [self.commandDelegate runInBackground:^{
        NSString* traceName = [command.arguments objectAtIndex:0];
        CDVPluginResult *pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK];
        FIRTrace *trace = [self.traces objectForKey:traceName];

        if (trace != nil) {
            [trace stop];
            [self.traces removeObjectForKey:traceName];
            [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
        } else {
            pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:@"Trace not found"];
        }

        [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
    }];
}

- (void)setAnalyticsCollectionEnabled:(CDVInvokedUrlCommand *)command {
     [self.commandDelegate runInBackground:^{
        BOOL enabled = [[command argumentAtIndex:0] boolValue];

        [[FIRAnalyticsConfiguration sharedInstance] setAnalyticsCollectionEnabled:enabled];
        CDVPluginResult *pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK];
        [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
     }];
}

- (void)setPerformanceCollectionEnabled:(CDVInvokedUrlCommand *)command {
     [self.commandDelegate runInBackground:^{
         BOOL enabled = [[command argumentAtIndex:0] boolValue];

         [[FIRPerformance sharedInstance] setDataCollectionEnabled:enabled];

         CDVPluginResult *pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK];

         [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
     }];
}

- (void)clearAllNotifications:(CDVInvokedUrlCommand *)command {
	[self.commandDelegate runInBackground:^{
        [[UIApplication sharedApplication] setApplicationIconBadgeNumber:1];
        [[UIApplication sharedApplication] setApplicationIconBadgeNumber:0];

        CDVPluginResult *pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK];
        [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
    }];
}
@end
