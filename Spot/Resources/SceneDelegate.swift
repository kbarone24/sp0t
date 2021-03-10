import UIKit
import Firebase
import Mixpanel

@available(iOS 13.0, *)

class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    
    var window: UIWindow?
    
    
    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        // Use this method to optionally configure and attach the UIWindow `window` to the provided UIWindowScene `scene`.
        // If using a storyboard, the `window` property will automatically be initialized and attached to the scene.
        // This delegate does not imply the connecting scene or session are new (see `application:configurationForConnectingSceneSession` instead).
        
        let notificationName = Notification.Name("openPush")
        
        if let windowScene = (scene as? UIWindowScene) {
            
            self.window = UIWindow(windowScene: windowScene)
            
            if Auth.auth().currentUser != nil {
                //self.window = UIWindow(frame: UIScreen.main.bounds)
                let sb = UIStoryboard(name: "TabBar", bundle: nil)
                let vc = sb.instantiateViewController(withIdentifier: "MapView") as! MapViewController

                let navController = UINavigationController(rootViewController: vc)
                
                NotificationCenter.default.post(name: notificationName, object: nil, userInfo: nil)
                
                self.window!.rootViewController = navController
                self.window!.makeKeyAndVisible()
                
            } else {
                let sb = UIStoryboard(name: "Main", bundle: nil)
                let vc = sb.instantiateViewController(withIdentifier: "LandingPage") as! LandingPageController
                
                self.window!.rootViewController = vc
                self.window!.makeKeyAndVisible()
            }
            
            let BarButtonItemAppearance = UIBarButtonItem.appearance()
            BarButtonItemAppearance.setTitleTextAttributes([NSAttributedString.Key.foregroundColor: UIColor.clear], for: .normal)
            
            BarButtonItemAppearance.setTitleTextAttributes([NSAttributedString.Key.foregroundColor: UIColor.clear], for: .selected)
            
            UITextField.appearance(whenContainedInInstancesOf: [UISearchBar.self]).defaultTextAttributes = [NSAttributedString.Key.foregroundColor: UIColor.white]
            
            let searchBarAppearance = UISearchBar.appearance()
            searchBarAppearance.barTintColor = UIColor(named: "SpotBlack")
            searchBarAppearance.barStyle =  .black
            
            UITextField.appearance(whenContainedInInstancesOf: [UISearchBar.self]).defaultTextAttributes = [NSAttributedString.Key.foregroundColor: UIColor.white]

            
            let tabBarAppearance = UITabBar.appearance()
            
            tabBarAppearance.backgroundColor = UIColor.black
            
            UIView.appearance().isExclusiveTouch = true
            
            Mixpanel.initialize(token: "fd9796146c1f75c2962ce3534e120d33")
        }
        
    }
    
    func sceneDidDisconnect(_ scene: UIScene) {
        // Called as the scene is being released by the system.
        // This occurs shortly after the scene enters the background, or when its session is discarded.
        // Release any resources associated with this scene that can be re-created the next time the scene connects.
        // The scene may re-connect later, as its session was not neccessarily discarded (see `application:didDiscardSceneSessions` instead).
    }
    
    func sceneDidBecomeActive(_ scene: UIScene) {
        // Called when the scene has moved from an inactive state to an active state.
        // Use this method to restart any tasks that were paused (or not yet started) when the scene was inactive.
    }
    
    func sceneWillResignActive(_ scene: UIScene) {
        // Called when the scene will move from an active state to an inactive state.
        // This may occur due to temporary interruptions (ex. an incoming phone call).
    }
    
    func sceneWillEnterForeground(_ scene: UIScene) {
        // Called as the scene transitions from the background to the foreground.
        // Use this method to undo the changes made on entering the background.
        
    }
    
    func sceneDidEnterBackground(_ scene: UIScene) {
        
    }
    
    
}
