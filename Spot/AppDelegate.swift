import CoreData
import SDWebImage
import Firebase
import FirebaseFirestore
import FirebaseStorage
import FirebaseCrashlytics
import FirebaseMessaging
import Mixpanel
import UIKit
import UserNotifications
import CoreLocation

@main
class AppDelegate: UIResponder, UIApplicationDelegate {

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        FirebaseApp.configure()

        let db = Firestore.firestore()
        let settings = db.settings
        settings.isPersistenceEnabled = true
        db.settings = settings
        
        SDImageCache.shared.config.maxDiskAge = 60 * 5
        SDImageCache.shared.config.maxMemoryCount = 10
        SDImageCache.shared.config.maxMemoryCost = 1
        
        let locationManager = CLLocationManager()
        registerServices(locationManager: locationManager)

        let navigationBarAppearance = UINavigationBarAppearance()
        navigationBarAppearance.titleTextAttributes = [
            NSAttributedString.Key.foregroundColor: UIColor.white,
            NSAttributedString.Key.font: SpotFonts.UniversCE.fontWith(size: 20),
        ]
        UINavigationBar.appearance().backIndicatorImage = UIImage(named: "BackArrow")

        // set bar button appearance (remove "back" from back buttons)
        let BarButtonItemAppearance = UIBarButtonItem.appearance()
        BarButtonItemAppearance.setTitleTextAttributes([NSAttributedString.Key.foregroundColor: UIColor.black], for: .normal)
        BarButtonItemAppearance.setTitleTextAttributes([NSAttributedString.Key.foregroundColor: UIColor.black], for: .selected)
        BarButtonItemAppearance.setTitleTextAttributes([NSAttributedString.Key.foregroundColor: UIColor.black], for: .highlighted)

        UIView.appearance().isExclusiveTouch = true

        if #available(iOS 15.0, *) {
            UITableView.appearance().sectionHeaderTopPadding = 0.0
        }

        FirebaseConfiguration.shared.setLoggerLevel(.min)
        
        SDImageCache.shared.deleteOldFiles()
        
        // Setting disk cache
        SDImageCache.shared.config.maxDiskSize = 1_000_000 * 200 // 200 MB

        // Setting memory cache
        SDImageCache.shared.config.maxMemoryCost = 25 * 1_024 * 1_024
        
        // Setting cache expiry date
        SDImageCache.shared.config.maxDiskAge = 60 * 5 // 5 minutes

        return true
    }

    func application(_ application: UIApplication, configurationForConnecting connectingSceneSession: UISceneSession, options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        // Called when a new scene session is being created.
        // Use this method to select a configuration to create the new scene with.
        return UISceneConfiguration(name: "Default Configuration", sessionRole: connectingSceneSession.role)
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

    private func registerServices(locationManager: CLLocationManager?) {
        do {
            let fireStore = Firestore.firestore()
            let storage = Storage.storage()

            let friendsService = FriendsService(fireStore: fireStore)
            try ServiceContainer.shared.register(service: friendsService, for: \.friendsService)
            
            let userService = UserService(fireStore: fireStore)
            try ServiceContainer.shared.register(service: userService, for: \.userService)
            
            let spotService = SpotService(fireStore: fireStore)
            try ServiceContainer.shared.register(service: spotService, for: \.spotService)
            
            let imageVideoService = ImageVideoService(fireStore: fireStore, storage: storage)
            try ServiceContainer.shared.register(service: imageVideoService, for: \.imageVideoService)

            let postService = PostService(fireStore: fireStore, imageVideoService: imageVideoService)
            try ServiceContainer.shared.register(service: postService, for: \.postService)

            let mapService = MapService(fireStore: fireStore)
            try ServiceContainer.shared.register(service: mapService, for: \.mapService)

            let notificationsService = NotificationsService(fireStore: fireStore)
            try ServiceContainer.shared.register(service: notificationsService, for: \.notificationsService)

            let botChatService = BotChatService(fireStore: fireStore)
            try ServiceContainer.shared.register(service: botChatService, for: \.botChatService)

            let popService = PopService(fireStore: fireStore)
            try ServiceContainer.shared.register(service: popService, for: \.popService)
            
            if let locationManager {
                let locationService = LocationService(locationManager: locationManager)
                try ServiceContainer.shared.register(service: locationService, for: \.locationService)
            }

            var keys: NSDictionary?
            if let path = Bundle.main.path(forResource: "Keys", ofType: "plist") {
                keys = NSDictionary(contentsOfFile: path)
            }
            if let keys, let apiKey = keys["MixpanelAPIKey"] as? String, apiKey != "" {
                Mixpanel.initialize(token: apiKey, trackAutomaticEvents: true)
            }

        } catch {
            #if DEBUG
            fatalError("Unable to initialize services: \(error.localizedDescription)")
            #else
            Crashlytics.crashlytics().record(error: error)
            #endif
        }
    }
}
