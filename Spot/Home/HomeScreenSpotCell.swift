//
//  HomeScreenSpotCell.swift
//  Spot
//
//  Created by Kenny Barone on 8/5/23.
//  Copyright © 2023 sp0t, LLC. All rights reserved.
//

import Foundation
import UIKit
import FirebaseStorageUI
import Mixpanel

final class HomeScreenSpotCell: UITableViewCell {
    var spot: MapSpot?

    private lazy var postArea: UIView = {
        let view = UIView()
        view.backgroundColor =  UIColor(red: 0.979, green: 0.979, blue: 0.979, alpha: 1)
        view.layer.cornerRadius = 22
        view.addShadow(shadowColor: UIColor.black.cgColor, opacity: 0.15, radius: 6, offset: CGSize(width: 0, height: 0))
        return view
    }()

    private lazy var hereNowView: UIView = {
        let view = UIView()
        view.backgroundColor = UIColor(red: 0.345, green: 1, blue: 0.345, alpha: 1)
        view.translatesAutoresizingMaskIntoConstraints = false
        view.layer.masksToBounds = true
        view.layer.cornerRadius = 16
        return view
    }()

    private lazy var hereNowIcon: UIImageView = {
        let view = UIImageView(image: UIImage(named: "FeedHereNowIcon"))
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    private lazy var hereNowCount: UILabel = {
        let label = UILabel()
        label.font = SpotFonts.SFCompactRoundedBold.fontWith(size: 17)
        label.textColor = .black
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private lazy var spotName: UILabel = {
        let label = UILabel()
        label.textColor = UIColor(red: 0.038, green: 0.038, blue: 0.038, alpha: 1)
        label.font = SpotFonts.UniversCE.fontWith(size: 21)
        return label
    }()

    private lazy var visitorsCount: UILabel = {
        let label = UILabel()
        label.textColor = UIColor(red: 0.404, green: 0.404, blue: 0.404, alpha: 1)
        label.font = SpotFonts.SFCompactRoundedSemibold.fontWith(size: 15.5)
        return label
    }()

    private lazy var avatarView = RightAlignedAvatarView()

    private lazy var friendCount: UILabel = {
        let label = UILabel()
        label.textColor = .white
        label.font = SpotFonts.SFCompactRoundedMedium.fontWith(size: 15.5)
        return label
    }()

    private lazy var recentPostImageView: UIImageView = {
        let view = UIImageView()
        view.layer.masksToBounds = true
        view.layer.cornerRadius = 7
        view.layer.borderColor = UIColor.black.cgColor
        view.isHidden = true
        return view
    }()

    // set bold / regular in configure
    private lazy var recentPostLabel: UILabel = {
        let label = UILabel()
        label.lineBreakMode = .byTruncatingTail
        return label
    }()

    let recentPostEmptyStateString = "Be the first to claim this spot!"

    private lazy var timestampLabel: UILabel = {
        let label = UILabel()
        label.textColor = UIColor(red: 0.767, green: 0.767, blue: 0.767, alpha: 1)
        label.font = SpotFonts.SFCompactRoundedMedium.fontWith(size: 15.5)
        return label
    }()


    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        backgroundColor = .clear
        selectionStyle = .none
        setUpView()
    }

    private func setUpView() {
        contentView.addSubview(postArea)
        postArea.snp.makeConstraints {
            $0.leading.equalTo(14)
            $0.trailing.equalTo(-17)
            $0.top.bottom.equalToSuperview().inset(8.5)
        }

        postArea.addSubview(hereNowView)
        hereNowView.snp.makeConstraints {
            $0.trailing.equalTo(-12)
            $0.top.equalTo(11)
        }

        hereNowIcon.setContentHuggingPriority(.required, for: .horizontal)
        hereNowIcon.setContentHuggingPriority(.required, for: .vertical)
        hereNowView.addSubview(hereNowIcon)
        hereNowIcon.snp.makeConstraints {
            $0.top.bottom.equalToSuperview().inset(6.5)
            $0.centerY.equalToSuperview()
            $0.leading.equalTo(12).priority(.high)
        }

        hereNowCount.setContentHuggingPriority(.required, for: .horizontal)
        hereNowCount.setContentHuggingPriority(.required, for: .vertical)
        hereNowView.addSubview(hereNowCount)
        hereNowCount.snp.makeConstraints {
            $0.leading.equalTo(hereNowIcon.snp.trailing).offset(3.5).priority(.high)
            $0.centerY.equalTo(hereNowIcon)
            $0.trailing.equalToSuperview().inset(12).priority(.high)
        }

        postArea.addSubview(spotName)
        spotName.snp.makeConstraints {
            $0.leading.equalTo(20)
            $0.top.equalTo(21)
            $0.trailing.equalToSuperview().offset(-20)
        }

        postArea.addSubview(visitorsCount)
        visitorsCount.snp.makeConstraints {
            $0.leading.equalTo(spotName)
            $0.top.equalTo(spotName.snp.bottom).offset(4)
        }

        postArea.addSubview(recentPostImageView)
        recentPostImageView.snp.makeConstraints {
            $0.leading.equalTo(21)
            $0.top.equalTo(visitorsCount.snp.bottom).offset(11)
            $0.height.width.equalTo(26)
        }

        postArea.addSubview(recentPostLabel)
        recentPostLabel.setContentHuggingPriority(.required, for: .horizontal)
        recentPostLabel.snp.makeConstraints {
            $0.leading.equalTo(recentPostImageView.snp.trailing).offset(8)
            $0.centerY.equalTo(recentPostImageView)
        }

        postArea.addSubview(timestampLabel)
        timestampLabel.setContentCompressionResistancePriority(.required, for: .horizontal)
        timestampLabel.snp.makeConstraints {
            $0.leading.equalTo(recentPostLabel.snp.trailing).offset(6)
            $0.trailing.lessThanOrEqualTo(-20)
            $0.bottom.equalTo(recentPostLabel)
        }
    }

    func configure(spot: MapSpot) {
        self.spot = spot

        configureHereNow()
        configureFriendsHereNow()

        spotName.attributedText = NSAttributedString(string: spot.spotName)
        visitorsCount.attributedText = NSAttributedString.getKernString(string: "\(spot.visitorList.count) joined", kern: 0.15)

        recentPostLabel.attributedText = NSAttributedString.getKernString(string: getRecentPostString(), kern: 0.15)
        configureRecentPost()

        configureTimestamp()
    }

    private func configureHereNow() {
        let hereNow = spot?.hereNow?.count ?? 0
        if hereNow == 0 {
            hereNowView.isHidden = true

            spotName.snp.updateConstraints {
                $0.trailing.equalTo(-20)
            }

        } else {
            hereNowView.isHidden = false
            hereNowCount.attributedText = NSAttributedString.getKernString(string: "\(String(hereNow))", kern: 0.15)
            hereNowView.layoutIfNeeded()
            let hereNowContentSize = hereNowIcon.bounds.width + hereNowCount.bounds.width + 24 + 3.5
            // content size was getting overwritten so manually calculating it

            spotName.snp.updateConstraints {
                $0.trailing.equalTo(-hereNowContentSize - 12 - 5)
            }
        }
    }

    // TODO: implement new avatar view
    private func configureFriendsHereNow() {
        let friendVisitors = spot?.friendsHereNow ?? []
        if friendVisitors.count == 0 {
            avatarView.isHidden = true
            friendCount.isHidden = true

        } else {
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
        var textPost = false

        // get most recent post that usr has access to and assign to values
        if let index = spot?.getLastAccessPostIndex(), index >= 0 {
            if spot?.postVideoURLs?[safe: index] ?? "" != "" {
                postString = "sent a video"

            } else if spot?.postImageURLs?[safe: index] ?? "" != "" {
                postString = "sent a photo"

            } else {
                if let caption = spot?.postCaptions?[safe: index] {
                    postString = caption
                    textPost = true
                } else {
                    postString = recentPostEmptyStateString
                }
            }

            if let username = spot?.postUsernames?[safe: index] {
                userString = username
            }
        } else {
            postString = recentPostEmptyStateString
        }

        if textPost {
            userString += ":"
        }

        if userString != "" {
            userString += " "
        }

        return userString + postString
    }

    private func configureRecentPost() {
        if spot?.seen ?? true ||  recentPostLabel.attributedText?.string == recentPostEmptyStateString {
            recentPostLabel.textColor = UIColor(red: 0.404, green: 0.404, blue: 0.404, alpha: 1)
            recentPostLabel.font = SpotFonts.SFCompactRoundedSemibold.fontWith(size: 15.5)
            recentPostImageView.layer.borderWidth = 0

            recentPostLabel.snp.updateConstraints {
                $0.leading.equalTo(recentPostImageView.snp.trailing).offset(8)
            }

        } else {
            recentPostLabel.textColor = UIColor(red: 0.038, green: 0.038, blue: 0.038, alpha: 1)
            recentPostLabel.font = SpotFonts.SFCompactRoundedBold.fontWith(size: 15.5)
            recentPostImageView.layer.borderWidth = 2
        }

        if let index = spot?.getLastAccessPostIndex(), index > 0, let url = spot?.postImageURLs?[safe: index], url != "" {
            let transformer = SDImageResizingTransformer(size: CGSize(width: 50, height: 50), scaleMode: .aspectFill)
            recentPostImageView.sd_setImage(
                with: URL(string: url),
                placeholderImage: UIImage(color: SpotColors.BlankImage.color),
                options: .highPriority,
                context: [.imageTransformer: transformer])

            recentPostImageView.isHidden = false
            recentPostLabel.snp.updateConstraints {
                $0.leading.equalTo(recentPostImageView.snp.trailing).offset(8)
            }

        } else {
            recentPostImageView.isHidden = true
            recentPostLabel.snp.updateConstraints {
                $0.leading.equalTo(recentPostImageView.snp.trailing).offset(-26)
            }
        }
    }

    private func configureTimestamp() {
        var timestampText = ""
        if let index = spot?.getLastAccessPostIndex(), index >= 0, let timestamp = spot?.postTimestamps[safe: index] {
            timestampText = timestamp.toString(allowDate: false)
        }
        timestampLabel.attributedText = NSAttributedString.getKernString(string: timestampText, kern: 0.15)
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        recentPostImageView.sd_cancelCurrentImageLoad()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
