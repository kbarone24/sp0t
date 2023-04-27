//
//  SpotscoreCell.swift
//  Spot
//
//  Created by Kenny Barone on 4/26/23.
//  Copyright © 2023 sp0t, LLC. All rights reserved.
//

import Foundation
import UIKit

class SpotscoreCell: UITableViewCell {
    private(set) lazy var upperDotView = UIView()
    private(set) lazy var lowerDotView = UIView()

    private(set) lazy var scoreLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont(name: "Gameplay", size: 11.31)
        label.textAlignment = .center
        return label
    }()

    private(set) lazy var avatarImage = UIImageView()
    private(set) lazy var avatarMask: UIView = {
        let mask = UIView()
        mask.backgroundColor = UIColor(red: 0.129, green: 0.129, blue: 0.129, alpha: 1.0)
        return mask
    }()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        backgroundColor = UIColor(red: 0.129, green: 0.129, blue: 0.129, alpha: 1)
        selectionStyle = .none

        contentView.addSubview(upperDotView)
        upperDotView.snp.makeConstraints {
            $0.top.equalTo(4)
            $0.leading.equalTo(47)
            $0.width.equalTo(2)
            $0.height.equalTo(26)
        }

        contentView.addSubview(scoreLabel)
        scoreLabel.snp.makeConstraints {
            $0.centerX.equalTo(upperDotView)
            $0.top.equalTo(upperDotView.snp.bottom).offset(6)
        }

        contentView.addSubview(lowerDotView)
        lowerDotView.snp.makeConstraints {
            $0.top.equalTo(scoreLabel.snp.bottom).offset(6)
            $0.leading.width.equalTo(upperDotView)
            $0.height.equalTo(9)
        }

        contentView.addSubview(avatarImage)
        avatarImage.snp.makeConstraints {
            $0.leading.equalTo(scoreLabel.snp.trailing).offset(6)
            $0.top.equalTo(8)
            $0.height.equalTo(50.13)
            $0.width.equalTo(44.56)
        }

        contentView.addSubview(avatarMask)
        avatarMask.snp.makeConstraints {
            $0.edges.equalTo(avatarImage)
        }
    }

    func setUp(avatar: AvatarProfile, dotCount: Int, maskOpacity: CGFloat) {
        var scoreText = String(avatar.unlockScore)
        if avatar.unlockScore < 100 {
            scoreText = "0" + scoreText
        }
        if avatar.unlockScore < 10 {
            scoreText = "0" + scoreText
        }

        scoreLabel.textColor = dotCount > 3 ? UIColor(red: 0.227, green: 0.851, blue: 0.953, alpha: 1) : UIColor(red: 0.624, green: 0.624, blue: 0.624, alpha: 1)
        scoreLabel.attributedText = NSMutableAttributedString(string: scoreText, attributes: [NSAttributedString.Key.kern: 0.79])

        avatarImage.image = UIImage(named: avatar.avatarName)
        addUpperDots(count: dotCount)
        addLowerDots(count: max(0, dotCount - 4))

        avatarMask.alpha = maskOpacity
    }

    private func addUpperDots(count: Int) {
        // 4 dots above score label, fill if user has reached level
        for i in 0...3 {
            let dot = UIView()
            dot.backgroundColor = count > i ? UIColor(red: 0.227, green: 0.851, blue: 0.953, alpha: 1) : UIColor(red: 0.624, green: 0.624, blue: 0.624, alpha: 1)
            upperDotView.addSubview(dot)
            dot.snp.makeConstraints {
                $0.leading.trailing.equalToSuperview()
                $0.height.equalTo(2)
                $0.top.equalTo(CGFloat(i * 6))
            }
        }
    }

    private func addLowerDots(count: Int) {
        // 4 dots above score label, fill if user has reached level
        for i in 0...1 {
            let dot = UIView()
            dot.backgroundColor = count > i ? UIColor(red: 0.227, green: 0.851, blue: 0.953, alpha: 1) : UIColor(red: 0.624, green: 0.624, blue: 0.624, alpha: 1)
            lowerDotView.addSubview(dot)
            dot.snp.makeConstraints {
                $0.leading.trailing.equalToSuperview()
                $0.height.equalTo(2)
                $0.top.equalTo(CGFloat(i * 6))
            }
        }
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
