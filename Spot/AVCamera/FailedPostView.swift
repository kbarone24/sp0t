//
//  FailedPostView.swift
//  Spot
//
//  Created by Oforkanji Odekpe on 10/22/22.
//  Copyright © 2022 sp0t, LLC. All rights reserved.
//

import UIKit

final class FailedPostView: UIView {
    private lazy var contentView: UIView = {
        let view = UIView()
        view.backgroundColor = UIColor(red: 0.957, green: 0.957, blue: 0.957, alpha: 1)
        view.layer.cornerRadius = 12
        return view
    }()

    public lazy var coverImage: UIImageView = {
        let view = UIImageView()
        view.layer.cornerRadius = 8
        view.clipsToBounds = true
        view.contentMode = .scaleAspectFill
        return view
    }()

    private lazy var retryLabel: UILabel = {
        let label = UILabel()
        label.text = "Retry failed upload?"
        label.textColor = .black
        label.font = UIFont(name: "SFCompactText-Semibold", size: 18)
        return label
    }()

    private lazy var cancelButton: UIButton = {
        let button = UIButton()
        button.backgroundColor = UIColor(red: 0.871, green: 0.871, blue: 0.871, alpha: 1)
        button.setTitle("Cancel", for: .normal)
        button.setTitleColor(.red, for: .normal)
        button.titleLabel?.font = UIFont(name: "SFCompactText-Semibold", size: 14.5)
        button.layer.cornerRadius = 13
        button.contentHorizontalAlignment = .center
        button.contentVerticalAlignment = .center
        button.addTarget(self, action: #selector(cancelTap), for: .touchUpInside)
        return button
    }()

    private lazy var postButton: UIButton = {
        let button = UIButton()
        button.backgroundColor = UIColor(named: "SpotGreen")
        button.setTitle("Post", for: .normal)
        button.setTitleColor(.black, for: .normal)
        button.titleLabel?.font = UIFont(name: "SFCompactText-Bold", size: 14.5)
        button.layer.cornerRadius = 13
        button.contentVerticalAlignment = .center
        button.contentHorizontalAlignment = .center
        button.addTarget(self, action: #selector(postTap), for: .touchUpInside)
        return button
    }()

    private lazy var progressBar: UIView = {
        let view = UIView()
        view.backgroundColor = UIColor(named: "SpotGreen")?.withAlphaComponent(0.22)
        view.layer.cornerRadius = 6
        view.layer.borderWidth = 2
        view.layer.borderColor = UIColor(named: "SpotGreen")?.cgColor
        view.isHidden = true
        return view
    }()

    public lazy var progressFill: UIView = {
        let view = UIView()
        view.backgroundColor = UIColor(named: "SpotGreen")
        view.layer.cornerRadius = 6
        return view
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = UIColor.black.withAlphaComponent(0.9)

        addSubview(contentView)
        contentView.snp.makeConstraints {
            $0.height.equalTo(160)
            $0.width.equalToSuperview().inset(30)
            $0.centerX.equalToSuperview()
            $0.centerY.equalToSuperview().offset(-100)
        }

        contentView.addSubview(coverImage)
        coverImage.snp.makeConstraints {
            $0.leading.top.equalTo(12)
            $0.height.equalTo(70)
            $0.width.equalTo(70)
        }

        contentView.addSubview(retryLabel)
        retryLabel.snp.makeConstraints {
            $0.leading.equalTo(coverImage.snp.trailing).offset(14)
            $0.centerY.equalTo(coverImage.snp.centerY)
        }

        contentView.addSubview(cancelButton)
        cancelButton.snp.makeConstraints {
            $0.trailing.equalTo(contentView.snp.centerX).offset(-15)
            $0.bottom.equalToSuperview().inset(12)
            $0.width.equalTo(100)
            $0.height.equalTo(40)
        }

        contentView.addSubview(postButton)
        postButton.snp.makeConstraints {
            $0.leading.equalTo(contentView.snp.centerX).offset(15)
            $0.bottom.equalToSuperview().inset(12)
            $0.width.equalTo(100)
            $0.height.equalTo(40)
        }

        contentView.addSubview(progressBar)
        progressBar.snp.makeConstraints {
            $0.leading.trailing.equalToSuperview().inset(15)
            $0.centerY.equalTo(postButton)
            $0.height.equalTo(18)
        }

        progressBar.addSubview(progressFill)
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
            postButton.isHidden = true
            cancelButton.isHidden = true
        }
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
