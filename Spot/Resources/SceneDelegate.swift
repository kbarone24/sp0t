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
                
        if let windowScene = (scene as? UIWindowScene) {
            
            self.window = UIWindow(windowScene: windowScene)
            
           // if Auth.auth().currentUser != nil {
                //checkForPhoneAuth()
                
            //} else {
                let sb = UIStoryboard(name: "Main", bundle: nil)
                let vc = sb.instantiateViewController(withIdentifier: "LandingPage") as! LandingPageController
                
                self.window!.rootViewController = AvatarSelectionController()
                self.window!.makeKeyAndVisible()
            //}
        }
    }
    
    func checkForPhoneAuth() {
        /// use user defaults as primary, firestore as backup
        let defaults = UserDefaults.standard
        let verified = defaults.object(forKey: "verifiedPhone") as? Bool ?? false
        
        if verified {
            Mixpanel.mainInstance().track(event: "PreAuthenticatedUser")
            self.animateToMap()
            
        } else {
            
            let db = Firestore.firestore()
            db.collection("users").whereField("email", isEqualTo: Auth.auth().currentUser?.email ?? "").getDocuments { (snap, err) in

                if let doc = snap?.documents.first {
                    /// if user is verified but its not already saved to defaults ( could have deleted the app and redownloaded), save it to defaults and send them to the map
                    let verified = doc.get("verifiedPhone") as? Bool ?? false
                    if verified {
                        Mixpanel.mainInstance().track(event: "SceneDelegateDefaultVerificationFail")
                        defaults.set(true, forKey: "verifiedPhone")
                        self.animateToMap()
                    } else {
                        self.sendUserToPhoneAuth()
                    }
                    
                } else {
                    self.sendUserToPhoneAuth()
                }
            }
        }
    }
    
    func sendUserToPhoneAuth() {
        if let vc = UIStoryboard(name: "Main", bundle: nil).instantiateViewController(withIdentifier: "PhoneVC") as? PhoneController {
            
            vc.codeType = .multifactor
            vc.root = true
            
            let navController = UINavigationController(rootViewController: vc)
            navController.modalPresentationStyle = .fullScreen
            self.window!.rootViewController = navController
            self.window!.makeKeyAndVisible()
        }
    }
    
    func animateToMap() {
        let sb = UIStoryboard(name: "Map", bundle: nil)
        let vc = sb.instantiateViewController(withIdentifier: "MapVC") as! MapController
        
        let notificationName = Notification.Name("openPush")
        NotificationCenter.default.post(name: notificationName, object: nil, userInfo: nil)
        
        let navController = MapNavigationController(rootViewController: vc)
        self.window!.rootViewController = navController
        self.window!.makeKeyAndVisible()
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
