import CoreData
import Firebase
import FirebaseCrashlytics
import FirebaseMessaging
import FirebaseUI
import IQKeyboardManagerSwift
import Mixpanel
import UIKit
import UserNotifications

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {

    let serviceContainer = ServiceContainer()

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        FirebaseApp.configure()

        let db = Firestore.firestore()
        let settings = db.settings
        settings.isPersistenceEnabled = true
        db.settings = settings

        registerServices(serviceContainer: serviceContainer)

        /// set navigation bar appearance with gradient
        UINavigationBar.appearance().backIndicatorImage = UIImage()
        UINavigationBar.appearance().backIndicatorTransitionMaskImage = UIImage()

        // Sets the translucent background color
        // Set translucent. (Default value is already true, so this can  be removed if desired.)
        UINavigationBar.appearance().isTranslucent = true
        // UINavigationBar.appearance().edgesForExtendedLayout = UIRectEdge.none

        /// set bar button appearance (remove "back" from back buttons)
        let BarButtonItemAppearance = UIBarButtonItem.appearance()
        BarButtonItemAppearance.setTitleTextAttributes([NSAttributedString.Key.foregroundColor: UIColor.black], for: .normal)
        BarButtonItemAppearance.setTitleTextAttributes([NSAttributedString.Key.foregroundColor: UIColor.black], for: .selected)
        BarButtonItemAppearance.setTitleTextAttributes([NSAttributedString.Key.foregroundColor: UIColor.black], for: .highlighted)

        /// search bar attributes
        UITextField.appearance(whenContainedInInstancesOf: [UISearchBar.self]).defaultTextAttributes = [
            NSAttributedString.Key.foregroundColor: UIColor(red: 0.514, green: 0.518, blue: 0.537, alpha: 1),
            NSAttributedString.Key.font: UIFont(name: "SFCompactText-Semibold", size: 15) as Any
        ]

        let searchBarAppearance = UISearchBar.appearance()
        searchBarAppearance.barTintColor = UIColor(red: 0.945, green: 0.945, blue: 0.949, alpha: 1)

        UIView.appearance().isExclusiveTouch = true

        let navigationBarAppearance = UINavigationBarAppearance()
        navigationBarAppearance.titleTextAttributes = [
            NSAttributedString.Key.foregroundColor: UIColor.black,
            NSAttributedString.Key.font: UIFont(name: "SFCompactText-Heavy", size: 20) as Any
        ]

        navigationBarAppearance.backgroundColor = .white

        if #available(iOS 15.0, *) {
            UITableView.appearance().sectionHeaderTopPadding = 0.0
        }

        FirebaseConfiguration.shared.setLoggerLevel(.min)
        Mixpanel.initialize(token: "fd9796146c1f75c2962ce3534e120d33")

        return true
    }

    func application(_ application: UIApplication, configurationForConnecting connectingSceneSession: UISceneSession, options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        // Called when a new scene session is being created.
        // Use this method to select a configuration to create the new scene with.
        return UISceneConfiguration(name: "Default Configuration", sessionRole: connectingSceneSession.role)
    }

    func application(_ application: UIApplication, didDiscardSceneSessions sceneSessions: Set<UISceneSession>) {
        // Called when the user discards a scene session.
        // If any sessions were discarded while the application was not running, this will be called shortly after application:didFinishLaunchingWithOptions.
        // Use this method to release any resources that were specific to the discarded scenes, as they will not return.
    }

    func applicationWillResignActive(_ application: UIApplication) {
        // Sent when the application is about to move from active to inactive state.
        // This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message)
        // or when the user quits the application and it begins the transition to the background state.
        // Use this method to pause ongoing tasks, disable timers, and invalidate graphics rendering callbacks. Games should use this method to pause the game.
    }

    func applicationDidEnterBackground(_ application: UIApplication) {
        // Use this method to release shared resources, save user data, invalidate timers,
        // and store enough application state information to restore your application to its current state in case it is terminated later.
        // If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
    }

    func applicationWillEnterForeground(_ application: UIApplication) {
        // Called as part of the transition from the background to the active state; here you can undo many of the changes made on entering the background.
        print("enter foreground")
    }

    func applicationDidBecomeActive(_ application: UIApplication) {
        // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
        print("become active")
    }

    func applicationWillTerminate(_ application: UIApplication) {
        // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
    }

    lazy var persistentContainer: NSPersistentContainer = {
        let container = NSPersistentContainer(name: "Drafts")
        container.loadPersistentStores(completionHandler: { (_, error) in
            if let error = error as NSError? {
                print("error", error.userInfo)
                return
            }
        })
        return container
    }()

    func saveContext() {
        let context = persistentContainer.viewContext
        if context.hasChanges {
            do {
                try context.save()
            } catch {
                print("error", error)
                return
            }
        }
    }

    private func registerServices(serviceContainer: ServiceContainer) {
        do {
            let fireStore = Firestore.firestore()

            let mapService = MapService(fireStore: fireStore)
            try serviceContainer.register(service: mapService, for: \.mapsService)
        } catch {
            #if DEBUG
            fatalError("Unable to initialize services: \(error.localizedDescription)")
            #else
            Crashlytics.crashlytics().record(error: error)
            #endif
        }
    }
}
