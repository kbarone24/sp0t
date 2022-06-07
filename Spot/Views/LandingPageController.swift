//
//  LandingPageController.swift
//  Spot
//
//  Created by kbarone on 4/8/20.
//  Copyright © 2020 sp0t, LLC. All rights reserved.
//

import Foundation
import UIKit
import Firebase
import AVKit
import Mixpanel

class LandingPageController: UIViewController {
    
    var playerLooper: AVPlayerLooper!
    var playerLayer: AVPlayerLayer!
    var videoPlayer: AVQueuePlayer!
    var thumbnailImage: UIImageView! /// show preview thumbnail while video is buffering
    var videoPreviewView: UIView!
    var firstLoad = true /// determine whether video player has been loaded yet
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        Mixpanel.mainInstance().track(event: "LandingPageOpen")
    }
    
    deinit {
        if videoPlayer != nil { videoPlayer.removeObserver(self, forKeyPath: "status") }
        NotificationCenter.default.removeObserver(self, name: UIApplication.didEnterBackgroundNotification, object: nil) /// deinit player on send to background
        NotificationCenter.default.removeObserver(self, name: UIApplication.willResignActiveNotification, object: nil) /// deinit player on resign active
        NotificationCenter.default.removeObserver(self, name: UIApplication.willEnterForegroundNotification, object: nil) /// reinit player on send to foreground
        NotificationCenter.default.removeObserver(self, name: UIApplication.didBecomeActiveNotification, object: nil) /// reinit player on become active
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        setUpVideoLayer()
        
        var heightAdjust: CGFloat = 0
        if UIScreen.main.bounds.height < 800 { heightAdjust = 20 }
        
        let logoImage = UIImageView(frame: CGRect(x: UIScreen.main.bounds.width/2 - 50.5, y: 57 - heightAdjust, width: 101, height: 103))
        logoImage.image = UIImage(named: "LandingPageLogo")
        logoImage.contentMode = .scaleAspectFit
        view.addSubview(logoImage)
        
        let createAccountButton = UIButton(frame: CGRect(x: UIScreen.main.bounds.width/2 - 152, y: UIScreen.main.bounds.height - 268, width: 304, height: 48))
        createAccountButton.setImage(UIImage(named: "CreateAccountButton")!, for: .normal)
        createAccountButton.addTarget(self, action: #selector(createAccountTap(_:)), for: .touchUpInside)
        view.addSubview(createAccountButton)
        
        let beenHereLabel = UILabel(frame: CGRect(x: UIScreen.main.bounds.width/2 - 100, y: createAccountButton.frame.maxY + 27, width: 200, height: 17))
        beenHereLabel.text = "Been here before?"
        beenHereLabel.textAlignment = .center
        beenHereLabel.textColor = UIColor(red: 0.933, green: 0.933, blue: 0.933, alpha: 1)
        beenHereLabel.font = UIFont(name: "SFCompactText-Regular", size: 16)
        view.addSubview(beenHereLabel)
        
        let loginWithEmail = UIButton(frame: CGRect(x: UIScreen.main.bounds.width/2 - 152, y: beenHereLabel.frame.maxY + 9, width: 304, height: 45))
        loginWithEmail.setImage(UIImage(named: "LoginWithEmail"), for: .normal)
        loginWithEmail.addTarget(self, action: #selector(loginWithEmailTap(_:)), for: .touchUpInside)
        view.addSubview(loginWithEmail)
        
        let loginWithPhone = UIButton(frame: CGRect(x: UIScreen.main.bounds.width/2 - 152, y: loginWithEmail.frame.maxY + 12, width: 304, height: 45))
        loginWithPhone.setImage(UIImage(named: "LoginWithPhone"), for: .normal)
        loginWithPhone.addTarget(self, action: #selector(loginWithPhoneTap(_:)), for: .touchUpInside)
        view.addSubview(loginWithPhone)
    }
    
    func setUpVideoLayer() {
        
        videoPreviewView = UIView(frame: view.bounds)
        videoPreviewView.backgroundColor = nil
        view.addSubview(videoPreviewView)
        
        thumbnailImage = UIImageView(frame: videoPreviewView.frame)
        thumbnailImage.contentMode = .scaleAspectFill
        
        _ = try? AVAudioSession.sharedInstance().setCategory(AVAudioSession.Category.playback, mode: .default, options: .mixWithOthers)
        
        let videoURL = Bundle.main.url(forResource:"LandingScreenVideo", withExtension: "mp4")
        
        /// add preview thumbnail
        let previewImage = videoSnapshot(url: videoURL!)
        if previewImage != nil {
            print("add thumbnail")
            thumbnailImage.image = previewImage
            videoPreviewView.addSubview(thumbnailImage)
        }
        
        let playerItem = AVPlayerItem(url: videoURL!)
        
        videoPlayer = AVQueuePlayer(url: videoURL!)
        videoPlayer.isMuted = true
        
        playerLooper = AVPlayerLooper(player: videoPlayer, templateItem: playerItem)
        
        playerLayer = AVPlayerLayer(player: videoPlayer)
        playerLayer.videoGravity = .resizeAspectFill
        playerLayer.frame = videoPreviewView.frame
        
        videoPlayer.addObserver(self, forKeyPath: "status", options: [.old, .new], context: nil)
        
        /// add video mask
        let gl0 = CAGradientLayer()
        let color0 = UIColor(named: "SpotBlack")!.withAlphaComponent(0.7).cgColor
        let color1 = UIColor.clear.cgColor
        gl0.colors = [color1, color0]
        gl0.startPoint = CGPoint(x: 0, y: 0.6)
        gl0.endPoint = CGPoint(x: 0, y: 1.0)
        gl0.frame = self.view.bounds
        videoPreviewView.layer.addSublayer(gl0)
        
        let gl1 = CAGradientLayer()
        gl1.colors = [color0, color1]
        gl1.startPoint = CGPoint(x: 0, y: 0.0)
        gl1.endPoint = CGPoint(x: 0, y: 0.35)
        gl1.frame = self.view.bounds
        videoPreviewView.layer.addSublayer(gl1)
        
        NotificationCenter.default.addObserver(self, selector: #selector(setPlayerToNil(_:)), name: UIApplication.didEnterBackgroundNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(reinitializePlayerLayer(_:)), name: UIApplication.willEnterForegroundNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(setPlayerToNil(_:)), name: UIApplication.willResignActiveNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(reinitializePlayerLayer(_:)), name: UIApplication.didBecomeActiveNotification, object: nil)
    }
    
    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        if object as AnyObject? === videoPlayer {
            /// start video only when its ready so that we can show an image preview before the videoPlayer starts playing
            if keyPath == "status" {
                if videoPlayer.status == .readyToPlay {
                    if thumbnailImage != nil { thumbnailImage.removeFromSuperview() }
                    videoPreviewView.layer.addSublayer(playerLayer)
                    DispatchQueue.main.async {
                        self.videoPlayer.playImmediately(atRate: 1.0)
                        self.firstLoad = false
                    }
                }
            }
        }
    }
    
    @objc func reinitializePlayerLayer(_ sender: NSNotification) {
        if videoPlayer != nil && !firstLoad {
            playerLayer = AVPlayerLayer(player: videoPlayer)
            if videoPlayer.timeControlStatus == .paused {  videoPlayer.play() }
        }
    }
    
    @objc func setPlayerToNil(_ sender: NSNotification) {
        videoPlayer?.pause()
        playerLayer = nil
    }
    
    
    func videoSnapshot(url: URL) -> UIImage? {
        let asset = AVURLAsset(url: url)
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        
        let timestamp = CMTime(seconds: 1, preferredTimescale: 60)
        
        do {
            let imageRef = try generator.copyCGImage(at: timestamp, actualTime: nil)
            return UIImage(cgImage: imageRef)
        }
        
        catch let error as NSError {
            print("Image failed with error \(error)")
            return nil
        }
    }
    
    @objc func createAccountTap(_ sender: UIButton) {
        if let vc = UIStoryboard(name: "Main", bundle: nil).instantiateViewController(withIdentifier: "SignUp") as? SignUpController {
            let navController = UINavigationController(rootViewController: vc)
            navController.modalPresentationStyle = .fullScreen
            self.present(navController, animated: false, completion: nil)
        }
    }
    
    @objc func loginWithEmailTap(_ sender: UIButton) {
        if let vc = UIStoryboard(name: "Main", bundle: nil).instantiateViewController(withIdentifier: "EmailLogin") as? EmailLoginController {
            let navController = UINavigationController(rootViewController: vc)
            navController.modalPresentationStyle = .fullScreen
            self.present(navController, animated: false, completion: nil)
        }
    }
    
    @objc func loginWithPhoneTap(_ sender: UIButton) {
        if let vc = UIStoryboard(name: "Main", bundle: nil).instantiateViewController(withIdentifier: "PhoneVC") as? PhoneController {
            
            vc.codeType = .logIn
            
            let navController = UINavigationController(rootViewController: vc)
            navController.modalPresentationStyle = .fullScreen
            self.present(navController, animated: false, completion: nil)
        }
    }
}
