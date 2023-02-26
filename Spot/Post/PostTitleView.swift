//
//  PostTitleView.swift
//  Spot
//
//  Created by Kenny Barone on 2/17/23.
//  Copyright © 2023 sp0t, LLC. All rights reserved.
//

import Foundation
import UIKit

final class PostTitleView: UIView {
    override var intrinsicContentSize: CGSize {
        return UIView.layoutFittingExpandedSize
    }

    // TODO: import real fonts for these buttons
    lazy var myWorldButton: UIButton = {
        var configuration = UIButton.Configuration.plain()
        configuration.contentInsets = NSDirectionalEdgeInsets(top: 5, leading: 5, bottom: 5, trailing: 5)
        let attText = AttributedString("My World", attributes: AttributeContainer([
            .font: UIFont(name: "UniversCE-Black", size: 15) as Any,
            .foregroundColor: UIColor.white
        ]))
        configuration.attributedTitle = attText
        let button = UIButton(configuration: configuration)
        button.alpha = 0.5
        button.addShadow(shadowColor: UIColor(red: 0, green: 0, blue: 0, alpha: 0.5).cgColor, opacity: 1, radius: 4, offset: CGSize(width: 0, height: 1.5))
        return button
    }()
    
    lazy var nearbyButton: UIButton = {
        var configuration = UIButton.Configuration.plain()
        configuration.contentInsets = NSDirectionalEdgeInsets(top: 5, leading: 5, bottom: 5, trailing: 5)
        let attText = AttributedString("Nearby", attributes: AttributeContainer([
            .font: UIFont(name: "UniversCE-Black", size: 15) as Any,
            .foregroundColor: UIColor.white
        ]))
        configuration.attributedTitle = attText
        let button = UIButton(configuration: configuration)
        button.alpha = 0.5
        button.addShadow(shadowColor: UIColor(red: 0, green: 0, blue: 0, alpha: 0.5).cgColor, opacity: 1, radius: 4, offset: CGSize(width: 0, height: 1.5))
        return button
    }()
    
    lazy var buttonBar: UIView = {
        let view = UIView()
        view.backgroundColor = .white.withAlphaComponent(0.95)
        view.layer.cornerRadius = 1
        return view
    }()
    
    lazy var findFriendsButton: UIButton = {
        var configuration = UIButton.Configuration.plain()
        configuration.contentInsets = NSDirectionalEdgeInsets(top: 10, leading: 10, bottom: 10, trailing: 10)
        let button = UIButton(configuration: configuration)
        button.setImage(UIImage(named: "FindFriendsNavIcon"), for: .normal)
        return button
    }()

    private lazy var titleLabel: UILabel = {
        let label = UILabel()
        label.textAlignment = .center
        label.lineBreakMode = .byTruncatingTail
        label.adjustsFontSizeToFitWidth = true
        label.minimumScaleFactor = 0.7
        label.textColor = UIColor(red: 0.961, green: 0.961, blue: 0.961, alpha: 1)
        label.font = UIFont(name: "UniversCE-Black", size: 16.5)
        return label
    }()

    func setUp(parentVC: PostParent, selectedSegment: FeedFetchType?) {
        if parentVC == .Home {
            addSubview(myWorldButton)
            myWorldButton.snp.makeConstraints {
                $0.trailing.equalTo(self.snp.centerX).offset(-5)
                $0.centerY.equalToSuperview()
            }

            addSubview(nearbyButton)
            nearbyButton.snp.makeConstraints {
                $0.leading.equalTo(self.snp.centerX).offset(5)
                $0.centerY.equalToSuperview()
            }
            addSubview(buttonBar)
            setButtonBar(animated: false, selectedSegment: selectedSegment ?? .MyPosts)
            addSubview(findFriendsButton)
            findFriendsButton.snp.makeConstraints {
                $0.leading.equalToSuperview().offset(5)
                $0.top.equalTo(myWorldButton).offset(-10)
                $0.width.equalTo(62)
                $0.height.equalTo(46)
            }
        } else {
            addSubview(titleLabel)
            titleLabel.snp.makeConstraints {
                $0.centerY.equalToSuperview()
                $0.centerX.equalToSuperview()
            }
        }
    }

    public func setButtonBar(animated: Bool, selectedSegment: FeedFetchType) {
        buttonBar.snp.removeConstraints()
        switch selectedSegment {
        case .NearbyPosts:
            nearbyButton.alpha = 1.0
            myWorldButton.alpha = 0.5
            buttonBar.snp.makeConstraints {
                $0.top.equalTo(nearbyButton.snp.bottom).offset(5)
                $0.centerX.equalTo(nearbyButton)
                $0.width.equalTo(65)
                $0.height.equalTo(3)
            }
        case .MyPosts:
            myWorldButton.alpha = 1.0
            nearbyButton.alpha = 0.5
            buttonBar.snp.makeConstraints {
                $0.top.equalTo(myWorldButton.snp.bottom).offset(5)
                $0.centerX.equalTo(myWorldButton)
                $0.width.equalTo(65)
                $0.height.equalTo(3)
            }
        }
        
        if animated {
            UIView.animate(withDuration: 0.2) { [weak self] in
                self?.layoutIfNeeded()
            }
        }
    }
}
