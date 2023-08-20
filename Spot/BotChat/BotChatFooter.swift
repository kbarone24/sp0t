//
//  BotChatFooter.swift
//  Spot
//
//  Created by Kenny Barone on 8/19/23.
//  Copyright © 2023 sp0t, LLC. All rights reserved.
//

import Foundation
import UIKit
import FirebaseStorageUI
import Mixpanel

protocol BotFooterDelegate: AnyObject {
    func uploadChat(text: String)
    func togglePanGesture(enable: Bool)
}

class BotChatFooter: UIView {
    private(set) lazy var avatarImage: UIImageView = {
        let view = UIImageView()
        view.contentMode = .scaleAspectFill
        return view
    }()

    private(set) lazy var postButton: UIButton = {
        var configuration = UIButton.Configuration.plain()
        configuration.contentInsets = NSDirectionalEdgeInsets(top: 5, leading: 5, bottom: 5, trailing: 5)
        let button = UIButton(configuration: configuration)
        button.setImage(UIImage(named: "PostCommentButton"), for: .normal)
        button.addTarget(self, action: #selector(sendTap), for: .touchUpInside)
        button.isEnabled = false
        return button
    }()

    private(set) lazy var textView: UITextView = {
        let textView = UITextView()
        textView.delegate = self
        textView.backgroundColor = UIColor(red: 0.937, green: 0.937, blue: 0.937, alpha: 1)
        textView.textColor = SpotColors.SpotBlack.color.withAlphaComponent(0.5)
        textView.font = SpotFonts.SFCompactRoundedSemibold.fontWith(size: 17)
        textView.text = emptyTextString
        textView.textContainerInset = UIEdgeInsets(top: 11, left: 12, bottom: 11, right: 60)
        textView.isScrollEnabled = false
        textView.returnKeyType = .send
        textView.textContainer.maximumNumberOfLines = 6
        textView.textContainer.lineBreakMode = .byTruncatingHead
        textView.delegate = self
        textView.layer.cornerRadius = 11
        return textView
    }()

    weak var delegate: BotFooterDelegate?
    let emptyTextString = "sup..."

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = UIColor(red: 0.979, green: 0.979, blue: 0.979, alpha: 1)

        avatarImage.image = UserDataModel.shared.userInfo.getAvatarImage()
        addSubview(avatarImage)
        avatarImage.snp.makeConstraints {
            $0.leading.equalTo(13)
            $0.width.equalTo(36)
            $0.height.equalTo(40.5)
            $0.bottom.equalToSuperview().inset(15)
        }

        addSubview(textView)
        textView.snp.makeConstraints {
            $0.leading.equalTo(avatarImage.snp.trailing).offset(6)
            $0.trailing.equalToSuperview().inset(17)
            $0.top.equalToSuperview().inset(10)
            $0.bottom.equalToSuperview().inset(12)
        }

        addSubview(postButton)
        postButton.isEnabled = false
        postButton.snp.makeConstraints {
            $0.trailing.equalTo(textView.snp.trailing).inset(7)
            $0.width.height.equalTo(32)
            $0.bottom.equalTo(textView).offset(-4)
        }
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }


    @objc private func sendTap() {
        sendChat()
    }

    private func sendChat() {
        guard var chatText = textView.text, chatText != emptyTextString else { return }
        while chatText.last?.isNewline ?? false {
            chatText = String(chatText.dropLast())
        }
        guard chatText.replacingOccurrences(of: " ", with: "") != "" else { return }

        Mixpanel.mainInstance().track(event: "BotChatSent")
        delegate?.uploadChat(text: chatText)

        resetTextView()
    }

    func resetTextView() {
        textView.text = ""
        textView.resignFirstResponder()
    }
}
extension BotChatFooter: UITextViewDelegate {
    func textViewDidBeginEditing(_ textView: UITextView) {
        if textView.text == emptyTextString {
            textView.text = ""
        }
        delegate?.togglePanGesture(enable: true)
    }

    func textViewDidEndEditing(_ textView: UITextView) {
        if textView.text.isEmpty {
            textView.textColor = SpotColors.SpotBlack.color.withAlphaComponent(0.5)
            textView.text = emptyTextString
        }
        delegate?.togglePanGesture(enable: false)
    }

    func textViewDidChange(_ textView: UITextView) {
        let trimText = textView.text.trimmingCharacters(in: .whitespacesAndNewlines)
        self.postButton.isEnabled = trimText != ""
        if trimText.isEmpty {
            textView.textColor = SpotColors.SpotBlack.color.withAlphaComponent(0.5)
        } else {
            textView.textColor = SpotColors.SpotBlack.color.withAlphaComponent(1.0)
        }
    }

    func textView(_ textView: UITextView, shouldChangeTextIn range: NSRange, replacementText text: String) -> Bool {
        // send button tap
        if text == "\n" { sendChat(); return false }
        return textView.shouldChangeText(range: range, replacementText: text, maxChar: 300)
    }
}
