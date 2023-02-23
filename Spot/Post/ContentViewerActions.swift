//
//  ContentViewerActions.swift
//  Spot
//
//  Created by Kenny Barone on 1/31/23.
//  Copyright © 2023 sp0t, LLC. All rights reserved.
//

import Foundation
import UIKit
import Mixpanel

extension ContentViewerCell {
    @objc func likeTap() {
        delegate?.likePost(postID: post?.id ?? "")
    }

    @objc func commentsTap() {
        Mixpanel.mainInstance().track(event: "PostPageOpenCommentsFromButton")
        delegate?.openPostComments()
    }

    @objc func moreTap() {
        delegate?.openPostActionSheet()
    }

    @objc func captionTap(_ sender: UITapGestureRecognizer) {
        if tapInTagRect(sender: sender) {
            /// profile open handled on function call
            return
        } else if moreShowing {
            Mixpanel.mainInstance().track(event: "PostPageExpandCaption")
            expandCaption()
        } else {
            Mixpanel.mainInstance().track(event: "PostPageOpenCommentsFromCaption")
            delegate?.openPostComments()
        }
    }

    @objc func userTap() {
        if let user = post?.userInfo {
            delegate?.openProfile(user: user)
        }
    }

    @objc func spotTap() {
        if let post = post {
            delegate?.openSpot(post: post)
        }
    }

    @objc func mapTap() {
        if let mapID = post?.mapID, let mapName = post?.mapName {
            delegate?.openMap(mapID: mapID, mapName: mapName)
        }
    }

    func tapInTagRect(sender: UITapGestureRecognizer) -> Bool {
        for r in tagRect {
            let expandedRect = CGRect(x: r.rect.minX - 3, y: r.rect.minY, width: r.rect.width + 6, height: r.rect.height + 3)
            if expandedRect.contains(sender.location(in: sender.view)) {
                Mixpanel.mainInstance().track(event: "PostPageOpenTaggedUserProfile")
                // open tag from friends list
                if let user = UserDataModel.shared.userInfo.friendsList.first(where: { $0.username == r.username }) {
                    delegate?.openProfile(user: user)
                    return true
                } else {
                    // pass blank user object to open func, run get user func on profile load
                    let user = UserProfile(currentLocation: "", imageURL: "", name: "", userBio: "", username: r.username)
                    delegate?.openProfile(user: user)
                }
            }
        }
        return false
    }

    func expandCaption() {
        moreShowing = false
        captionLabel.numberOfLines = 0
        captionLabel.snp.updateConstraints { $0.height.lessThanOrEqualTo(300) }
        captionLabel.attributedText = NSAttributedString(string: post?.caption ?? "")
        addCaptionAttString()
    }

    func animateLocation() {
        if locationView.bounds.width == 0 { return }
        if delegate?.getSelectedPostIndex() == self.globalRow && locationView.contentSize.width > locationView.bounds.width {
            DispatchQueue.main.async { self.locationView.startAnimating() }
        }
    }

    public func stopLocationAnimation() {
        locationView.stopAnimating()
    }

    @objc func imageTap(_ gesture: UITapGestureRecognizer) {
        let position = gesture.location(in: contentView)
        if position.x < 75 {
            if post?.selectedImageIndex ?? 0 > 0 {
                goPreviousImage()
            } else {
                delegate?.tapToPreviousPost()
            }
        } else if position.x > (gesture.view?.bounds.width ?? 0) - 75 {
            if post?.selectedImageIndex ?? 0 < (post?.frameIndexes?.count ?? 0) - 1 {
                goNextImage()
            } else {
                delegate?.tapToNextPost()
            }
        }
    }

