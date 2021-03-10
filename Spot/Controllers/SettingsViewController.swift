//
//  ContactViewController.swift
//  Spot
//
//  Created by kbarone on 7/29/19.
//  Copyright © 2019 sp0t, LLC. All rights reserved.
//

import Foundation
import UIKit
import Firebase
import FirebaseFirestore
import FirebaseAuth
import Mixpanel

class SettingsViewController: UIViewController, UITableViewDataSource, UITableViewDelegate {
    
    unowned var profileVC: ProfileViewController!
    @IBOutlet weak var tableview: UITableView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        Mixpanel.mainInstance().track(event: "SettingsOpen")
        tableview.backgroundColor = UIColor(named: "SpotBlack")
        tableview.separatorStyle = .none
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return 4
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        
        if indexPath.row == 0 {
            
            guard let cell = tableView.dequeueReusableCell(withIdentifier: "XCell") else { return UITableViewCell() }
            cell.backgroundColor = UIColor(named: "SpotBlack")
            cell.selectionStyle = .none
            
            let exitButton = UIButton(frame: CGRect(x: UIScreen.main.bounds.width - 56, y: 8, width: 44, height: 36))
            exitButton.imageEdgeInsets = UIEdgeInsets(top: 6, left: 10, bottom: 6, right: 10)
            exitButton.setImage(UIImage(named: "CancelButton"), for: .normal)
            exitButton.addTarget(self, action: #selector(exitTap(_:)), for: .touchUpInside)
            cell.addSubview(exitButton)
            
            let settingsTitle = UILabel(frame: CGRect(x: 100, y: 15, width: UIScreen.main.bounds.width - 200, height: 20))
            settingsTitle.text = "Settings"
            settingsTitle.textColor = .white
            settingsTitle.textAlignment = .center
            settingsTitle.font = UIFont(name: "SFCamera-Regular", size: 16)
            cell.addSubview(settingsTitle)
            
            let bottomLine = UIView(frame: CGRect(x: 15, y: 49, width: UIScreen.main.bounds.width - 40, height: 1))
            bottomLine.backgroundColor = UIColor(red: 0.162, green: 0.162, blue: 0.162, alpha: 1)
            cell.addSubview(bottomLine)
            
            return cell

        } else if indexPath.row == 1 {
            
            guard let cell = tableView.dequeueReusableCell(withIdentifier: "LogoutCell") else { return UITableViewCell() }
            cell.backgroundColor = UIColor(named: "SpotBlack")
            cell.selectionStyle = .none
            
            let logoutLabel = UIButton(frame: CGRect(x: 5, y: 5, width: 70, height: 40))
            logoutLabel.titleEdgeInsets = UIEdgeInsets(top: 5, left: 10, bottom: 5, right: 10)
            logoutLabel.setTitle("Logout", for: .normal)
            logoutLabel.setTitleColor(UIColor(red:0.88, green:0.88, blue:0.88, alpha:1.0), for: .normal)
            logoutLabel.titleLabel?.font = UIFont(name: "SFCamera-Regular", size: 14)
            logoutLabel.titleLabel?.textAlignment = .left
            logoutLabel.addTarget(self, action: #selector(showAlert(_:)), for: .touchUpInside)
            cell.addSubview(logoutLabel)
            
            let bottomLine = UIView(frame: CGRect(x: 15, y: 49, width: UIScreen.main.bounds.width - 40, height: 1))
            bottomLine.backgroundColor = UIColor(red: 0.162, green: 0.162, blue: 0.162, alpha: 1)
            cell.addSubview(bottomLine)
            
            return cell
            
        } else if indexPath.row == 2 {
            guard let cell = tableView.dequeueReusableCell(withIdentifier: "PrivacyCell") else { return UITableViewCell() }
            cell.backgroundColor = UIColor(named: "SpotBlack")
            cell.selectionStyle = .none
            
            let privacyLabel = UIButton(frame: CGRect(x: 5, y: 5, width: 110, height: 40))
            privacyLabel.titleEdgeInsets = UIEdgeInsets(top: 5, left: 10, bottom: 5, right: 10)
            privacyLabel.setTitle("Terms of use", for: .normal)
            privacyLabel.setTitleColor(UIColor(red:0.88, green:0.88, blue:0.88, alpha:1.0), for: .normal)
            privacyLabel.titleLabel?.textAlignment = .left
            privacyLabel.titleLabel?.font = UIFont(name: "SFCamera-Regular", size: 14)
            privacyLabel.addTarget(self, action: #selector(openPrivacy(_:)), for: .touchUpInside)
            cell.addSubview(privacyLabel)
            
            let bottomLine = UIView(frame: CGRect(x: 15, y: 49, width: UIScreen.main.bounds.width - 40, height: 1))
            bottomLine.backgroundColor = UIColor(red: 0.162, green: 0.162, blue: 0.162, alpha: 1)
            cell.addSubview(bottomLine)
            
            return cell
        } else {
            guard let cell = tableView.dequeueReusableCell(withIdentifier: "FeedbackCell") as? FeedbackCell else { return UITableViewCell() }
            cell.setUp()
            return cell
        }
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        if indexPath.row == 3 { return 300 }
        return 50
    }
    
    @objc func exitTap(_ sender: UIButton) {
        self.dismiss(animated: true, completion: nil)
    }
    
    @objc func openPrivacy(_ sender: UIButton) {
        Mixpanel.mainInstance().track(event: "SettingsPrivacy")
        if let url = URL(string: "https://www.sp0t.app/legal") {
            UIApplication.shared.open(url)
        }
    }
    
    @objc func showAlert(_ sender: UIButton) {
        let alert = UIAlertController(title: "Log out of sp0t?", message: nil, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Log out", style: .default, handler: { action in
            switch action.style{
            case .default:
                Mixpanel.mainInstance().track(event: "SettingsLogout")
                self.logOut()
            case .cancel:
                print("cancel")
            case .destructive:
                print("destruct")
            @unknown default:
                fatalError()
            }}))
        alert.addAction(UIAlertAction(title: "Cancel", style: .default, handler: { action in
            switch action.style{
            case .default:
                break
            case .cancel:
                print("cancel")
            case .destructive:
                print("destruct")
            @unknown default:
                fatalError()
            }}))
        
        self.present(alert, animated: true, completion: nil)
        
    }
    
