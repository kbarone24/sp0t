import Firebase
import Mixpanel
import UIKit
import FirebaseAuth

class SceneDelegate: UIResponder, UIWindowSceneDelegate {

    var window: UIWindow?

    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        // Use this method to optionally configure and attach the UIWindow `window` to the provided UIWindowScene `scene`.
        // If using a storyboard, the `window` property will automatically be initialized and attached to the scene.
        // This delegate does not imply the connecting scene or session are new (see `application:configurationForConnectingSceneSession` instead).

        guard let windowScene = (scene as? UIWindowScene) else {
            return
        }

        self.window = UIWindow(windowScene: windowScene)

        guard Auth.auth().currentUser == nil,
              let window = self.window
        else {
            animateToHome()
            return
        }

        let vc = LandingPageController()
        window.rootViewController = vc
        window.makeKeyAndVisible()
    }

    func animateToHome() {
        guard let window else { return }
        let homeScreenController = HomeScreenController(viewModel: HomeScreenViewModel(serviceContainer: ServiceContainer.shared))
        let navigationController = UINavigationController(rootViewController: homeScreenController)
        window.rootViewController = navigationController
        window.makeKeyAndVisible()
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
    
    func scene(_ scene: UIScene, openURLContexts URLContexts: Set<UIOpenURLContext>) {
        // first launch after install
            handleIncomingDynamicLink(URLContexts.first?.url)
        }
    func scene(_ scene: UIScene, continue userActivity: NSUserActivity) {
        // when in background mode
            handleIncomingDynamicLink(userActivity.webpageURL)
    }
        
    func handleIncomingDynamicLink(_ url: URL?) {
        var finalMapID = ""
        var finalPostID = ""

        guard let url = url else { return }
        DynamicLinks.dynamicLinks().resolveShortLink(url) {url, _ in
            guard let final = url else { return }
            guard let components = URLComponents(url: final, resolvingAgainstBaseURL: false), let queryItems = components.queryItems else { return }
            for queryItem in queryItems where queryItem.name == "deep_link_id" {
                guard let linkToParse = URL(string: queryItem.value ?? " ") else { return }
                guard let finalComponents = URLComponents(url: linkToParse, resolvingAgainstBaseURL: false), let qIs = finalComponents.queryItems else { return }
                for qI in qIs {
                    switch qI.name {
                    case "mapID":
                        finalMapID = qI.value ?? " "
                        Task {
                            do {
                                let mapsService = try ServiceContainer.shared.service(for: \.mapsService)
                                let map = try await mapsService.getMap(mapID: finalMapID)
                                NotificationCenter.default.post(name: Notification.Name("IncomingMap"), object: nil, userInfo: ["mapInfo": map])
                            } catch {
                                return
                            }
                        }
                    case "postID":
                        finalPostID = qI.value ?? " "
                        Task {
                            do {
                                let postService = try ServiceContainer.shared.service(for: \.mapPostService)
                                let post = try await postService.getPost(postID: finalPostID)
                                NotificationCenter.default.post(name: Notification.Name("IncomingPost"), object: nil, userInfo: ["postInfo": post])
                            } catch {
                                return
                            }
                        }
                    default:
                        return
                    }
                }
            }
            }
        }
}
