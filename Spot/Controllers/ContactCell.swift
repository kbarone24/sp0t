//
//  ActivityCell.swift
//  Spot
//
//  Created by Shay Gyawali on 6/26/22.
//  Copyright © 2022 sp0t, LLC. All rights reserved.
//
import Foundation
import UIKit
import Firebase
import Mixpanel
import FirebaseUI
import FirebaseFirestore
import FirebaseFirestoreSwift
import FirebaseAuth
import FirebaseMessaging
import Geofirestore
import Contacts


class ContactCell: UITableViewCell {
    
    weak var notificationControllerDelegate: notificationDelegateProtocol?
    var username: UILabel!
    var name: UILabel!
    var detail: UILabel!
    var profilePicButton: UIButton!
    var profilePic: UIImageView!
    var userAvatar: UIImageView!
    var statusButton: UIButton!
    var imageURLs: [String] = []
    var contact: UserProfile!
    var number: String = ""
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?){
        super.init(style: style, reuseIdentifier: reuseIdentifier)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
        
    // MARK: setting up views
    func set(contact: UserProfile?, inviteContact: CNContact?, friend: FriendStatus, invited: InviteStatus){
                
        self.resetCell()
        
        self.contact = contact
        
        self.backgroundColor = .white
        
        self.selectionStyle = .none
        
        let profilePicButton = UIButton()
        contentView.addSubview(profilePicButton)
        
        profilePicButton.snp.makeConstraints{
            $0.centerY.equalToSuperview()
            $0.leading.equalToSuperview().offset(16)
            $0.height.width.equalTo(50)
        }
        
        print("YEOOO ✍🏽: ", friend, invited, "uprof: ", contact, "inviteContact: ", inviteContact)
        
        if(contact != nil){
            profilePic = UIImageView {
                $0.layer.masksToBounds = false
                $0.layer.cornerRadius = 25
                $0.clipsToBounds = true
                $0.contentMode = UIView.ContentMode.scaleAspectFill
                $0.isHidden = false
                $0.translatesAutoresizingMaskIntoConstraints = true
                profilePicButton.addSubview($0)
                let url = contact!.imageURL
                if url != "" {
                    let transformer = SDImageResizingTransformer(size: CGSize(width: 100, height: 100), scaleMode: .aspectFill)
                    $0.sd_setImage(with: URL(string: url), placeholderImage: nil, options: .highPriority, context: [.imageTransformer: transformer]) } else {print("profilePic not found")}
            } } else {
                if profilePic != nil { profilePic.image = UIImage() }
                profilePic = UIImageView(frame: CGRect(x: 14, y: 8.5, width: 44, height: 44))
                profilePic.layer.cornerRadius = profilePic.bounds.width/2
                profilePic.clipsToBounds = true
                profilePic.contentMode = .scaleAspectFill
                profilePic.image = UIImage(data: inviteContact?.imageData ?? Data()) ?? UIImage(named: "BlankContact")
                profilePicButton.addSubview(profilePic)
            }
        
        profilePic.snp.makeConstraints{
            $0.centerY.equalToSuperview()
            $0.centerX.equalToSuperview()
            $0.height.width.equalTo(50)
        }

        if (contact?.avatarURL ?? "") != "" {
            userAvatar = UIImageView{
                $0.layer.masksToBounds = false
                $0.contentMode = UIView.ContentMode.scaleAspectFill
                $0.isHidden = false
                let url = contact?.avatarURL!
                if url != "" {
                    let transformer = SDImageResizingTransformer(size: CGSize(width: 50.24, height: 66), scaleMode: .aspectFit)
                    $0.sd_setImage(with: URL(string: url!), placeholderImage: nil, options: .highPriority, context: [.imageTransformer: transformer])
                } else { print("Avatar not found") }
                $0.translatesAutoresizingMaskIntoConstraints = false
                contentView.addSubview($0)
            }
            
            userAvatar.snp.makeConstraints{
                $0.leading.equalTo(profilePic.snp.leading).offset(-3)
                $0.bottom.equalTo(profilePic.snp.bottom).offset(3)
                $0.height.equalTo(33)
                $0.width.equalTo(25.14)
            }
        }
        
        name = UILabel{
             //$0.text = contact?.name
             $0.isUserInteractionEnabled = true
             let tap = UITapGestureRecognizer(target: self, action: #selector(self.postTap(_:)))
             $0.addGestureRecognizer(tap)
             $0.numberOfLines = 0
             $0.textColor = UIColor(red: 0, green: 0, blue: 0, alpha: 1)
             $0.font = UIFont(name: "SFCompactText-Semibold", size: 16)
             $0.translatesAutoresizingMaskIntoConstraints = false
             contentView.addSubview($0)
         }
        
        name.snp.makeConstraints{
            $0.leading.equalTo(profilePic.snp.trailing).offset(8)
            $0.centerY.equalToSuperview().offset(-10)

        }
                
        detail = UILabel {
            //$0.text = contact?.username
            $0.numberOfLines = 2
            $0.lineBreakMode = NSLineBreakMode.byWordWrapping
            $0.textColor = UIColor(red: 0.683, green: 0.683, blue: 0.683, alpha: 1)
            $0.font = UIFont(name: "SFCompactText-Semibold", size: 13.5)
            $0.translatesAutoresizingMaskIntoConstraints = false
            contentView.addSubview($0)
        }
        
        
        detail.snp.makeConstraints{
            $0.leading.equalTo(profilePic.snp.trailing).offset(8)
            $0.top.equalTo(name.snp.bottom)
        }
        
        let addButton = UIButton{
            $0.backgroundColor = UIColor(red: 0.488, green: 0.969, blue: 1, alpha: 1)
            $0.layer.cornerRadius = 14
            $0.setImage(UIImage(named: "AddFriendIcon"), for: .normal)
            $0.imageEdgeInsets = UIEdgeInsets(top: 0, left: 0, bottom: 0, right: 7)

            let customButtonTitle = NSMutableAttributedString(string: "Add", attributes: [
                NSAttributedString.Key.font: UIFont(name: "SFCompactText-Bold", size: 15),
                //NSAttributedString.Key.backgroundColor: UIColor.red,
                NSAttributedString.Key.foregroundColor: UIColor.black
            ])
            $0.setAttributedTitle(customButtonTitle, for: .normal)
            $0.translatesAutoresizingMaskIntoConstraints = false
            //$0.addTarget(self, action: #selector(acceptTap(_:)), for: .touchUpInside)
            $0.isHidden = false
            //$0.addSubview(addFriendIcon)
        }
        
        let pendingButton = UIButton{
            $0.backgroundColor = UIColor(red: 0.965, green: 0.965, blue: 0.965, alpha: 1)
            $0.layer.cornerRadius = 14
            $0.imageEdgeInsets = UIEdgeInsets(top: 0, left: 0, bottom: 0, right: 7)

            let customButtonTitle = NSMutableAttributedString(string: "Pending", attributes: [
                NSAttributedString.Key.font: UIFont(name: "SFCompactText-Bold", size: 15),
                //NSAttributedString.Key.backgroundColor: UIColor.red,
                NSAttributedString.Key.foregroundColor: UIColor.black
            ])
            $0.setAttributedTitle(customButtonTitle, for: .normal)
            $0.translatesAutoresizingMaskIntoConstraints = false
            //$0.addTarget(self, action: #selector(acceptTap(_:)), for: .touchUpInside)
            $0.isHidden = false
            //$0.addSubview(addFriendIcon)
        }
        
        let friendsButton = UIButton{
            $0.backgroundColor = UIColor(red: 0.965, green: 0.965, blue: 0.965, alpha: 1)
            $0.layer.cornerRadius = 14
            $0.imageEdgeInsets = UIEdgeInsets(top: 0, left: 0, bottom: 0, right: 7)

            let customButtonTitle = NSMutableAttributedString(string: "Friends", attributes: [
                NSAttributedString.Key.font: UIFont(name: "SFCompactText-Bold", size: 15),
                //NSAttributedString.Key.backgroundColor: UIColor.red,
                NSAttributedString.Key.foregroundColor: UIColor.black
            ])
            $0.setAttributedTitle(customButtonTitle, for: .normal)
            $0.translatesAutoresizingMaskIntoConstraints = false
            //$0.addTarget(self, action: #selector(acceptTap(_:)), for: .touchUpInside)
            $0.isHidden = false
            //$0.addSubview(addFriendIcon)
        }
        
        let joinedButton = UIButton{
            $0.backgroundColor = UIColor(red: 0.965, green: 0.965, blue: 0.965, alpha: 1)
            $0.layer.cornerRadius = 14
            $0.imageEdgeInsets = UIEdgeInsets(top: 0, left: 0, bottom: 0, right: 7)

            let customButtonTitle = NSMutableAttributedString(string: "Joined", attributes: [
                NSAttributedString.Key.font: UIFont(name: "SFCompactText-Bold", size: 15),
                //NSAttributedString.Key.backgroundColor: UIColor.red,
                NSAttributedString.Key.foregroundColor: UIColor.black
            ])
            $0.setAttributedTitle(customButtonTitle, for: .normal)
            $0.translatesAutoresizingMaskIntoConstraints = false
            //$0.addTarget(self, action: #selector(acceptTap(_:)), for: .touchUpInside)
            $0.isHidden = false
            //$0.addSubview(addFriendIcon)
        }
        
        let inviteButton = UIButton{
            $0.backgroundColor = UIColor(red: 0.488, green: 0.969, blue: 1, alpha: 1)
            $0.layer.cornerRadius = 14
            $0.imageEdgeInsets = UIEdgeInsets(top: 0, left: 0, bottom: 0, right: 7)

            let customButtonTitle = NSMutableAttributedString(string: "Invite", attributes: [
                NSAttributedString.Key.font: UIFont(name: "SFCompactText-Bold", size: 15),
                //NSAttributedString.Key.backgroundColor: UIColor.red,
                NSAttributedString.Key.foregroundColor: UIColor.black
            ])
            $0.setAttributedTitle(customButtonTitle, for: .normal)
            $0.translatesAutoresizingMaskIntoConstraints = false
            //$0.addTarget(self, action: #selector(acceptTap(_:)), for: .touchUpInside)
            $0.isHidden = false
            //$0.addSubview(addFriendIcon)
        }
        
        let invitedButton = UIButton{
            $0.backgroundColor = UIColor(red: 0.965, green: 0.965, blue: 0.965, alpha: 1)
            $0.layer.cornerRadius = 14
            $0.imageEdgeInsets = UIEdgeInsets(top: 0, left: 0, bottom: 0, right: 7)

            let customButtonTitle = NSMutableAttributedString(string: "Invited", attributes: [
                NSAttributedString.Key.font: UIFont(name: "SFCompactText-Bold", size: 15),
                //NSAttributedString.Key.backgroundColor: UIColor.red,
                NSAttributedString.Key.foregroundColor: UIColor.black
            ])
            $0.setAttributedTitle(customButtonTitle, for: .normal)
            $0.translatesAutoresizingMaskIntoConstraints = false
            $0.isHidden = false
            //$0.addSubview(addFriendIcon)
        }
        
        if(contact != nil){
            name.text = contact!.username
            detail.text = contact!.username
            switch friend {
            case .none:
                statusButton = addButton
            case .pending:
                statusButton = pendingButton
            case .friends:
                statusButton = friendsButton
            }
        } else {
            name.text = inviteContact!.givenName + " " + inviteContact!.familyName
            let rawNumber = inviteContact!.phoneNumbers.first?.value
            number = rawNumber?.stringValue ?? ""
            detail.text = number
            switch invited {
            case .joined:
                statusButton = joinedButton
            case .invited:
                statusButton = invitedButton
            case .none:
                statusButton = inviteButton
                //statusButton.addTarget(self, action: #selector(inviteFriend(_:)), for: .touchUpInside)

            }
        }
        
        contentView.addSubview(statusButton)
        
        
        statusButton.snp.makeConstraints{
            $0.trailing.equalToSuperview().offset(-18)
            $0.centerY.equalToSuperview()
            $0.height.equalTo(39)
            $0.width.equalTo(88)
        }
        
        
    }
        

    @objc func postTap(_ sender: Any){
        //SHOW POST INSTEAD ONCE YOU CAN
        print("post tapped")
    }
    
    @objc func inviteFriend(_ sender: UIButton) {
        if let vc = viewContainingController() as? SendInvitesController {
            vc.sendInvite(number: number)
        }
    }
    
    func resetCell() {
        if self.contentView.subviews.isEmpty == false {
            for subview in self.contentView.subviews {
                subview.removeFromSuperview()
            }
        }
         
    }
    
       override func prepareForReuse() {
           super.prepareForReuse()
           if profilePic != nil { profilePic.sd_cancelCurrentImageLoad() }
           if userAvatar != nil { userAvatar.sd_cancelCurrentImageLoad() }
           self.isUserInteractionEnabled = false
        // Remove Subviews Or Layers That Were Added Just For This Cell
    }
    
}

