//
//  AppDelegate.m
//  iNSite
//
//  Created by Chris Karr on 8/6/16.
//  Copyright © 2016 iNSite AEC Hackathon Team. All rights reserved.
//

@import CoreLocation;

#import "AFHTTPSessionManager.h"
#import "AFNetworkReachabilityManager.h"
#import "MMDrawerController.h"

#import "AppDelegate.h"

#import "ISMainViewController.h"
#import "ISSiteInfoViewController.h"
#import "ISMapFilterViewController.h"

@interface AppDelegate ()

@property AFNetworkReachabilityManager * reach;

@end

@implementation AppDelegate


- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    [self setupRootController];

    NSMutableDictionary * options = [NSMutableDictionary dictionary];
    [options setValue:NSLocalizedString(@"rationale_location_capabilities", nil) forKey:PDKCapabilityRationale];
    [options setValue:@NO forKey:PDKLocationSignificantChangesOnly];
    [options setValue:@YES forKey:PDKLocationAlwaysOn];
    
    [[PassiveDataKit sharedInstance] registerListener:self forGenerator:PDKLocation options:options];
    
    [self refreshSites];
    
    return YES;
}

- (void) refreshSites {
    self.reach = [AFNetworkReachabilityManager managerForDomain:@"insite.audacious-software.com"];
    
    __unsafe_unretained AppDelegate * weakSelf = self;
    
    [self.reach setReachabilityStatusChangeBlock:^(AFNetworkReachabilityStatus status){
        if (status == AFNetworkReachabilityStatusReachableViaWWAN || status == AFNetworkReachabilityStatusReachableViaWiFi)
        {
            NSURL * jsonUrl = [NSURL URLWithString:[NSBundle mainBundle].infoDictionary[@"iNSite Sites URL"]];
            
            AFHTTPSessionManager *manager = [AFHTTPSessionManager manager];
            
            manager.responseSerializer = [AFHTTPResponseSerializer serializer];
            
            [manager GET:jsonUrl.absoluteString parameters:nil progress:nil success:^(NSURLSessionTask *task, id responseObject) {
                NSError * error = nil;
                NSArray * sites = [NSJSONSerialization JSONObjectWithData:responseObject options:0 error:&error];
                
                [[NSUserDefaults standardUserDefaults] setValue:sites forKey:@"ISSitesList"];
                [[NSUserDefaults standardUserDefaults] synchronize];
                
                [[NSNotificationCenter defaultCenter] postNotificationName:@"sites_updated" object:nil];
            } failure:^(NSURLSessionTask *operation, NSError *error) {
                NSLog(@"ERROR: %@", error);
            }];
        }
        
        [weakSelf.reach stopMonitoring];
        weakSelf.reach = nil;
    }];
    
    [self.reach startMonitoring];
}


- (void) receivedData:(NSDictionary *) data forGenerator:(PDKDataGenerator) dataGenerator {
    switch(dataGenerator) {
        case PDKLocation:
            [self setLastKnownLocation:[data valueForKey:PDKLocationInstance]];
            
            break;
        default:
            break;
    }
}

- (void) setLastKnownLocation:(CLLocation *) location {
    NSUserDefaults * defaults = [NSUserDefaults standardUserDefaults];
    
    [defaults setDouble:location.coordinate.latitude forKey:@"last_known_latitude"];
    [defaults setDouble:location.coordinate.longitude forKey:@"last_known_longitude"];
    
    [defaults synchronize];
}

- (CLLocation *) lastKnownLocation {
    NSUserDefaults * defaults = [NSUserDefaults standardUserDefaults];
    
    if ([defaults valueForKey:@"last_known_latitude"] != nil) {
        CLLocationDegrees latitude = [defaults doubleForKey:@"last_known_latitude"];
        CLLocationDegrees longitude = [defaults doubleForKey:@"last_known_longitude"];
        
        return [[CLLocation alloc] initWithLatitude:latitude longitude:longitude];
    }
    
    return nil;
}

