//
//  NewSpotNameView.swift
//  Spot
//
//  Created by Kenny Barone on 11/2/22.
//  Copyright © 2022 sp0t, LLC. All rights reserved.
//

import Foundation
import UIKit

class NewSpotNameView: UIView {
    lazy var textView: UITextView = {
        let view = UITextView()
        view.backgroundColor = UIColor.black.withAlphaComponent(0.7)
        view.font = UIFont(name: "SFCompactText-Medium", size: 16.5)
        view.tintColor = .white
        view.textColor = UIColor.white
        view.text = ""
        view.textContainerInset = UIEdgeInsets(top: 9, left: 40, bottom: 9, right: 9)
        view.textContainer.lineBreakMode = .byTruncatingHead
        view.delegate = self
        view.layer.cornerRadius = 13
        view.returnKeyType = .done
        return view
    }()
    private lazy var spotIcon = UIImageView(image: UIImage(named: "AddSpotIcon"))
    private lazy var createButton: UIButton = {
        let button = UIButton()
        button.backgroundColor = UIColor(named: "SpotGreen")
        button.layer.cornerRadius = 16
        button.setTitle("Create spot", for: .normal)
        button.setTitleColor(.black, for: .normal)
        button.titleLabel?.font = UIFont(name: "SFCompactText-Semibold", size: 16.5)
        button.addTarget(self, action: #selector(createTap), for: .touchUpInside)
        return button
    }()

    var spotName: String {
        textView.text
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        translatesAutoresizingMaskIntoConstraints = false

        textView.delegate = self
        addSubview(textView)
        textView.snp.makeConstraints {
            $0.leading.trailing.equalToSuperview().inset(60)
            $0.top.equalToSuperview()
            $0.height.equalTo(40)
        }

        textView.addSubview(spotIcon)
        spotIcon.snp.makeConstraints {
            $0.leading.equalTo(15)
            $0.centerY.equalToSuperview()
            $0.width.equalTo(19.3)
            $0.height.equalTo(23)
        }

        addSubview(createButton)
        createButton.snp.makeConstraints {
            $0.top.equalTo(textView.snp.bottom).offset(25)
            $0.width.equalTo(160)
            $0.height.equalTo(41)
            $0.centerX.equalToSuperview()
        }
    }
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    @objc func createTap() {
        textView.endEditing(true)
    }
}

extension NewSpotNameView: UITextViewDelegate {
    func textViewDidBeginEditing(_ textView: UITextView) {
        textView.isUserInteractionEnabled = true
    }

    func textViewDidEndEditing(_ textView: UITextView) {
        textView.isUserInteractionEnabled = false
    }

    func textView(_ textView: UITextView, shouldChangeTextIn range: NSRange, replacementText text: String) -> Bool {
        if text == "\n" { textView.endEditing(true); return false }
        return text.count < 50
    }
}
