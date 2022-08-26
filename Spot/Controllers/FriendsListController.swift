//
//  FriendsListController.swift
//  Spot
//
//  Created by Kenny Barone on 6/25/22.
//  Copyright © 2022 sp0t, LLC. All rights reserved.
//

import Foundation
import UIKit
import Firebase
import FirebaseUI
import Mixpanel

protocol FriendsListDelegate {
    func finishPassing(selectedUsers: [UserProfile])
}

class FriendsListController: UIViewController {
    
    let allowsSelection: Bool
    let showsSearchBar: Bool
    var readyToDismiss = true
    var queried = false
    
    var doneButton: UIButton?
    var cancelButton: UIButton!
    var titleLabel: UILabel!
    var tableView: UITableView!
    var searchBar: UISearchBar?

    var confirmedIDs: [String] /// users who cannot be unselected
    var friendIDs: [String]
    var friendsList: [UserProfile]
    var queriedFriends: [UserProfile] = []
    
    var searchPan: UIPanGestureRecognizer?
    var delegate: FriendsListDelegate?
    
    var previousVC: UIViewController?
    
    var drawerView: DrawerView?
        
    init(fromVC: UIViewController, allowsSelection: Bool, showsSearchBar: Bool, friendIDs: [String], friendsList: [UserProfile], confirmedIDs: [String], presentedWithDrawerView: DrawerView? = nil) {
        previousVC = fromVC
        self.allowsSelection = allowsSelection
        self.showsSearchBar = showsSearchBar
        self.friendIDs = friendIDs
        self.friendsList = friendsList
        self.queriedFriends = friendsList
        self.confirmedIDs = confirmedIDs
        self.drawerView = presentedWithDrawerView
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        if showsSearchBar { addSearchBar() }
        addTableView()
        if friendsList.isEmpty {
            DispatchQueue.global(qos: .userInitiated).async {
                self.getFriends()
            }
        }
        presentationController?.delegate = self
    }
    
