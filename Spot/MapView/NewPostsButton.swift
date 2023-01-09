//
//  NewPostsButton.swift
//  Spot
//
//  Created by Oforkanji Odekpe on 10/22/22.
//  Copyright © 2022 sp0t, LLC. All rights reserved.
//

import Mixpanel
import UIKit

final class NewPostsButton: UIButton {
    private lazy var backgroundImageView = UIImageView(image: UIImage(named: "NewPostsIcon"))
    private lazy var newPostsIndicator: UIView = {
        let imageView = UIView()
        imageView.backgroundColor = UIColor(red: 0.225, green: 0.952, blue: 1, alpha: 1)
        imageView.layer.cornerRadius = 21 / 2
        return imageView
    }()
    private lazy var postCountBackground = UIImageView(image: UIImage(named: "PostCountBackground"))
    private lazy var countLabel: UILabel = {
        let label = UILabel()
        label.textColor = .black
        label.font = UIFont(name: "SFCompactText-Heavy", size: 15)
        label.textAlignment = .center
        return label
    }()

    var totalPosts = 0
    var unseenPosts: Int = 0 {
        didSet {
            if unseenPosts > 0 {
                countLabel.attributedText = NSMutableAttributedString(
                    string: String(unseenPosts),
                    attributes: [NSAttributedString.Key.kern: -0.75]
                )
                postCountBackground.isHidden = false
                backgroundImageView.alpha = 1.0
            } else {
                postCountBackground.isHidden = true
                backgroundImageView.alpha = 0.8
                // set to new asset
            }
            backgroundImageView.image = totalPosts == 0 ? UIImage(named: "NewPostsIconGray") : UIImage(named: "NewPostsIcon")
        }
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        translatesAutoresizingMaskIntoConstraints = false

        let tap = UITapGestureRecognizer(target: self, action: #selector(tap))
        addGestureRecognizer(tap)

        addSubview(backgroundImageView)
        backgroundImageView.snp.makeConstraints {
            $0.leading.trailing.bottom.equalToSuperview()
            $0.top.equalTo(2)
        }

        addSubview(postCountBackground)
        postCountBackground.isHidden = true
        postCountBackground.snp.makeConstraints {
            $0.top.equalToSuperview()
            $0.trailing.equalTo(-2)
            $0.width.height.equalTo(29)
        }

        postCountBackground.addSubview(newPostsIndicator)
        newPostsIndicator.snp.makeConstraints {
            $0.edges.equalToSuperview().inset(4)
        }

        newPostsIndicator.addSubview(countLabel)
        countLabel.snp.makeConstraints { $0.edges.equalToSuperview() }
    }

    func setHidden(hidden: Bool) {
        isHidden = hidden
    }

    @objc func tap() {
        guard let mapVC = viewContainingController() as? MapController else { return }
        Mixpanel.mainInstance().track(event: "MapControllerAnimateToMostRecentPost")

        if unseenPosts > 0 {
            mapVC.animateToMostRecentPost()
        } else {
            mapVC.centerMapOnMapPosts(animated: true, includeSeen: true)
        }
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
