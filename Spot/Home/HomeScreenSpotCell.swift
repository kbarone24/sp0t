//
//  HomeScreenSpotCell.swift
//  Spot
//
//  Created by Kenny Barone on 8/5/23.
//  Copyright © 2023 sp0t, LLC. All rights reserved.
//

import Foundation
import UIKit

final class HomeScreenSpotCell: UITableViewCell {
    var spot: MapSpot?

    private lazy var postArea: UIView = {
        let view = UIView()
        view.backgroundColor = UIColor(hexString: "1D1D1D")
        view.layer.cornerRadius = 18
        return view
    }()

    private lazy var spotName: UILabel = {
        let label = UILabel()
        label.textColor = UIColor(red: 1, green: 1, blue: 1, alpha: 1)
        label.font = UIFont(name: "SFCompactRounded-Semibold", size: 20.5)
        return label
    }()

    private lazy var visitorsIcon = UIImageView(image: UIImage(named: "SpotVisitorsIcon"))

    private lazy var visitorsCount: UILabel = {
        let label = UILabel()
        label.textColor = UIColor(red: 0.624, green: 0.624, blue: 0.624, alpha: 1)
        label.font = UIFont(name: "SFCompactRounded-Medium", size: 15.5)
        return label
    }()

    private lazy var separatorView0: UIView = {
        let view = UIView()
        view.backgroundColor = UIColor(red: 0.242, green: 0.242, blue: 0.242, alpha: 1)
        return view
    }()

    private lazy var hereNowIcon = UIImageView(image: UIImage(named: "HereNowIcon"))

    private lazy var hereNowCount: UILabel = {
        let label = UILabel()
        label.font = UIFont(name: "SFCompactRounded-Medium", size: 15.5)
        label.textColor = UIColor(red: 0.345, green: 1, blue: 0.345, alpha: 1)
        return label
    }()

    private lazy var separatorView1: UIView = {
        let view = UIView()
        view.backgroundColor = UIColor(red: 0.242, green: 0.242, blue: 0.242, alpha: 1)
        return view
    }()

    private lazy var avatarView = RightAlignedAvatarView()

    private lazy var friendCount: UILabel = {
        let label = UILabel()
        label.textColor = .white
        label.font = UIFont(name: "SFCompactRounded-Medium", size: 15.5)
        return label
    }()

    private lazy var unseenIcon: UIView = {
        let view = UIView()
        view.backgroundColor =  UIColor(red: 1, green: 0, blue: 0.66, alpha: 1)
        view.layer.cornerRadius = 4
        return view
    }()
    // set bold / regular in configure
    private lazy var recentPostLabel = UILabel()
    let recentPostEmptyStateString = "Be the first to claim this spot!"

