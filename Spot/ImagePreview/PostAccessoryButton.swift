//
//  PostAccessoryButton.swift
//  Spot
//
//  Created by Kenny Barone on 2/20/23.
//  Copyright © 2023 sp0t, LLC. All rights reserved.
//

import Foundation
import UIKit

protocol PostAccessoryDelegate: AnyObject {
    func cancelSpot()
    func cancelMap()
}

class PostAccessoryButton: UIButton {
    enum PostAccessoryType {
        case Spot
        case Map
    }
    var type: PostAccessoryType?

    private lazy var icon = UIImageView()

    private lazy var cancelButton: UIButton = {
        var configuration = UIButton.Configuration.plain()
        configuration.contentInsets = NSDirectionalEdgeInsets(top: 5, leading: 5, bottom: 5, trailing: 5)
        let button = UIButton(configuration: configuration)
        button.setImage(UIImage(named: "ChooseSpotCancel"), for: .normal)
        button.addTarget(self, action: #selector(cancelTap), for: .touchUpInside)
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
        label.textColor = .white
        label.font = UIFont(name: "SFCompactText-Semibold", size: 15)
        label.lineBreakMode = .byTruncatingTail
        label.sizeToFit()
        return label
    }()

    weak var delegate: PostAccessoryDelegate?

    var name: String? {
        didSet {
            setNameLabelText()
            if name != nil {
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

    init(type: PostAccessoryType, name: String?) {
        super.init(frame: .zero)
        self.type = type
        self.name = name

        translatesAutoresizingMaskIntoConstraints = false
        backgroundColor = UIColor(red: 0.129, green: 0.129, blue: 0.129, alpha: 0.65)
        layer.cornerRadius = 12
        layer.cornerCurve = .continuous

        icon.image = type == .Spot ? UIImage(named: "AddSpotIcon") : UIImage(named: "AddMapIcon")
        icon.contentMode = .scaleAspectFit
        icon.clipsToBounds = true

        addSubview(icon)
        icon.snp.makeConstraints {
            $0.leading.equalTo(11)
            $0.centerY.equalToSuperview()
        }

        addSubview(cancelButton)
        cancelButton.isHidden = true
        cancelButton.snp.makeConstraints {
            $0.trailing.equalToSuperview().inset(6)
            $0.height.width.equalTo(1)
            $0.centerY.equalToSuperview()
        }

        addSubview(separatorLine)
        separatorLine.isHidden = true
        separatorLine.snp.makeConstraints {
            $0.trailing.equalTo(cancelButton.snp.leading).offset(-3)
            $0.height.width.equalTo(1)
            $0.centerY.equalToSuperview()
        }

        setNameLabelText()
        addSubview(nameLabel)
        nameLabel.snp.makeConstraints {
            $0.leading.equalTo(icon.snp.trailing).offset(6.5)
            $0.trailing.equalTo(separatorLine.snp.leading).offset(-3)
            $0.centerY.equalToSuperview()
        }
    }

    private func setNameLabelText() {
        nameLabel.text = name ?? (type == .Spot ? "Tag spot" : "Add to map")
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
        if type == .Spot {
            delegate?.cancelSpot()
        } else {
            delegate?.cancelMap()
        }
    }
}