    func addTableView() {
        
        view.backgroundColor = .white
        
        if allowsSelection {
            doneButton = UIButton {
                $0.setTitle("Done", for: .normal)
                $0.setTitleColor(UIColor(named: "SpotGreen"), for: .normal)
                $0.titleLabel?.font = UIFont(name: "SFCompactText-Bold", size: 16)
                $0.addTarget(self, action: #selector(doneTap(_:)), for: .touchUpInside)
                view.addSubview($0)
            }
            doneButton!.snp.makeConstraints {
                $0.trailing.equalToSuperview().inset(7)
                $0.top.equalTo(12)
                $0.width.equalTo(60)
                $0.height.equalTo(30)
            }
        }
        
        cancelButton = UIButton {
            $0.setImage(UIImage(named: "CancelButtonDark"), for: .normal)
            $0.imageEdgeInsets = UIEdgeInsets(top: 5, left: 5, bottom: 5, right: 5)
            $0.addTarget(self, action: #selector(cancelTap(_:)), for: .touchUpInside)
            view.addSubview($0)
        }
        cancelButton.snp.makeConstraints {
            $0.leading.top.equalTo(7)
            $0.width.height.equalTo(40)
        }
        
        titleLabel = UILabel {
            $0.text = allowsSelection ? "Select friends" : "Friends list"
            $0.textColor = .black
            $0.font = UIFont(name: "SFCompactText-Heavy", size: 20.5)
            $0.textAlignment = .center
            view.addSubview($0)
        }
        titleLabel.snp.makeConstraints {
            $0.top.equalTo(15)
            $0.width.equalTo(200)
            $0.centerX.equalToSuperview()
        }
        
        tableView = UITableView {
            $0.backgroundColor = nil
            $0.separatorStyle = .none
            $0.dataSource = self
            $0.delegate = self
            $0.showsVerticalScrollIndicator = false
            $0.separatorStyle = .none
            $0.contentInset = UIEdgeInsets(top: 0, left: 0, bottom: 100, right: 0)
            $0.register(ChooseFriendsCell.self, forCellReuseIdentifier: "FriendsCell")
            $0.translatesAutoresizingMaskIntoConstraints = false
            view.addSubview($0)
        }
        tableView.snp.makeConstraints {
            let topConstraint = showsSearchBar ? 115 : 60
            let inset = showsSearchBar ? 50 : 10
            $0.leading.trailing.equalToSuperview()
            $0.top.equalTo(topConstraint)
            $0.height.equalToSuperview().inset(inset)
        }
    }
    
    func addSearchBar() {
        searchBar = UISearchBar {
            $0.tintColor = UIColor(named: "SpotGreen")
            $0.searchTextField.backgroundColor = UIColor(red: 0.945, green: 0.945, blue: 0.949, alpha: 1)
            $0.searchTextField.leftView?.tintColor = UIColor(red: 0.396, green: 0.396, blue: 0.396, alpha: 1)
            $0.delegate = self
            $0.autocapitalizationType = .none
            $0.autocorrectionType = .no
            $0.placeholder = " Search"
            $0.clipsToBounds = true
            $0.layer.cornerRadius = 3
            $0.keyboardDistanceFromTextField = 250
            view.addSubview($0)
        }
        searchBar!.snp.makeConstraints {
            $0.leading.trailing.equalToSuperview().inset(16)
            $0.top.equalTo(60)
            $0.height.equalTo(36)
        }
        
        searchPan = UIPanGestureRecognizer(target: self, action: #selector(searchPan(_:)))
        searchPan!.delegate = self
        searchPan!.isEnabled = false
        view.addGestureRecognizer(searchPan!)
    }
    
    func getFriends() {
        let db: Firestore = Firestore.firestore()
        let dispatch = DispatchGroup()
        
        for id in friendIDs {
            dispatch.enter()
            db.collection("users").document(id).getDocument { [weak self] snap, err in
                do {
                    guard let self = self else { return }
                    let unwrappedInfo = try snap?.data(as: UserProfile.self)
                    guard var userInfo = unwrappedInfo else { dispatch.leave(); return }
                    userInfo.id = id
                    self.friendsList.append(userInfo)
                    dispatch.leave()
                } catch {
                    dispatch.leave()
                }
            }
        }
        
        dispatch.notify(queue: .main) { [weak self] in
            guard let self = self else { return }
            self.tableView.reloadData()
        }
    }
    
    @objc func doneTap(_ sender: UIButton) {
        var selectedUsers: [UserProfile] = []
        for friend in friendsList { if friend.selected { selectedUsers.append(friend) }}
        delegate?.finishPassing(selectedUsers: selectedUsers)
        Mixpanel.mainInstance().track(event: "FriendsListDoneTap", properties: ["selectedCount": selectedUsers.count])
        DispatchQueue.main.async { self.dismiss(animated: true) }
    }
    
    @objc func cancelTap(_ sender: UIButton) {
        Mixpanel.mainInstance().track(event: "FriendsListCancel")
        DispatchQueue.main.async { self.dismiss(animated: true) }
    }
    
    @objc func searchPan(_ sender: UIPanGestureRecognizer) {
        /// remove keyboard on down swipe + vertical swipe > horizontal
        if abs(sender.translation(in: view).y) > abs(sender.translation(in: view).x) {
            searchBar!.resignFirstResponder()
        }
    }
}

extension FriendsListController: UIGestureRecognizerDelegate, UIAdaptivePresentationControllerDelegate {
    
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
                
        if gestureRecognizer.view == view, let gesture = gestureRecognizer as? UIPanGestureRecognizer {
            return shouldRecognize(searchPan: gesture)
            
        } else if otherGestureRecognizer.view == view, let gesture = gestureRecognizer as? UIPanGestureRecognizer {
            return shouldRecognize(searchPan: gesture)
        }
        
        return true
    }
    
    func shouldRecognize(searchPan: UIPanGestureRecognizer) -> Bool {
        /// down swipe with table not offset return true
        return tableView.contentOffset.y < 5 && searchPan.translation(in: view).y > 0
    }
    
    func presentationControllerShouldDismiss(_ presentationController: UIPresentationController) -> Bool {
        /// dont want to recognize swipe to dismiss with keyboard active
        return readyToDismiss
    }
}

extension FriendsListController: UISearchBarDelegate {
    
    func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
        queried = searchText != ""
        queriedFriends.removeAll()
        queriedFriends = getQueriedUsers(userList: friendsList, searchText: searchText)
        DispatchQueue.main.async { self.tableView.reloadData() }
    }
    
    func searchBarTextDidBeginEditing(_ searchBar: UISearchBar) {
        searchPan!.isEnabled = true
        readyToDismiss = false
        queried = true
    }
    
    func searchBarTextDidEndEditing(_ searchBar: UISearchBar) {
        searchPan!.isEnabled = false
        /// lag on ready to dismiss to avoid double tap to dismiss
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
            guard let self = self else { return }
            self.readyToDismiss = true
        }
    }
}

extension FriendsListController: UITableViewDelegate, UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return queried ? queriedFriends.count : friendsList.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        if let cell = tableView.dequeueReusableCell(withIdentifier: "FriendsCell", for: indexPath) as? ChooseFriendsCell {
            let friend = queried ? queriedFriends[indexPath.row] : friendsList[indexPath.row]
            let editable = !confirmedIDs.contains(friend.id!)
            cell.setUp(user: friend, allowsSelection: allowsSelection, editable: editable)
            return cell
        }
        return UITableViewCell()
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 63
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        if self.previousVC?.navigationController != nil {
            let profileVC = ProfileViewController(userProfile: self.friendsList[indexPath.row], presentedDrawerView: drawerView)
            self.previousVC?.navigationController!.pushViewController(profileVC, animated: true)
            dismiss(animated: true)
            return
        }
        
        let id = queried ? queriedFriends[indexPath.row].id! : friendsList[indexPath.row].id!
        if confirmedIDs.contains(id) { return } /// cannot unselect confirmed ID
        
        if queried { if let i = queriedFriends.firstIndex(where: {$0.id == id}) { queriedFriends[i].selected = !queriedFriends[i].selected } }
        if let i = friendsList.firstIndex(where: {$0.id == id}) { friendsList[i].selected = !friendsList[i].selected }
        DispatchQueue.main.async { self.tableView.reloadData() }
    }
}