    func logOut() {
        do {
            try Auth.auth().signOut()
        } catch let signOutError as NSError {
            print ("Error signing out: %@", signOutError)
        }
        if let loginVC = UIStoryboard(name: "Main", bundle: nil).instantiateViewController(identifier: "LandingPage") as? LandingPageController {
            //  loginVC.modalPresentationStyle = .fullScreen
            
            let keyWindow = UIApplication.shared.connectedScenes
                .filter({$0.activationState == .foregroundActive})
                .map({$0 as? UIWindowScene})
                .compactMap({$0})
                .first?.windows
                .filter({$0.isKeyWindow}).first
            keyWindow?.rootViewController = loginVC
        }
    }
}

class FeedbackCell: UITableViewCell {
    var contactLabel: UILabel!
    var improveLabel: UILabel!
    var textView: UITextView!
    var submitButton: UIButton!
    var successLabel: UILabel!
    
    func setUp() {
        selectionStyle = .none
        backgroundColor = UIColor(named: "SpotBlack")
        
        contactLabel = UILabel(frame: CGRect(x: 20, y: 20, width: 100, height: 18))
        contactLabel.text = "Feedback"
        contactLabel.textColor = UIColor(red:0.88, green:0.88, blue:0.88, alpha:1.0)
        contactLabel.font = UIFont(name: "SFCamera-Regular", size: 14)
        self.addSubview(contactLabel)
        
        improveLabel = UILabel(frame: CGRect(x: 20, y: 40, width: UIScreen.main.bounds.width - 40, height: 16))
        improveLabel.text = "Help us improve sp0t"
        improveLabel.textColor = UIColor(red: 0.71, green: 0.71, blue: 0.71, alpha:1.0)
        improveLabel.font = UIFont(name: "SFCamera-Regular", size: 12)
        self.addSubview(improveLabel)
        
        textView = UITextView(frame: CGRect(x: 20, y: 70, width: UIScreen.main.bounds.width - 40, height: 120))
        textView.backgroundColor = UIColor(red: 0.11, green: 0.11, blue: 0.11, alpha:1.0)
        textView.layer.cornerRadius = 7.5
        textView.textColor = UIColor.white
        textView.font = UIFont(name: "SFCamera-regular", size: 12)
        textView.isScrollEnabled = false
        textView.textContainer.lineBreakMode = .byTruncatingHead
        textView.textContainerInset = UIEdgeInsets(top: 8, left: 8, bottom: 8, right: 8)
        self.addSubview(textView)
        
        let submitButton = UIButton(frame: CGRect(x: UIScreen.main.bounds.width - 74, y: 195, width: 50, height: 20))
        submitButton.setTitle("Submit", for: .normal)
        submitButton.setTitleColor(UIColor(named: "SpotGreen"), for: .normal)
        submitButton.titleLabel?.font = UIFont(name: "SFCamera-Semibold", size: 14)
        submitButton.addTarget(self, action: #selector(submitTap(_:)), for: .touchUpInside)
        self.addSubview(submitButton)
        
    }
    
    @objc func submitTap(_ sender: UIButton) {
        let db = Firestore.firestore()
        if (!textView.text.isEmpty) {
            if let settingsVC = viewContainingController() as? SettingsViewController  {
                let feedback = textView.text!
                let postID = UUID().uuidString
                db.collection("contact").document(postID).setData(["feedback" : feedback, "user" : settingsVC.profileVC.userInfo.username])
                if successLabel != nil { return }
                successLabel = UILabel(frame: CGRect(x: 20, y: 220, width: UIScreen.main.bounds.width - 40, height: 100))
                successLabel.text = "Thanks 👍"
                successLabel.font = UIFont(name: "SFCamera-Regular", size: 14)
                successLabel.textColor = UIColor.white
                successLabel.textAlignment = .center
                successLabel.lineBreakMode = .byWordWrapping
                self.addSubview(successLabel)
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) { [weak self] in
                    guard let self = self else { return }
                    UIView.animate(withDuration: 0.5, animations: {
                        self.successLabel.alpha = 0.0
                    })
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                        guard let self = self else { return }
                        self.successLabel.removeFromSuperview()
                        self.successLabel = nil
                    }
                }
            }
        }
        textView.text = ""
    }
}