    @objc func imageSwipe(_ gesture: UIPanGestureRecognizer) {
        let velocity = gesture.velocity(in: gesture.view)
        let translation = gesture.translation(in: gesture.view)
        let composite = translation.x + velocity.x / 4
        let selectedIndex = post?.selectedImageIndex ?? 0
        let imageCount = post?.frameIndexes?.count ?? 0

        switch gesture.state {
        case.began:
            if cellOffset || imageSwiping { return }
            if abs(velocity.x) > abs(velocity.y) {
                imageSwiping = true
            }

        case .changed:
            if !imageSwiping { return }
            let adjustedOffset: CGFloat =
            post?.selectedImageIndex ?? 0 == 0 ? min(0, translation.x) :
            post?.selectedImageIndex ?? 0 == (post?.frameIndexes?.count ?? 0) - 1 ? max(0, translation.x) :
            translation.x

            if currentImage.superview != nil { currentImage.snp.updateConstraints({ $0.leading.trailing.equalToSuperview().offset(adjustedOffset) }) }
            if nextImage.superview != nil { nextImage.snp.updateConstraints({ $0.leading.trailing.equalToSuperview().offset(UIScreen.main.bounds.width + adjustedOffset) }) }
            if previousImage.superview != nil { previousImage.snp.updateConstraints({ $0.leading.trailing.equalToSuperview().offset(-UIScreen.main.bounds.width + adjustedOffset) }) }

        case .ended:
            if (composite < -UIScreen.main.bounds.width / 2) && (selectedIndex < imageCount - 1) {
                self.animateToNextImage()
            } else if (composite > UIScreen.main.bounds.width / 2) && (selectedIndex > 0) {
                self.animateToPreviousImage()
            } else {
                self.resetImageFrame()
            }
            imageSwiping = false

        default: return
        }
    }

    private func goNextImage() {
        Mixpanel.mainInstance().track(event: "ContentCellNextImage")
        var selectedIndex = post?.selectedImageIndex ?? 0
        selectedIndex += 1
        post?.selectedImageIndex = selectedIndex
        setImages()

        NotificationCenter.default.post(Notification(name: Notification.Name("PostImageChange"), object: nil, userInfo: ["index": selectedIndex as Any]))
    }

    private func goPreviousImage() {
        Mixpanel.mainInstance().track(event: "ContentCellPreviousImage")
        var selectedIndex = post?.selectedImageIndex ?? 0
        selectedIndex -= 1
        post?.selectedImageIndex = selectedIndex
        setImages()

        NotificationCenter.default.post(Notification(name: Notification.Name("PostImageChange"), object: nil, userInfo: ["index": selectedIndex as Any]))
    }

    private func animateToNextImage() {
        Mixpanel.mainInstance().track(event: "ContentCellSwipeToNextImage")
        currentImage.snp.updateConstraints { $0.leading.trailing.equalToSuperview().offset(-UIScreen.main.bounds.width) }
        nextImage.snp.updateConstraints { $0.leading.trailing.equalToSuperview() }

        UIView.animate(withDuration: 0.2) { [weak self] in
            self?.contentView.layoutIfNeeded()

        } completion: { [weak self] _ in
            if self?.post != nil {
                self?.goNextImage()
            }
        }
    }

    private func animateToPreviousImage() {
        Mixpanel.mainInstance().track(event: "ContentCellSwipeToPreviousImage")
        currentImage.snp.updateConstraints { $0.leading.trailing.equalToSuperview().offset(UIScreen.main.bounds.width) }
        previousImage.snp.updateConstraints { $0.leading.trailing.equalToSuperview() }

        UIView.animate(withDuration: 0.2) { [weak self] in
            self?.contentView.layoutIfNeeded()

        } completion: { [weak self] _ in
            if self?.post != nil {
                self?.goPreviousImage()
            }
        }
    }

    private func resetImageFrame() {
        if currentImage.superview != nil { currentImage.snp.updateConstraints { $0.leading.trailing.equalToSuperview() } }
        if previousImage.superview != nil { previousImage.snp.updateConstraints { $0.leading.trailing.equalToSuperview().offset(-UIScreen.main.bounds.width) } }
        if nextImage.superview != nil { nextImage.snp.updateConstraints {
            $0.leading.trailing.equalToSuperview().offset(UIScreen.main.bounds.width )
        } }
        UIView.animate(withDuration: 0.2) {
            self.contentView.layoutIfNeeded()
        }
    }

    override func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        return true
    }
}