class ChooseFriendsCell: UITableViewCell {
    
    var userID = ""

    var profileImage: UIImageView!
    var avatarImage: UIImageView!
    var username: UILabel!
    var selectedBubble: UIView!
    var bottomLine: UIView!
        
    func setUp(user: UserProfile, allowsSelection: Bool, editable: Bool) {
        
        backgroundColor = .white
        contentView.alpha = 1.0
        selectionStyle = .none
        userID = user.id!
        
        resetCell()
        
        profileImage = UIImageView {
            $0.contentMode = .scaleAspectFit
            $0.layer.cornerRadius = 21
            $0.clipsToBounds = true
            contentView.addSubview($0)
        }
        profileImage.snp.makeConstraints {
            $0.leading.equalTo(15)
            $0.top.equalTo(8)
            $0.width.height.equalTo(42)
        }
        
        avatarImage = UIImageView {
            $0.contentMode = .scaleAspectFill
            contentView.addSubview($0)
        }
        avatarImage.snp.makeConstraints {
            $0.leading.equalTo(profileImage).inset(-10)
            $0.bottom.equalTo(profileImage).inset(-2)
            $0.height.equalTo(25)
            $0.width.equalTo(17.33)
        }
        
        let transformer = SDImageResizingTransformer(size: CGSize(width: 100, height: 100), scaleMode: .aspectFill)
        profileImage.sd_setImage(with: URL(string: user.imageURL), placeholderImage: nil, options: .highPriority, context: [.imageTransformer: transformer])
        
        let aviTransformer = SDImageResizingTransformer(size: CGSize(width: 69.4, height: 100), scaleMode: .aspectFit)
        avatarImage.sd_setImage(with: URL(string: user.avatarURL ?? ""), placeholderImage: nil, options: .highPriority, context: [.imageTransformer: aviTransformer])

        username = UILabel {
            $0.text = user.username
            $0.textColor = .black
            $0.font = UIFont(name: "SFCompactText-Semibold", size: 16)
            contentView.addSubview($0)
        }
        username.snp.makeConstraints {
            $0.leading.equalTo(profileImage.snp.trailing).offset(8)
            $0.top.equalTo(21)
            $0.trailing.equalToSuperview().inset(60)
        }
        
        if allowsSelection {
            selectedBubble = UIView {
                $0.frame = CGRect(x: UIScreen.main.bounds.width - 49, y: 17, width: 24, height: 24)
                $0.backgroundColor = user.selected ? UIColor(named: "SpotGreen") : UIColor(red: 0.975, green: 0.975, blue: 0.975, alpha: 1)
                $0.layer.borderColor = UIColor(red: 0.863, green: 0.863, blue: 0.863, alpha: 1).cgColor
                $0.layer.borderWidth = 2
                $0.layer.cornerRadius = 12.5
                contentView.addSubview($0)
            }
            selectedBubble.snp.makeConstraints {
                $0.trailing.equalToSuperview().inset(25)
                $0.width.height.equalTo(24)
                $0.centerY.equalToSuperview()
            }
        }
        
        bottomLine = UIView {
            $0.backgroundColor = UIColor(red: 0.967, green: 0.967, blue: 0.967, alpha: 1)
            contentView.addSubview($0)
        }
        bottomLine.snp.makeConstraints {
            $0.leading.trailing.bottom.equalToSuperview()
            $0.height.equalTo(1)
        }
                
        if !editable {
            contentView.alpha = 0.5
        }
    }
        
    func resetCell() {
        if profileImage != nil { profileImage.image = UIImage(); profileImage.removeFromSuperview() }
        if avatarImage != nil { avatarImage.image = UIImage(); avatarImage.removeFromSuperview() }
        if username != nil { username.text = "" }
        if selectedBubble != nil { selectedBubble.backgroundColor = nil; selectedBubble.layer.borderColor = nil }
        if bottomLine != nil { bottomLine.backgroundColor = nil }
    }
    
    override func prepareForReuse() {
        super.prepareForReuse()
        if profileImage != nil { profileImage.sd_cancelCurrentImageLoad() }
        if avatarImage != nil { avatarImage.sd_cancelCurrentImageLoad() }
    }
}

