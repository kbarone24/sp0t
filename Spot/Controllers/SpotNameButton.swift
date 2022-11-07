//
//  SpotNameButton.swift
//  Spot
//
//  Created by Kenny Barone on 11/2/22.
//  Copyright © 2022 sp0t, LLC. All rights reserved.
//

import Foundation
import UIKit

class SpotNameButton: UIButton {
    private lazy var spotIcon: UIImageView = {
        let view = UIImageView()
        view.image = UIImage(named: "AddSpotIcon")
        return view
    }()
    private lazy var cancelButton: UIButton = {
        let button = UIButton()
        button.setImage(UIImage(named: "ChooseSpotCancel"), for: .normal)
        button.addTarget(self, action: #selector(cancelTap(_:)), for: .touchUpInside)
        button.imageEdgeInsets = UIEdgeInsets(top: 5, left: 5, bottom: 5, right: 5)
        button.isHidden = true
        return button
    }()
    private lazy var separatorLine: UIView = {
        let view = UIView()
        view.backgroundColor = UIColor(red: 0.308, green: 0.308, blue: 0.308, alpha: 1)
        view.isHidden = true
        return view
    }()
    private lazy var nameLabel: UILabel = {
        let label = UILabel()
        label.text = UploadPostModel.shared.spotObject?.spotName ?? "Add spot"
        label.textColor = .white
        label.font = UIFont(name: "SFCompactText-Semibold", size: 15)
        label.lineBreakMode = .byTruncatingTail
        label.sizeToFit()
        return label
    }()

    var spotName: String? {
        didSet {
            nameLabel.text = spotName ?? "Add spot"
            if spotName != nil {
                separatorLine.isHidden = false
                separatorLine.snp.updateConstraints { $0.height.equalTo(21) }
                cancelButton.isHidden = false
                cancelButton.snp.updateConstraints { $0.height.width.equalTo(26) }
                nameLabel.snp.updateConstraints { $0.trailing.equalTo(separatorLine.snp.leading).offset(-8) }
            } else {
                separatorLine.isHidden = true
                separatorLine.snp.updateConstraints { $0.height.equalTo(1) }
                cancelButton.isHidden = true
                cancelButton.snp.updateConstraints { $0.height.width.equalTo(5) }
                nameLabel.snp.updateConstraints { $0.trailing.equalTo(separatorLine.snp.leading).offset(-3) }
            }
        }
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        translatesAutoresizingMaskIntoConstraints = false
        backgroundColor = UIColor.black.withAlphaComponent(0.5)
        layer.cornerRadius = 12
        layer.cornerCurve = .continuous

        addSubview(spotIcon)
        spotIcon.snp.makeConstraints {
            $0.leading.equalTo(11)
            $0.height.equalTo(21)
            $0.width.equalTo(17.6)
            $0.centerY.equalToSuperview()
        }

        addSubview(cancelButton)
        cancelButton.snp.makeConstraints {
            $0.trailing.equalToSuperview().inset(6)
            $0.height.width.equalTo(1)
            $0.centerY.equalToSuperview()
        }

        addSubview(separatorLine)
        separatorLine.snp.makeConstraints {
            $0.trailing.equalTo(cancelButton.snp.leading).offset(-3)
            $0.height.width.equalTo(1)
            $0.centerY.equalToSuperview()
        }

        addSubview(nameLabel)
        nameLabel.snp.makeConstraints {
            $0.leading.equalTo(spotIcon.snp.trailing).offset(6.5)
            $0.trailing.equalTo(separatorLine.snp.leading).offset(-3)
            $0.centerY.equalToSuperview()
        }
    }

    override func point(inside point: CGPoint, with _: UIEvent?) -> Bool {
        let margin: CGFloat = 7
        let area = self.bounds.insetBy(dx: -margin, dy: -margin)
        return area.contains(point)
    }
    // expand toucharea -> https://stackoverflow.com/questions/808503/uibutton-making-the-hit-area-larger-than-the-default-hit-area

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    @objc func cancelTap(_ sender: UIButton) {
        if let previewVC = viewContainingController() as? ImagePreviewController {
            previewVC.cancelSpotSelection()
        }
    }
}


