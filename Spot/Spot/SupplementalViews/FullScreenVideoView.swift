//
//  FullScreenVideoView.swift
//  Spot
//
//  Created by Kenny Barone on 7/19/23.
//  Copyright © 2023 sp0t, LLC. All rights reserved.
//

import Foundation
import UIKit
import Mixpanel

class FullScreenVideoView: UIView {
    private lazy var maskBackground: UIView = {
        let view = UIView()
        view.backgroundColor = SpotColors.SpotBlack.color
        view.alpha = 0.0
        return view
    }()

    private lazy var exitButton: UIButton = {
        let button = UIButton(withInsets: NSDirectionalEdgeInsets(top: 10, leading: 10, bottom: 10, trailing: 10))
        button.setImage(UIImage(named: "WhiteCancelButton"), for: .normal)
        button.addTarget(self, action: #selector(exitTap), for: .touchUpInside)
        return button
    }()

    private lazy var thumbnailView: UIImageView = {
        let image = UIImageView()
        image.contentMode = .scaleAspectFit
        return image
    }()

    private lazy var playerView = PlayerView(videoGravity: .resizeAspect)
    private lazy var activityIndicator = UIActivityIndicatorView(style: .large)

    var swipingToExit = false

    init(thumbnailImage: UIImage, urlString: String, initialFrame: CGRect) {
        super.init(frame: .zero)

        Mixpanel.mainInstance().track(event: "VideoPreviewAppeared")

        addSubview(maskBackground)
        maskBackground.snp.makeConstraints {
            $0.edges.equalToSuperview()
        }

        if let url = URL(string: urlString) {
            let player = AVPlayer(url: url)
            playerView.player = player
            maskBackground.addSubview(playerView)
            playerView.snp.makeConstraints {
                $0.leading.equalTo(initialFrame.minX)
                $0.top.equalTo(initialFrame.minY)
                $0.width.equalTo(initialFrame.width)
                $0.height.equalTo(initialFrame.height)
            }
            playerView.addGestureRecognizer(UIPanGestureRecognizer(target: self, action: #selector(swipeToClose)))
        }

        maskBackground.addSubview(thumbnailView)
        thumbnailView.image = thumbnailImage
        thumbnailView.snp.makeConstraints {
            $0.edges.equalTo(playerView)
        }

        let minStatusHeight: CGFloat = UserDataModel.shared.screenSize == 2 ? 54 : UserDataModel.shared.screenSize == 1 ? 47 : 20
        let statusHeight = max(window?.windowScene?.statusBarManager?.statusBarFrame.height ?? 20.0, minStatusHeight)

        maskBackground.addSubview(exitButton)
        exitButton.isHidden = true
        exitButton.snp.makeConstraints {
            $0.leading.equalToSuperview().offset(6)
            $0.top.equalToSuperview().offset(statusHeight + 20)
            $0.width.height.equalTo(45)
        }

        maskBackground.addSubview(activityIndicator)
        activityIndicator.startAnimating()
        activityIndicator.snp.makeConstraints {
            $0.centerX.centerY.equalTo(playerView)
        }

        NotificationCenter.default.addObserver(forName: .AVPlayerItemDidPlayToEndTime, object: playerView.player?.currentItem, queue: nil) { [weak self] _ in
            self?.playerView.player?.seek(to: CMTime.zero)
            self?.playerView.player?.play()
        }

        NotificationCenter.default.addObserver(self, selector: #selector(enteredForeground), name: UIApplication.willEnterForegroundNotification, object: nil)
        playerView.player?.addObserver(self, forKeyPath: "timeControlStatus", options: [.old, .new], context: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        playerView.player?.removeObserver(self, forKeyPath: "timeControlStatus")
        playerView.player?.pause()
        playerView.player = nil
        thumbnailView.image = nil
        NotificationCenter.default.removeObserver(self)
    }

    @objc func exitTap() {
        Mixpanel.mainInstance().track(event: "VideoPreivewTapToExit")
        animateOffscreen()
    }

    func expand() {
        layoutIfNeeded()
        playerView.snp.removeConstraints()
        playerView.snp.makeConstraints {
            $0.edges.equalToSuperview()
        }
        UIView.animate(withDuration: 0.2, animations: {
            self.layoutIfNeeded()
            self.maskBackground.alpha = 1.0
        }) { [weak self] _ in
            self?.exitButton.isHidden = false
        }
    }

    @objc func swipeToClose(_ gesture: UIPanGestureRecognizer) {
        let translation = gesture.translation(in: self)
        let velocity = gesture.velocity(in: self)

        if translation.y > 0 || swipingToExit {
            switch gesture.state {
            case .began:
                swipingToExit = true
            case .changed:
                maskBackground.transform = CGAffineTransform(translationX: 0, y: translation.y)
            case .ended, .cancelled, .failed:
                let composite = translation.y + velocity.y / 3
                if composite > bounds.height / 2 {
                    Mixpanel.mainInstance().track(event: "VideoPreviewSwipeToExit")
                    self.animateOffscreen()
                } else {
                    self.resetConstraints()
                }
            default:
                return
            }
        }
    }

    private func animateOffscreen() {
        maskBackground.snp.removeConstraints()
        maskBackground.snp.makeConstraints {
            $0.leading.trailing.height.equalToSuperview()
            $0.top.equalTo(self.snp.bottom)
        }
        UIView.animate(withDuration: 0.2, animations: {
            self.layoutIfNeeded()
            self.maskBackground.alpha = 0.0
        }) { [weak self] _ in
            self?.removeFromSuperview()
        }
    }

    private func resetConstraints() {
        UIView.animate(withDuration: 0.2) {
            self.maskBackground.transform = CGAffineTransform(translationX: 0, y: 0)
        }
    }

    override public func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        if keyPath == "timeControlStatus", let change = change, let newValue = change[NSKeyValueChangeKey.newKey] as? Int, let oldValue = change[NSKeyValueChangeKey.oldKey] as? Int {
            let oldStatus = AVPlayer.TimeControlStatus(rawValue: oldValue)
            let newStatus = AVPlayer.TimeControlStatus(rawValue: newValue)
            if newStatus != oldStatus {
                DispatchQueue.main.async {[weak self] in
                    if newStatus == .playing || newStatus == .paused {
                        self?.activityIndicator.stopAnimating()
                        self?.thumbnailView.isHidden = true
                    } else {
                        self?.activityIndicator.startAnimating()
                    }
                }
            }
        }
    }
    // src: https://stackoverflow.com/questions/42743343/avplayer-show-and-hide-loading-indicator-when-buffering


    @objc func enteredForeground() {
        DispatchQueue.main.async {
            self.playerView.player?.play()
        }
    }
}
