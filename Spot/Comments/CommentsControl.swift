//
//  CommentsControl.swift
//  Spot
//
//  Created by Oforkanji Odekpe on 12/24/22.
//  Copyright © 2022 sp0t, LLC. All rights reserved.
//

import UIKit
import Mixpanel

final class CommentsControl: UITableViewHeaderFooterView {
    var buttonBar: UIView!
    var commentSeg: CommentSeg!
    var likeSeg: LikeSeg!

    var selectedIndex: Int = 0 {
        didSet {
            commentSeg.index = selectedIndex
            likeSeg.index = selectedIndex
            setBarConstraints()
        }
    }

    override init(reuseIdentifier: String?) {
        super.init(reuseIdentifier: reuseIdentifier)
        isUserInteractionEnabled = true
        let backgroundView = UIView()
        backgroundView.backgroundColor = .white
        self.backgroundView = backgroundView

        setUp()
    }

    func setUp() {
        let segWidth: CGFloat = 125
        if commentSeg != nil { return }

        commentSeg = CommentSeg {
            $0.addTarget(self, action: #selector(commentSegTap(_:)), for: .touchUpInside)
            addSubview($0)
        }
        commentSeg.snp.makeConstraints {
            $0.bottom.equalToSuperview().offset(-3.5)
            $0.trailing.equalTo(snp.centerX).offset(-5)
            $0.width.equalTo(segWidth)
        }

        likeSeg = LikeSeg {
            $0.addTarget(self, action: #selector(likeSegTap(_:)), for: .touchUpInside)
            addSubview($0)
        }
        likeSeg.snp.makeConstraints {
            $0.bottom.equalToSuperview().offset(-3.5)
            $0.leading.equalTo(snp.centerX).offset(5)
            $0.width.equalTo(segWidth)
        }

        buttonBar = UIView {
            $0.backgroundColor = .black
            $0.layer.cornerRadius = 1
            addSubview($0)
        }
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    @objc func commentSegTap(_ sender: UIButton) {
        Mixpanel.mainInstance().track(event: "CommentsCommentsSegTap")
        if selectedIndex == 1 {
            switchToCommentSeg()
        }
    }

    @objc func likeSegTap(_ sender: UIButton) {
        Mixpanel.mainInstance().track(event: "CommentsLikeSegTap")
        if selectedIndex == 0 {
            switchToLikeSeg()
            guard let commentsVC = viewContainingController() as? CommentsController else { return }
            commentsVC.textView.resignFirstResponder()
        }
    }

    func switchToLikeSeg() {
        guard let commentsVC = viewContainingController() as? CommentsController else { return }
        commentsVC.selectedIndex = 1
        commentsVC.tableView.reloadData()
        commentsVC.footerView.isHidden = true
    }

    func switchToCommentSeg() {
        guard let commentsVC = viewContainingController() as? CommentsController else { return }
        commentsVC.selectedIndex = 0
        commentsVC.tableView.reloadData()
        commentsVC.footerView.isHidden = false
        commentsVC.footerView.becomeFirstResponder()
    }

    func setBarConstraints() {
        buttonBar.snp.removeConstraints()
        let selectedButton = selectedIndex == 0 ? commentSeg : likeSeg
        buttonBar.snp.makeConstraints {
            $0.leading.equalTo(selectedButton!.snp.leading)
            $0.top.equalTo(selectedButton!.snp.bottom)
            $0.width.equalTo(selectedButton!.snp.width)
            $0.height.equalTo(3.5)
        }
    }

    func animateSegmentSwitch() {
        let selectedButton = selectedIndex == 0 ? commentSeg : likeSeg
        UIView.animate(withDuration: 0.2) {
            self.buttonBar.snp.updateConstraints {
                $0.leading.equalTo(selectedButton!.snp.leading)
            }
            self.buttonBar.layoutIfNeeded()
        }
    }
}
