//
//  FailedPostView.swift
//  Spot
//
//  Created by Oforkanji Odekpe on 10/22/22.
//  Copyright © 2022 sp0t, LLC. All rights reserved.
//

import UIKit

final class FailedPostView: UIView {
    var contentView: UIView!
    var retryLabel: UILabel!
    var coverImage: UIImageView!
    var cancelButton: UIButton!
    var postButton: UIButton!

    var progressBar: UIView!
    var progressFill: UIView!

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = UIColor.black.withAlphaComponent(0.9)

        contentView = UIView {
            $0.backgroundColor = UIColor(red: 0.957, green: 0.957, blue: 0.957, alpha: 1)
            $0.layer.cornerRadius = 12
            addSubview($0)
        }
        contentView.snp.makeConstraints {
            $0.height.equalTo(160)
            $0.width.equalToSuperview().inset(30)
            $0.centerX.equalToSuperview()
            $0.centerY.equalToSuperview().offset(-100)
        }

        coverImage = UIImageView {
            $0.layer.cornerRadius = 8
            $0.clipsToBounds = true
            $0.contentMode = .scaleAspectFill
            contentView.addSubview($0)
        }
        coverImage.snp.makeConstraints {
            $0.leading.top.equalTo(12)
            $0.height.equalTo(70)
            $0.width.equalTo(70)
        }

        retryLabel = UILabel {
            $0.text = "Retry failed upload?"
            $0.textColor = .black
            $0.font = UIFont(name: "SFCompactText-Semibold", size: 18)
            contentView.addSubview($0)
        }
        retryLabel.snp.makeConstraints {
            $0.leading.equalTo(coverImage.snp.trailing).offset(14)
            $0.centerY.equalTo(coverImage.snp.centerY)
        }

        cancelButton = UIButton {
            $0.backgroundColor = UIColor(red: 0.871, green: 0.871, blue: 0.871, alpha: 1)
            $0.setTitle("Cancel", for: .normal)
            $0.setTitleColor(.red, for: .normal)
            $0.titleLabel?.font = UIFont(name: "SFCompactText-Semibold", size: 14.5)
            $0.layer.cornerRadius = 13
            $0.contentHorizontalAlignment = .center
            $0.contentVerticalAlignment = .center
            $0.addTarget(self, action: #selector(cancelTap), for: .touchUpInside)
            contentView.addSubview($0)
        }
        cancelButton.snp.makeConstraints {
            $0.trailing.equalTo(contentView.snp.centerX).offset(-15)
            $0.bottom.equalToSuperview().inset(12)
            $0.width.equalTo(100)
            $0.height.equalTo(40)
        }

        postButton = UIButton {
            $0.backgroundColor = UIColor(named: "SpotGreen")
            $0.setTitle("Post", for: .normal)
            $0.setTitleColor(.black, for: .normal)
            $0.titleLabel?.font = UIFont(name: "SFCompactText-Bold", size: 14.5)
            $0.layer.cornerRadius = 13
            $0.contentVerticalAlignment = .center
            $0.contentHorizontalAlignment = .center
            $0.addTarget(self, action: #selector(postTap), for: .touchUpInside)
            contentView.addSubview($0)
        }
        postButton.snp.makeConstraints {
            $0.leading.equalTo(contentView.snp.centerX).offset(15)
            $0.bottom.equalToSuperview().inset(12)
            $0.width.equalTo(100)
            $0.height.equalTo(40)
        }

        progressBar = UIView {
            $0.backgroundColor = UIColor(named: "SpotGreen")?.withAlphaComponent(0.22)
            $0.layer.cornerRadius = 6
            $0.layer.borderWidth = 2
            $0.layer.borderColor = UIColor(named: "SpotGreen")?.cgColor
            $0.isHidden = true
            addSubview($0)
        }
        progressBar.snp.makeConstraints {
            $0.leading.trailing.equalToSuperview().inset(50)
            $0.top.equalTo(contentView.snp.bottom).offset(30)
            $0.height.equalTo(18)
        }

        progressFill = UIView {
            $0.backgroundColor = UIColor(named: "SpotGreen")
            $0.layer.cornerRadius = 6
            progressBar.addSubview($0)
        }
        progressFill.snp.makeConstraints {
            $0.leading.equalToSuperview().offset(1)
            $0.width.equalTo(0)
            $0.height.equalTo(16)
        }
    }

    @objc func cancelTap() {
        if let cameraVC = viewContainingController() as? CameraViewController {
            cameraVC.deletePostDraft()
        }
    }

    @objc func postTap() {
        /// upload and delete post draft if success
        self.isUserInteractionEnabled = false
        if let cameraVC = viewContainingController() as? CameraViewController {
            cameraVC.uploadPostDraft()
            progressBar.isHidden = false
        }
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
