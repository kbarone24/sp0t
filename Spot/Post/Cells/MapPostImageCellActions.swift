//
//  MapPostImageCellActions.swift
//  Spot
//
//  Created by Kenny Barone on 1/31/23.
//  Copyright © 2023 sp0t, LLC. All rights reserved.
//

import Foundation
import UIKit
import Mixpanel

extension MapPostImageCell {
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
            DispatchQueue.main.async {
                self.locationView.startAnimating()
            }
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

    private func goNextImage() {
        Mixpanel.mainInstance().track(event: "ContentCellNextImage")
        var selectedIndex = post?.selectedImageIndex ?? 0
        selectedIndex += 1
        post?.selectedImageIndex = selectedIndex
        addDots()

        NotificationCenter.default.post(Notification(name: Notification.Name("PostImageChange"), object: nil, userInfo: ["index": selectedIndex as Any]))
    }

    private func goPreviousImage() {
        Mixpanel.mainInstance().track(event: "ContentCellPreviousImage")
        var selectedIndex = post?.selectedImageIndex ?? 0
        selectedIndex -= 1
        post?.selectedImageIndex = selectedIndex
        addDots()

        NotificationCenter.default.post(Notification(name: Notification.Name("PostImageChange"), object: nil, userInfo: ["index": selectedIndex as Any]))
    }

    private func animateToNextImage() {
        Mixpanel.mainInstance().track(event: "ContentCellSwipeToNextImage")

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

        UIView.animate(withDuration: 0.2) { [weak self] in
            self?.contentView.layoutIfNeeded()

        } completion: { [weak self] _ in
            if self?.post != nil {
                self?.goPreviousImage()
            }
        }
    }

    private func resetImageFrame() {
        UIView.animate(withDuration: 0.2) { [weak self] in
            self?.contentView.layoutIfNeeded()
        }
    }
}