    private lazy var timestampLabel: UILabel = {
        let label = UILabel()
        label.textColor = UIColor(red: 0.412, green: 0.412, blue: 0.412, alpha: 1)
        label.font = UIFont(name: "SFCompactRounded-Medium", size: 15.5)
        return label
    }()


    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        backgroundColor = SpotColors.SpotBlack.color
        selectionStyle = .none
        setUpView()
    }

    private func setUpView() {
        contentView.addSubview(postArea)
        postArea.snp.makeConstraints {
            $0.leading.equalTo(14)
            $0.trailing.equalTo(-17)
            $0.top.bottom.equalToSuperview().inset(7.5)
        }

        postArea.addSubview(spotName)
        spotName.snp.makeConstraints {
            $0.top.leading.equalTo(18)
            $0.trailing.lessThanOrEqualToSuperview().inset(18)
        }

        postArea.addSubview(visitorsIcon)
        visitorsIcon.snp.makeConstraints {
            $0.leading.equalTo(spotName)
            $0.top.equalTo(spotName.snp.bottom).offset(8)
        }

        postArea.addSubview(visitorsCount)
        visitorsCount.snp.makeConstraints {
            $0.leading.equalTo(visitorsIcon.snp.trailing).offset(5)
            $0.centerY.equalTo(visitorsIcon)
        }

        postArea.addSubview(separatorView0)
        separatorView0.snp.makeConstraints {
            $0.leading.equalTo(visitorsCount.snp.trailing).offset(8)
            $0.width.equalTo(2)
            $0.height.equalTo(18)
            $0.centerY.equalTo(visitorsIcon)
        }

        postArea.addSubview(hereNowIcon)
        hereNowIcon.snp.makeConstraints {
            $0.centerY.equalTo(separatorView0)
            $0.leading.equalTo(separatorView0.snp.trailing).offset(8)
        }

        postArea.addSubview(hereNowCount)
        hereNowCount.snp.makeConstraints {
            $0.leading.equalTo(hereNowIcon.snp.trailing).offset(5.5)
            $0.centerY.equalTo(hereNowIcon)
        }

        postArea.addSubview(separatorView1)
        separatorView1.snp.makeConstraints {
            $0.leading.equalTo(hereNowCount.snp.trailing).offset(8)
            $0.height.width.equalTo(separatorView0)
            $0.centerY.equalTo(hereNowCount)
        }

        postArea.addSubview(avatarView)
        avatarView.snp.makeConstraints {
            $0.leading.equalTo(separatorView1.snp.trailing).offset(8)
            $0.centerY.equalTo(separatorView1)
        }

        postArea.addSubview(friendCount)
        friendCount.snp.makeConstraints {
            $0.leading.equalTo(avatarView.snp.trailing).offset(5)
            $0.centerY.equalTo(avatarView)
            $0.trailing.lessThanOrEqualTo(18)
        }

        postArea.addSubview(timestampLabel)
        timestampLabel.snp.makeConstraints {
            $0.trailing.bottom.equalTo(-18)
        }

        postArea.addSubview(unseenIcon)
        unseenIcon.snp.makeConstraints {
            $0.leading.equalTo(18)
            $0.bottom.equalTo(-19)
            $0.height.width.equalTo(15)
        }

        postArea.addSubview(recentPostLabel)
    }

    func configure(spot: MapSpot) {
        self.spot = spot

        configureHereNow()
        configureFriendsHereNow()

        spotName.attributedText = NSAttributedString.getKernString(string: spot.spotName, kern: 0.2)
        visitorsCount.attributedText = NSAttributedString.getKernString(string: String(spot.visitorList.count), kern: 0.15)

        recentPostLabel.attributedText = NSAttributedString.getKernString(string: getRecentPostString(), kern: 0.15)
        configureRecentPost()

        timestampLabel.attributedText = NSAttributedString.getKernString(string: spot.lastPostTimestamp?.toString(allowDate: true) ?? "", kern: 0.15)
    }

    private func configureHereNow() {
        //TODO: replace with here now
        let hereNow = spot?.friendVisitors.count ?? 0
        if spot?.friendVisitors.isEmpty ?? true {
            separatorView0.isHidden = true
            hereNowIcon.isHidden = true
            hereNowCount.isHidden = true

        } else {
            hereNowIcon.isHidden = false
            hereNowCount.isHidden = false
            separatorView0.isHidden = false

            hereNowCount.attributedText = NSAttributedString.getKernString(string: "\(String(hereNow)) here", kern: 0.15)
        }
    }

    private func configureFriendsHereNow() {
        let friendVisitors = spot?.friendsHereNow ?? []
        if friendVisitors.count == 0 {
            separatorView1.isHidden = true
            avatarView.isHidden = true
            friendCount.isHidden = true

        } else {
            separatorView1.isHidden = false
            avatarView.isHidden = false
            friendCount.isHidden = false

            //TODO: add avatar view
            var friendVisitorString = "\(String(friendVisitors.count)) friend"
            if friendVisitors.count > 0 { friendVisitorString += "s"}
            friendCount.attributedText = NSAttributedString.getKernString(string: friendVisitorString, kern: 0.15)
        }
    }

    private func getRecentPostString() -> String {
        var userString = ""
        var postString = ""

        // get most recent post that usr has access to and assign to values
        if let index = spot?.getLastAccessPostIndex(), index >= 0 {
            let postDescriptor = spot?.postVideoURLs?[safe: index] ?? "" != "" ? "sent a video" :
            spot?.postImageURLs?[safe: index] ?? "" != "" ? "sent a photo" :
            spot?.postCaptions?[safe: index] ?? recentPostEmptyStateString

            postString = postDescriptor

            if let username = spot?.postUsernames?[safe: index] {
                userString = username
            }
        } else {
            postString = recentPostEmptyStateString
        }

        if userString != "" {
            userString += ": "
        }

        return userString + postString
    }

    private func configureRecentPost() {
        recentPostLabel.snp.removeConstraints()
        if recentPostLabel.attributedText?.string == recentPostEmptyStateString {
            recentPostLabel.textColor = UIColor(red: 0.412, green: 0.412, blue: 0.412, alpha: 1)
            recentPostLabel.font = UIFont(name: "SFCompactRounded-Medium", size: 15.5)

            unseenIcon.isHidden = true
            recentPostLabel.snp.makeConstraints {
                $0.leading.equalTo(18)
                $0.trailing.lessThanOrEqualTo(timestampLabel.snp.leading).offset(-8)
                $0.bottom.equalTo(-18)
            }

        } else if spot?.seen ?? true {
            recentPostLabel.textColor = UIColor(red: 0.875, green: 0.875, blue: 0.875, alpha: 1)
            recentPostLabel.font = UIFont(name: "SFCompactRounded-Medium", size: 15.5)

            unseenIcon.isHidden = true
            recentPostLabel.snp.makeConstraints {
                $0.leading.equalTo(18)
                $0.trailing.lessThanOrEqualTo(timestampLabel.snp.leading).offset(-8)
                $0.bottom.equalTo(-18)
            }

        } else {
            recentPostLabel.textColor = .white
            recentPostLabel.font = UIFont(name: "SFCompactRounded-Semibold", size: 15.5)

            unseenIcon.isHidden = false
            recentPostLabel.snp.makeConstraints {
                $0.leading.equalTo(unseenIcon.snp.trailing).offset(8)
                $0.trailing.lessThanOrEqualTo(timestampLabel.snp.leading).offset(-8)
                $0.bottom.equalTo(-18)
            }
        }
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
