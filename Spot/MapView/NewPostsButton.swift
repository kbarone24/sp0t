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
    private lazy var contentArea: UIView = {
        let view = UIView()
        view.backgroundColor = UIColor.white.withAlphaComponent(0.95)
        view.layer.cornerRadius = 18
        return view
    }()

    private lazy var textLabel: UILabel = {
        let label = UILabel()

        label.textColor = UIColor(red: 0.663, green: 0.663, blue: 0.663, alpha: 1)
        label.font = UIFont(name: "SFCompactText-Bold", size: 14)
        label.clipsToBounds = true

        return label
    }()

    private lazy var newPostsIndicator: UIImageView = {
        let imageView = UIImageView()
        imageView.image = UIImage(named: "NewPostsIcon")
        imageView.isHidden = true

        return imageView
    }()

    private lazy var carat: UIImageView = {
        let imageView = UIImageView()
        imageView.image = UIImage(named: "SideCarat")
        imageView.isHidden = true

        return imageView
    }()

    var unseenPosts: Int = 0 {
        didSet {
            if unseenPosts > 0 {
                let text = unseenPosts > 1 ? "\(unseenPosts) new posts" : "\(unseenPosts) new post"
                textLabel.text = text
                textLabel.snp.updateConstraints({ $0.trailing.equalToSuperview().inset(38) })
                newPostsIndicator.isHidden = false
                carat.isHidden = true
            } else {
                textLabel.text = "See all posts"
                textLabel.snp.updateConstraints({ $0.trailing.equalToSuperview().inset(32) })
                newPostsIndicator.isHidden = true
                carat.isHidden = false
            }
        }
    }

    var totalPosts: Int = 0 {
        didSet {
            if totalPosts == 0 { isHidden = true }
        }
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        translatesAutoresizingMaskIntoConstraints = false

        let tap = UITapGestureRecognizer(target: self, action: #selector(tap))
        addGestureRecognizer(tap)

        addSubview(contentArea)
        contentArea.snp.makeConstraints { $0.leading.trailing.top.bottom.equalToSuperview().inset(5)
        }

        contentArea.addSubview(textLabel)
        textLabel.snp.makeConstraints {
            $0.leading.equalTo(14)
            $0.top.equalTo(12)
            $0.bottom.equalToSuperview().inset(11)
            $0.trailing.equalToSuperview().inset(32)
        }

        contentArea.addSubview(newPostsIndicator)
        newPostsIndicator.isHidden = true
        newPostsIndicator.snp.makeConstraints {
            $0.trailing.equalToSuperview().inset(10)
            $0.width.height.equalTo(23)
            $0.centerY.equalToSuperview()
        }

        contentArea.addSubview(carat)
        carat.isHidden = true
        carat.snp.makeConstraints {
            $0.trailing.equalToSuperview().inset(15)
            $0.width.equalTo(8.9)
            $0.height.equalTo(15)
            $0.centerY.equalToSuperview()
        }
    }

    func setHidden(hidden: Bool) {
        if totalPosts == 0 {
            isHidden = true
        } else {
            isHidden = hidden
        }
    }

    @objc func tap() {
        guard let mapVC = viewContainingController() as? MapController else {
            return
        }

        if unseenPosts > 0 {
            Mixpanel.mainInstance().track(event: "MapControllerAnimateToMostRecentPost")
            mapVC.animateToMostRecentPost()
        } else {
            Mixpanel.mainInstance().track(event: "MapControllerOpenSelectedMap")
            mapVC.openSelectedMap()
        }
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
