//
//  PlayerView.swift
//  Spot
//
//  Created by Oforkanji Odekpe on 3/11/23.
//  Copyright © 2023 sp0t, LLC. All rights reserved.
//

import UIKit
import AVFoundation

final class PlayerView: UIView {
    private let videoGravity: AVLayerVideoGravity
    var player: AVPlayer? {
        get {
            return playerLayer?.player
        }
        set {
            playerLayer?.videoGravity = videoGravity
            playerLayer?.player = newValue
            player?.play()
        }
    }

    var playerLayer: AVPlayerLayer? {
        return layer as? AVPlayerLayer
    }

    override static var layerClass: AnyClass {
        return AVPlayerLayer.self
    }

    init(videoGravity: AVLayerVideoGravity) {
        self.videoGravity = videoGravity
        super.init(frame: .zero)
        isUserInteractionEnabled = true
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
