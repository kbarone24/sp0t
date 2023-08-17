//
//  CreateThumbnailView.swift
//  Spot
//
//  Created by Kenny Barone on 8/1/23.
//  Copyright © 2023 sp0t, LLC. All rights reserved.
//

import Foundation
import UIKit
import Mixpanel

protocol CreateThumbnailDelegate: AnyObject {
    func cancel()
    func expandThumbnail()
}

class CreateThumbnailView: UIView {
    let thumbnailImage: UIImage
    weak var delegate: CreateThumbnailDelegate?

    private lazy var thumbnailView: UIImageView = {
        let view = UIImageView()
        view.contentMode = .scaleAspectFill
        view.layer.cornerRadius = 25
        view.layer.masksToBounds = true
        view.isUserInteractionEnabled = true
        view.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(thumbnailTap)))
        return view
    }()

    private lazy var cancelButton: UIButton = {
        var configuration = UIButton.Configuration.plain()
        configuration.contentInsets = NSDirectionalEdgeInsets(top: 5, leading: 5, bottom: 5, trailing: 5)
        let button = UIButton(configuration: configuration)
        button.setImage(UIImage(named: "CircleCancelButton"), for: .normal)
        button.addTarget(self, action: #selector(cancelTap), for: .touchUpInside)
        return button
    }()

    private lazy var playButton = UIImageView(image: UIImage(named: "PlayButton"))

    init(thumbnailImage: UIImage, videoURL: URL?) {
        self.thumbnailImage = thumbnailImage
        super.init(frame: .zero)

        thumbnailView.image = thumbnailImage
        addSubview(thumbnailView)
        thumbnailView.snp.makeConstraints {
            $0.edges.equalToSuperview()
        }

        addSubview(cancelButton)
        cancelButton.snp.makeConstraints {
            $0.top.trailing.equalToSuperview().inset(5)
            $0.height.width.equalTo(40)
        }

        if videoURL != nil {
            thumbnailView.addSubview(playButton)
            playButton.snp.makeConstraints {
                $0.centerX.centerY.equalToSuperview()
                $0.height.width.equalTo(40)
            }
        }
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    @objc private func cancelTap() {
        Mixpanel.mainInstance().track(event: "CreatePostThumbnailCancelTap")
        delegate?.cancel()
    }

    @objc private func thumbnailTap() {
        delegate?.expandThumbnail()
    }
}