- (void) setupRootController {
    self.window = [[UIWindow alloc] initWithFrame:[[UIScreen mainScreen] bounds]];
    
    ISMainViewController * mainController = [[ISMainViewController alloc] init];
    
    UINavigationController * navController = [[UINavigationController alloc] initWithRootViewController:mainController];
    navController.navigationBar.barStyle = UIBarStyleBlack;
    navController.navigationBar.barTintColor = [UIColor colorWithRed:(0xff/255.0) green:(0x8f/255.0) blue:(0x00/255.0) alpha:1.0];
    navController.navigationBar.tintColor = [UIColor whiteColor];
    navController.navigationBar.translucent = NO;
    navController.navigationBar.titleTextAttributes = @{ NSForegroundColorAttributeName: [UIColor whiteColor] };
    
    CALayer * navLayer = navController.navigationBar.layer;
    navLayer.masksToBounds = NO;
    navLayer.shadowOffset = CGSizeMake(0.0, 0.0);
    navLayer.shadowRadius = 2.0;
    navLayer.shadowOpacity = 0.5;
    
    ISSiteInfoViewController * siteInfo = [[ISSiteInfoViewController alloc] init];
    ISMapFilterViewController * mapFilter = [[ISMapFilterViewController alloc] init];
    
    MMDrawerController * drawerController = [[MMDrawerController alloc] initWithCenterViewController:navController
                                                                            leftDrawerViewController:mapFilter
                                                                           rightDrawerViewController:siteInfo];
    self.window.rootViewController = drawerController;
    
    [self.window makeKeyAndVisible];
    
    [UIApplication sharedApplication].statusBarStyle = UIStatusBarStyleLightContent;
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
    // Saves changes in the application's managed object context before the application terminates.
    [self saveContext];
}

#pragma mark - Core Data stack

@synthesize managedObjectContext = _managedObjectContext;
@synthesize managedObjectModel = _managedObjectModel;
@synthesize persistentStoreCoordinator = _persistentStoreCoordinator;

- (NSURL *)applicationDocumentsDirectory {
    // The directory the application uses to store the Core Data store file. This code uses a directory named "com.aechackathon.iNSite" in the application's documents directory.
    return [[[NSFileManager defaultManager] URLsForDirectory:NSDocumentDirectory inDomains:NSUserDomainMask] lastObject];
}

- (NSManagedObjectModel *)managedObjectModel {
    // The managed object model for the application. It is a fatal error for the application not to be able to find and load its model.
    if (_managedObjectModel != nil) {
        return _managedObjectModel;
    }
    NSURL *modelURL = [[NSBundle mainBundle] URLForResource:@"iNSite" withExtension:@"momd"];
    _managedObjectModel = [[NSManagedObjectModel alloc] initWithContentsOfURL:modelURL];
    return _managedObjectModel;
}

- (NSPersistentStoreCoordinator *)persistentStoreCoordinator {
    // The persistent store coordinator for the application. This implementation creates and returns a coordinator, having added the store for the application to it.
    if (_persistentStoreCoordinator != nil) {
        return _persistentStoreCoordinator;
    }
    
    // Create the coordinator and store
    
    _persistentStoreCoordinator = [[NSPersistentStoreCoordinator alloc] initWithManagedObjectModel:[self managedObjectModel]];
    NSURL *storeURL = [[self applicationDocumentsDirectory] URLByAppendingPathComponent:@"iNSite.sqlite"];
    NSError *error = nil;
    NSString *failureReason = @"There was an error creating or loading the application's saved data.";
    if (![_persistentStoreCoordinator addPersistentStoreWithType:NSSQLiteStoreType configuration:nil URL:storeURL options:nil error:&error]) {
        // Report any error we got.
        NSMutableDictionary *dict = [NSMutableDictionary dictionary];
        dict[NSLocalizedDescriptionKey] = @"Failed to initialize the application's saved data";
        dict[NSLocalizedFailureReasonErrorKey] = failureReason;
        dict[NSUnderlyingErrorKey] = error;
        error = [NSError errorWithDomain:@"YOUR_ERROR_DOMAIN" code:9999 userInfo:dict];
        // Replace this with code to handle the error appropriately.
        // abort() causes the application to generate a crash log and terminate. You should not use this function in a shipping application, although it may be useful during development.
        NSLog(@"Unresolved error %@, %@", error, [error userInfo]);
        abort();
    }
    
    return _persistentStoreCoordinator;
}


- (NSManagedObjectContext *)managedObjectContext {
    // Returns the managed object context for the application (which is already bound to the persistent store coordinator for the application.)
    if (_managedObjectContext != nil) {
        return _managedObjectContext;
    }
    
    NSPersistentStoreCoordinator *coordinator = [self persistentStoreCoordinator];
    if (!coordinator) {
        return nil;
    }
    _managedObjectContext = [[NSManagedObjectContext alloc] initWithConcurrencyType:NSMainQueueConcurrencyType];
    [_managedObjectContext setPersistentStoreCoordinator:coordinator];
    return _managedObjectContext;
}

#pragma mark - Core Data Saving support

- (void)saveContext {
    NSManagedObjectContext *managedObjectContext = self.managedObjectContext;
    if (managedObjectContext != nil) {
        NSError *error = nil;
        if ([managedObjectContext hasChanges] && ![managedObjectContext save:&error]) {
            // Replace this implementation with code to handle the error appropriately.
            // abort() causes the application to generate a crash log and terminate. You should not use this function in a shipping application, although it may be useful during development.
            NSLog(@"Unresolved error %@, %@", error, [error userInfo]);
            abort();
        }
    }
}

@end
