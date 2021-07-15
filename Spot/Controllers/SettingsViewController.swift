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
    unowned var mapVC: MapViewController!
    var tableView: UITableView!
    
    override func viewDidLoad() {
        
        super.viewDidLoad()
        
        Mixpanel.mainInstance().track(event: "SettingsOpen")
        
        tableView = UITableView(frame: UIScreen.main.bounds)
        tableView.backgroundColor = UIColor(named: "SpotBlack")
        tableView.separatorStyle = .none
        tableView.delegate = self
        tableView.dataSource = self
        tableView.isScrollEnabled = false
        tableView.allowsSelection = false
        tableView.isUserInteractionEnabled = true
        tableView.register(SettingsHeader.self, forHeaderFooterViewReuseIdentifier: "HeaderCell")
        tableView.register(SettingsEditCell.self, forCellReuseIdentifier: "EditCell")
        tableView.register(SettingsFindFriendsCell.self, forCellReuseIdentifier: "FriendsCell")
        tableView.register(SettingsTermsCell.self, forCellReuseIdentifier: "TermsCell")
        tableView.register(SettingsManageAccount.self, forCellReuseIdentifier: "AccountCell")
        tableView.register(SettingsReviewCell.self, forCellReuseIdentifier: "ReviewCell")
        tableView.register(SettingsFeedbackCell.self, forCellReuseIdentifier: "FeedbackCell")
        view.addSubview(tableView)
        
        let offsetY: CGFloat = mapVC.largeScreen ? 150 : 115
        let logoutButton = UIButton(frame: CGRect(x: 20, y: UIScreen.main.bounds.height - offsetY, width: 100, height: 25))
        logoutButton.setTitle("Log Out", for: .normal)
        logoutButton.contentVerticalAlignment = .center
        logoutButton.contentHorizontalAlignment = .left
        logoutButton.setTitleColor(UIColor(red: 0.71, green: 0.71, blue: 0.71, alpha:1.0), for: .normal)
        logoutButton.titleLabel?.font = UIFont(name: "SFCamera-Regular", size: 16)
        logoutButton.addTarget(self, action: #selector(showAlert(_:)), for: .touchUpInside)
        view.addSubview(logoutButton)
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
    }
    
    
    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        return 50
    }
    
    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        guard let header = tableView.dequeueReusableHeaderFooterView(withIdentifier: "HeaderCell") as? SettingsHeader else { return UITableViewHeaderFooterView() }
        header.exitButton.addTarget(self, action: #selector(exitTap(_:)), for: .touchUpInside)
        return header
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        let adminID = profileVC.uid == "kwpjnnDCSKcTZ0YKB3tevLI1Qdi2" || profileVC.uid == "Za1OQPFoCWWbAdxB5yu98iE8WZT2" || profileVC.uid == "T4KMLe3XlQaPBJvtZVArqXQvaNT2"
        return adminID ? 5 : 4
    }
        
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        
        if indexPath.row == 0 {
            
            guard let cell = tableView.dequeueReusableCell(withIdentifier: "EditCell") as? SettingsEditCell else { return UITableViewCell() }
            cell.editButton.addTarget(self, action: #selector(editProfile(_:)), for: .touchUpInside)
            return cell

        } else if indexPath.row == 1 {
            guard let cell = tableView.dequeueReusableCell(withIdentifier: "FriendsCell") as? SettingsFindFriendsCell else { return UITableViewCell() }
            cell.findFriendsButton.addTarget(self, action: #selector(openFindFriends(_:)), for: .touchUpInside)
            return cell
            
        } else if indexPath.row == 2 {
            
            guard let cell = tableView.dequeueReusableCell(withIdentifier: "TermsCell") as? SettingsTermsCell else { return UITableViewCell() }
            cell.privacyButton.addTarget(self, action: #selector(openPrivacy(_:)), for: .touchUpInside)
            return cell

        } else if indexPath.row == 3 {
            
            guard let cell = tableView.dequeueReusableCell(withIdentifier: "FeedbackCell") as? SettingsFeedbackCell else { return UITableViewCell() }
            cell.submitButton.addTarget(self, action: #selector(submitTap(_:)), for: .touchUpInside)
            return cell

        } else {

            guard let cell = tableView.dequeueReusableCell(withIdentifier: "ReviewCell") as? SettingsReviewCell else { return UITableViewCell() }
            cell.reviewButton.addTarget(self, action: #selector(openReviewPublic(_:)), for: .touchUpInside)
            return cell

        }
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return indexPath.row == 3 ? 280 : 50
    }

    @objc func exitTap(_ sender: UIButton) {
        dismiss(animated: true, completion: nil)
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
        
        present(alert, animated: true, completion: nil)
        
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
    
    @objc func editProfile(_ sender: UIButton) {
        profileVC.editProfile(editBio: false)
        dismiss(animated: false, completion: nil)
    }
    
    @objc func openFindFriends(_ sender: UIButton) {
        
        if let vc = storyboard?.instantiateViewController(identifier: "FindFriends") as? FindFriendsController {
            vc.mapVC = mapVC
            present(vc, animated: true, completion: nil)
        }
    }

    @objc func openPrivacy(_ sender: UIButton) {
        Mixpanel.mainInstance().track(event: "SettingsPrivacy")
        if let url = URL(string: "https://www.sp0t.app/legal") {
            UIApplication.shared.open(url)
        }
    }
    
    @objc func openManageAccount(_ sender: UIButton) {

        if let vc = storyboard?.instantiateViewController(identifier: "ManageAccount") as? ManageAccountController {
            vc.mapVC = mapVC
            present(vc, animated: true, completion: nil)
        }
    }
    
    @objc func openReviewPublic(_ sender: UIButton) {
        if let vc = storyboard?.instantiateViewController(identifier: "ReviewPublic") as? ReviewPublicController {
            present(vc, animated: true, completion: nil)
        }
    }
    
    @objc func submitTap(_ sender: UIButton) {
        
        let db = Firestore.firestore()
        guard let cell = tableView.cellForRow(at: IndexPath(row: 3, section: 0)) as? SettingsFeedbackCell else { return }
        
        if (!cell.textView.text.isEmpty) {
                        
            let feedback = cell.textView.text!
            let postID = UUID().uuidString
            db.collection("contact").document(postID).setData(["feedback" : feedback, "user" : profileVC.userInfo.username])
            if cell.successLabel != nil { return }
            cell.successLabel = UILabel(frame: CGRect(x: 20, y: 220, width: UIScreen.main.bounds.width - 40, height: 100))
            cell.successLabel.text = "Thanks 👍"
            cell.successLabel.font = UIFont(name: "SFCamera-Regular", size: 14)
            cell.successLabel.textColor = UIColor.white
            cell.successLabel.textAlignment = .center
            cell.successLabel.lineBreakMode = .byWordWrapping
            cell.addSubview(cell.successLabel)
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                
                UIView.animate(withDuration: 0.5, animations: {
                    cell.successLabel.alpha = 0.0
                })
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    cell.successLabel.removeFromSuperview()
                    cell.successLabel = nil
                }
            }
        }
        cell.textView.text = ""
    }
}


class SettingsHeader: UITableViewHeaderFooterView {
    
    var exitButton: UIButton!
    
    override init(reuseIdentifier: String?) {
        super.init(reuseIdentifier: reuseIdentifier)
        
        let backgroundView = UIView()
        backgroundView.backgroundColor = UIColor(named: "SpotBlack")
        self.backgroundView = backgroundView

        exitButton = UIButton(frame: CGRect(x: UIScreen.main.bounds.width - 56, y: 8, width: 44, height: 36))
        exitButton.imageEdgeInsets = UIEdgeInsets(top: 6, left: 10, bottom: 6, right: 10)
        exitButton.setImage(UIImage(named: "CancelButton"), for: .normal)
        addSubview(exitButton)
        
        let settingsTitle = UILabel(frame: CGRect(x: 100, y: 15, width: UIScreen.main.bounds.width - 200, height: 20))
        settingsTitle.text = "Settings"
        settingsTitle.textColor = .white
        settingsTitle.textAlignment = .center
        settingsTitle.font = UIFont(name: "SFCamera-Regular", size: 16)
        addSubview(settingsTitle)
        
        let bottomLine = UIView(frame: CGRect(x: 15, y: 49, width: UIScreen.main.bounds.width - 40, height: 1))
        bottomLine.backgroundColor = UIColor(red: 0.162, green: 0.162, blue: 0.162, alpha: 1)
        addSubview(bottomLine)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

class SettingsEditCell: UITableViewCell {
    
    var editButton: UIButton!
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        
        backgroundColor = UIColor(named: "SpotBlack")
        selectionStyle = .none
        
        editButton = UIButton(frame: CGRect(x: 0, y: 5, width: 110, height: 40))
        editButton.titleEdgeInsets = UIEdgeInsets(top: 5, left: 9, bottom: 5, right: 10)
        editButton.setTitle("Edit Profile", for: .normal)
        editButton.setTitleColor(UIColor(red:0.88, green:0.88, blue:0.88, alpha:1.0), for: .normal)
        editButton.titleLabel?.textAlignment = .left
        editButton.titleLabel?.font = UIFont(name: "SFCamera-Regular", size: 14)
        contentView.addSubview(editButton)
        
        let bottomLine = UIView(frame: CGRect(x: 15, y: 49, width: UIScreen.main.bounds.width - 40, height: 1))
        bottomLine.backgroundColor = UIColor(red: 0.162, green: 0.162, blue: 0.162, alpha: 1)
        addSubview(bottomLine)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}


class SettingsTermsCell: UITableViewCell {
    
    var privacyButton: UIButton!
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        
        backgroundColor = UIColor(named: "SpotBlack")
        selectionStyle = .none
        
        privacyButton = UIButton(frame: CGRect(x: 5, y: 5, width: 110, height: 40))
        privacyButton.titleEdgeInsets = UIEdgeInsets(top: 5, left: 10, bottom: 5, right: 10)
        privacyButton.setTitle("Terms of use", for: .normal)
        privacyButton.setTitleColor(UIColor(red:0.88, green:0.88, blue:0.88, alpha:1.0), for: .normal)
        privacyButton.titleLabel?.textAlignment = .left
        privacyButton.titleLabel?.font = UIFont(name: "SFCamera-Regular", size: 14)
        contentView.addSubview(privacyButton)
        
        let bottomLine = UIView(frame: CGRect(x: 15, y: 49, width: UIScreen.main.bounds.width - 40, height: 1))
        bottomLine.backgroundColor = UIColor(red: 0.162, green: 0.162, blue: 0.162, alpha: 1)
        addSubview(bottomLine)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

class SettingsFeedbackCell: UITableViewCell {
    
    var botImage: UIImageView!
    var contactLabel: UILabel!
    var improveLabel: UILabel!
    var textView: UITextView!
    var submitButton: UIButton!
    var successLabel: UILabel!
    var titleButton: UIButton!
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {

        super.init(style: style, reuseIdentifier: reuseIdentifier)
        
                selectionStyle = .none
        backgroundColor = UIColor(named: "SpotBlack")
        
        botImage = UIImageView(frame: CGRect(x: 19, y: 15, width: 34.4, height: 40))
        botImage.image = UIImage(named: "TheB0t")
        addSubview(botImage)
        
        contactLabel = UILabel(frame: CGRect(x: botImage.frame.maxX + 10, y: 20, width: 100, height: 18))
        contactLabel.text = "Feedback"
        contactLabel.textColor = UIColor(red:0.88, green:0.88, blue:0.88, alpha:1.0)
        contactLabel.font = UIFont(name: "SFCamera-Regular", size: 14)
        contentView.addSubview(contactLabel)
        
        improveLabel = UILabel(frame: CGRect(x: botImage.frame.maxX + 10, y: 40, width: UIScreen.main.bounds.width - 40, height: 16))
        improveLabel.text = "Help us improve sp0t!"
        improveLabel.textColor = UIColor(red: 0.71, green: 0.71, blue: 0.71, alpha:1.0)
        improveLabel.font = UIFont(name: "SFCamera-Regular", size: 12)
        contentView.addSubview(improveLabel)
        
        titleButton = UIButton(frame: CGRect(x: 10, y: 10, width: UIScreen.main.bounds.width - 20, height: 60))
        titleButton.backgroundColor = nil
        titleButton.addTarget(self, action: #selector(feedbackTap(_:)), for: .touchUpInside)
        contentView.addSubview(titleButton)
        
        textView = UITextView(frame: CGRect(x: 20, y: 70, width: UIScreen.main.bounds.width - 40, height: 120))
        textView.backgroundColor = UIColor(red: 0.11, green: 0.11, blue: 0.11, alpha:1.0)
        textView.layer.cornerRadius = 7.5
        textView.textColor = UIColor.white
        textView.font = UIFont(name: "SFCamera-regular", size: 12)
        textView.isScrollEnabled = false
        textView.textContainer.lineBreakMode = .byTruncatingHead
        textView.textContainerInset = UIEdgeInsets(top: 8, left: 8, bottom: 8, right: 8)
        contentView.addSubview(textView)
        
        submitButton = UIButton(frame: CGRect(x: UIScreen.main.bounds.width - 74, y: 195, width: 50, height: 20))
        submitButton.setTitle("Submit", for: .normal)
        submitButton.setTitleColor(UIColor(named: "SpotGreen"), for: .normal)
        submitButton.titleLabel?.font = UIFont(name: "SFCamera-Semibold", size: 14)
        contentView.addSubview(submitButton)
    }
    
    @objc func feedbackTap(_ sender: UIButton) {
        textView.becomeFirstResponder()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

class SettingsFindFriendsCell: UITableViewCell {
    
    var findFriendsButton: UIButton!
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        
        backgroundColor = UIColor(named: "SpotBlack")
        selectionStyle = .none
        
        findFriendsButton = UIButton(frame: CGRect(x: 8.5, y: 5, width: 150, height: 40))
        findFriendsButton.titleEdgeInsets = UIEdgeInsets(top: 5, left: 10, bottom: 5, right: 10)
        findFriendsButton.setTitle("Add friends", for: .normal)
        findFriendsButton.setTitleColor(UIColor(red:0.88, green:0.88, blue:0.88, alpha:1.0), for: .normal)
        findFriendsButton.contentHorizontalAlignment = .left
        findFriendsButton.titleLabel?.font = UIFont(name: "SFCamera-Regular", size: 14)
        contentView.addSubview(findFriendsButton)
        
        let bottomLine = UIView(frame: CGRect(x: 15, y: 49, width: UIScreen.main.bounds.width - 40, height: 1))
        bottomLine.backgroundColor = UIColor(red: 0.162, green: 0.162, blue: 0.162, alpha: 1)
        addSubview(bottomLine)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

class SettingsManageAccount: UITableViewCell {
    
    var manageAccountButton: UIButton!
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        
        backgroundColor = UIColor(named: "SpotBlack")
        selectionStyle = .none
        
        manageAccountButton = UIButton(frame: CGRect(x: 8.5, y: 5, width: 150, height: 40))
        manageAccountButton.titleEdgeInsets = UIEdgeInsets(top: 5, left: 10, bottom: 5, right: 10)
        manageAccountButton.setTitle("Manage Account", for: .normal)
        manageAccountButton.setTitleColor(UIColor(red:0.88, green:0.88, blue:0.88, alpha:1.0), for: .normal)
        manageAccountButton.contentHorizontalAlignment = .left
        manageAccountButton.titleLabel?.font = UIFont(name: "SFCamera-Regular", size: 14)
        contentView.addSubview(manageAccountButton)
        
        let bottomLine = UIView(frame: CGRect(x: 15, y: 49, width: UIScreen.main.bounds.width - 40, height: 1))
        bottomLine.backgroundColor = UIColor(red: 0.162, green: 0.162, blue: 0.162, alpha: 1)
        addSubview(bottomLine)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

class SettingsReviewCell: UITableViewCell {
    
    var reviewButton: UIButton!
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        
        backgroundColor = UIColor(named: "SpotBlack")
        selectionStyle = .none
        
        reviewButton = UIButton(frame: CGRect(x: 8.5, y: 5, width: 220, height: 40))
        reviewButton.titleEdgeInsets = UIEdgeInsets(top: 5, left: 10, bottom: 5, right: 10)
        reviewButton.setTitle("Review public submissions", for: .normal)
        reviewButton.setTitleColor(UIColor(red:0.88, green:0.88, blue:0.88, alpha:1.0), for: .normal)
        reviewButton.contentHorizontalAlignment = .left
        reviewButton.titleLabel?.font = UIFont(name: "SFCamera-Regular", size: 14)
        contentView.addSubview(reviewButton)
        
        let bottomLine = UIView(frame: CGRect(x: 15, y: 49, width: UIScreen.main.bounds.width - 40, height: 1))
        bottomLine.backgroundColor = UIColor(red: 0.162, green: 0.162, blue: 0.162, alpha: 1)
        addSubview(bottomLine)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
