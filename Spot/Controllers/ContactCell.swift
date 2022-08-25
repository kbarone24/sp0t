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
    var statusButton: StatusButton!
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
                
        self.contentView.isUserInteractionEnabled = true

        //keeping them buttons in case we wanna click into profiles in the future
        let profilePicButton = UIButton()
        contentView.addSubview(profilePicButton)
        
        profilePicButton.snp.makeConstraints{
            $0.centerY.equalToSuperview()
            $0.leading.equalToSuperview().offset(16)
            $0.height.width.equalTo(50)
        }
                
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
             $0.isUserInteractionEnabled = false
             $0.textColor = UIColor(red: 0, green: 0, blue: 0, alpha: 1)
             $0.font = UIFont(name: "SFCompactText-Semibold", size: 16)
             $0.adjustsFontSizeToFitWidth = false
             $0.lineBreakMode = .byTruncatingTail
             contentView.addSubview($0)
         }
        name.snp.makeConstraints{
            $0.leading.equalTo(profilePic.snp.trailing).offset(8)
            $0.centerY.equalToSuperview().offset(-10)
            $0.trailing.equalToSuperview().offset(-120)
        }
                
        detail = UILabel {
            //$0.text = contact?.username
            $0.numberOfLines = 0
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
        
        statusButton = StatusButton {
            $0.setUpButton(contact: contact, inviteContact: inviteContact, friend: friend, invited: invited)
            $0.translatesAutoresizingMaskIntoConstraints = false
            $0.isHidden = false
        }
        
        //cell details and adding targets that depend on contact type
        if(contact != nil){
            name.text = contact!.name
            detail.text = contact!.username
            if friend == .none{
                statusButton.addTarget(self, action: #selector(addFriend(_:)), for: .touchUpInside)
            }
        } else {
            name.text = inviteContact!.givenName + " " + inviteContact!.familyName
            let rawNumber = inviteContact!.phoneNumbers.first?.value
            number = rawNumber?.stringValue ?? ""
            detail.text = number
            if invited == .none {
                statusButton.addTarget(self, action: #selector(inviteFriend(_:)), for: .touchUpInside)
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
            
    @objc func inviteFriend(_ sender: Any) {
        if let vc = viewContainingController() as? SendInvitesController {
            vc.sendInvite(number: number)
        }
    }
    
    @objc func addFriend(_ sender: Any) {
        addFriend(senderProfile: UserDataModel.shared.userInfo, receiverID: contact.id!)
        let title = NSMutableAttributedString(string: "Pending", attributes: [
            NSAttributedString.Key.font: UIFont(name: "SFCompactText-Bold", size: 15),
            NSAttributedString.Key.foregroundColor: UIColor.black
        ])
        statusButton.setAttributedTitle(title, for: .normal)
        statusButton.backgroundColor = UIColor(red: 0.965, green: 0.965, blue: 0.965, alpha: 1)
        statusButton.removeTarget(self, action: #selector(addFriend(_:)), for: .touchUpInside)
        statusButton.setImage(nil, for: .normal)
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
           self.isUserInteractionEnabled = true
        // Remove Subviews Or Layers That Were Added Just For This Cell
    }
    
}

class StatusButton: UIButton {
    
    func setUpButton(contact: UserProfile?, inviteContact: CNContact?, friend: FriendStatus, invited: InviteStatus) {
        self.layer.cornerRadius = 14

        ///setting up different buttons
        if(contact != nil){
            switch friend {
            case .none:
                self.backgroundColor = UIColor(red: 0.488, green: 0.969, blue: 1, alpha: 1)
                self.setImage(UIImage(named: "AddFriendIcon"), for: .normal)
                self.imageEdgeInsets = UIEdgeInsets(top: 0, left: 0, bottom: 0, right: 7)

                let customButtonTitle = NSMutableAttributedString(string: "Add", attributes: [
                    NSAttributedString.Key.font: UIFont(name: "SFCompactText-Bold", size: 15),
                    NSAttributedString.Key.foregroundColor: UIColor.black
                ])
                self.setAttributedTitle(customButtonTitle, for: .normal)
            case .pending:
                self.backgroundColor = UIColor(red: 0.965, green: 0.965, blue: 0.965, alpha: 1)
                let customButtonTitle = NSMutableAttributedString(string: "Pending", attributes: [
                    NSAttributedString.Key.font: UIFont(name: "SFCompactText-Bold", size: 15),
                    NSAttributedString.Key.foregroundColor: UIColor.black
                ])
                self.setAttributedTitle(customButtonTitle, for: .normal)
                self.setImage(nil, for: .normal)

            case .friends:
                self.backgroundColor = UIColor(red: 0.965, green: 0.965, blue: 0.965, alpha: 1)
                let customButtonTitle = NSMutableAttributedString(string: "Friends", attributes: [
                    NSAttributedString.Key.font: UIFont(name: "SFCompactText-Bold", size: 15),
                    NSAttributedString.Key.foregroundColor: UIColor.black
                ])
                self.setAttributedTitle(customButtonTitle, for: .normal)
                self.setImage(nil, for: .normal)
            }
        } else {

            switch invited {
            case .joined:
                self.backgroundColor = UIColor(red: 0.965, green: 0.965, blue: 0.965, alpha: 1)
                let customButtonTitle = NSMutableAttributedString(string: "Joined", attributes: [
                    NSAttributedString.Key.font: UIFont(name: "SFCompactText-Bold", size: 15),
                    NSAttributedString.Key.foregroundColor: UIColor.black
                ])
                self.setAttributedTitle(customButtonTitle, for: .normal)
                self.setImage(nil, for: .normal)
            case .invited:
                self.backgroundColor = UIColor(red: 0.965, green: 0.965, blue: 0.965, alpha: 1)
                let customButtonTitle = NSMutableAttributedString(string: "Invited", attributes: [
                    NSAttributedString.Key.font: UIFont(name: "SFCompactText-Bold", size: 15),
                    NSAttributedString.Key.foregroundColor: UIColor.black
                ])
                self.setAttributedTitle(customButtonTitle, for: .normal)
                self.setImage(nil, for: .normal)
            case .none:
                self.backgroundColor = UIColor(red: 0.488, green: 0.969, blue: 1, alpha: 1)
                self.imageEdgeInsets = UIEdgeInsets(top: 0, left: 0, bottom: 0, right: 7)

                let customButtonTitle = NSMutableAttributedString(string: "Invite", attributes: [
                    NSAttributedString.Key.font: UIFont(name: "SFCompactText-Bold", size: 15),
                    NSAttributedString.Key.foregroundColor: UIColor.black
                ])
                self.setAttributedTitle(customButtonTitle, for: .normal)
                self.setImage(nil, for: .normal)
            }
        }
        
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = nil
    }
        
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
}

