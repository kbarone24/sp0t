//
//  VideoEditorController.swift
//  Spot
//
//  Created by Kenny Barone on 4/4/23.
//  Copyright © 2023 sp0t, LLC. All rights reserved.
//

import Foundation
import UIKit
import Photos
import PryntTrimmerView
import Mixpanel

protocol VideoEditorDelegate: AnyObject {
    func finishPassing(videoObject: VideoObject)
}

class VideoEditorController: UIViewController {
    private var player: AVPlayer?
    private var sourceVideoURL: URL?
    private let videoAsset: PHAsset

    private lazy var bottomMask: UIView = {
        let view = UIView()
        view.backgroundColor = UIColor(red: 0.075, green: 0.075, blue: 0.075, alpha: 0.75)
        return view
    }()

    private lazy var topMask: UIView = {
        let view = UIView()
        view.backgroundColor = UIColor(red: 0.075, green: 0.075, blue: 0.075, alpha: 0.75)
        return view
    }()

    private lazy var playerView = PlayerView(videoGravity: .resizeAspect)

    private lazy var trimmerView: TrimmerView = {
        let trimmerView = TrimmerView()
        trimmerView.delegate = self
        trimmerView.positionBarColor = .white
        trimmerView.handleColor = .white
        trimmerView.mainColor = UIColor(hexString: "2d2d2d")
        trimmerView.maxDuration = 15
        trimmerView.minDuration = 0.5
        return trimmerView
    }()

    let symbolConfig = UIImage.SymbolConfiguration(pointSize: 26, weight: .regular)
    let buttonConfig: UIButton.Configuration = {
        var config = UIButton.Configuration.plain()
        config.contentInsets = NSDirectionalEdgeInsets(top: 5, leading: 5, bottom: 5, trailing: 5)
        return config
    }()
    private lazy var playButton: UIButton = {
        let button = UIButton(configuration: buttonConfig)
        button.setImage(UIImage(systemName: "play.fill", withConfiguration: symbolConfig), for: .normal)
        button.imageView?.tintColor = .white
        button.contentHorizontalAlignment = .fill
        button.contentVerticalAlignment = .fill
        button.addTarget(self, action: #selector(playTap), for: .touchUpInside)
        return button
    }()
    private lazy var pauseButton: UIButton = {
        let button = UIButton(configuration: buttonConfig)
        button.setImage(UIImage(systemName: "pause.fill", withConfiguration: symbolConfig), for: .normal)
        button.imageView?.tintColor = .white
        button.contentHorizontalAlignment = .fill
        button.contentVerticalAlignment = .fill
        button.addTarget(self, action: #selector(pauseTap), for: .touchUpInside)
        return button
    }()

    lazy var useButton: UIButton = {
        let button = UIButton()
        button.setTitle("Use Video", for: .normal)
        button.setTitleColor(.white, for: .normal)
        button.titleLabel?.font = SpotFonts.SFCompactRoundedRegular.fontWith(size: 18)
        button.addTarget(self, action: #selector(useVideoTap), for: .touchUpInside)
        return button
    }()

    lazy var cancelButton: UIButton = {
        let button = UIButton()
        button.setTitle("Cancel", for: .normal)
        button.setTitleColor(UIColor(red: 0.954, green: 0.954, blue: 0.954, alpha: 1), for: .normal)
        button.titleLabel?.font = SpotFonts.SFCompactRoundedRegular.fontWith(size: 18)
        button.addTarget(self, action: #selector(cancelTap), for: .touchUpInside)
        return button
    }()

    private(set) lazy var activityIndicator: UIActivityIndicatorView = {
        let view = UIActivityIndicatorView(style: .large)
        view.color = .white
        return view
    }()

    weak var delegate: VideoEditorDelegate?

    let options: PHVideoRequestOptions = {
        let options = PHVideoRequestOptions()
        options.deliveryMode = .highQualityFormat
        options.isNetworkAccessAllowed = true
        return options
    }()

    var playbackTimeCheckerTimer: Timer?
    var trimmerPositionChangedTimer: Timer?

    init(videoAsset: PHAsset) {
        self.videoAsset = videoAsset
        super.init(nibName: nil, bundle: nil)
        view.backgroundColor = UIColor(named: "SpotBlack")

        view.addSubview(playerView)
        playerView.snp.makeConstraints {
            $0.edges.equalToSuperview()
        }

        view.addSubview(topMask)
        topMask.snp.makeConstraints {
            $0.leading.top.trailing.equalToSuperview()
            $0.height.equalTo(UserDataModel.shared.statusHeight + 45)
        }

        topMask.addSubview(trimmerView)
        trimmerView.snp.makeConstraints {
            $0.leading.trailing.equalToSuperview().inset(14)
            $0.bottom.equalToSuperview().offset(-5)
            $0.height.equalTo(40)
        }

        view.addSubview(bottomMask)
        bottomMask.snp.makeConstraints {
            $0.leading.trailing.bottom.equalToSuperview()
            $0.height.equalTo(100)
        }

        bottomMask.addSubview(playButton)
        playButton.tintColor = .white
        playButton.snp.makeConstraints {
            $0.top.equalTo(10)
            $0.centerX.equalToSuperview()
            $0.height.width.equalTo(50)
        }

        bottomMask.addSubview(pauseButton)
        pauseButton.tintColor = .white
        pauseButton.isHidden = true
        pauseButton.snp.makeConstraints {
            $0.edges.equalTo(playButton)
        }

        bottomMask.addSubview(cancelButton)
        cancelButton.snp.makeConstraints {
            $0.leading.equalTo(14)
            $0.top.equalTo(20)
        }

        bottomMask.addSubview(useButton)
        useButton.snp.makeConstraints {
            $0.trailing.equalTo(-14)
            $0.top.equalTo(cancelButton)
        }

        view.addSubview(activityIndicator)
        activityIndicator.snp.makeConstraints {
            $0.centerX.equalToSuperview()
            $0.bottom.equalTo(bottomMask.snp.top).offset(-20)
        }
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.layoutIfNeeded()
        addPreviewVideo()
        edgesForExtendedLayout = []
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setNavigationBarHidden(true, animated: true)
    }

    override func viewDidAppear(_ animated: Bool) {
        // configure separate audio session here -> play and record wasn't allowing for headphone playback
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .default, options: [.mixWithOthers, .duckOthers])
        try? AVAudioSession.sharedInstance().setActive(true)

        if player?.timeControlStatus == .paused {
            playVideo()
        }
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        pauseVideo()
        NotificationCenter.default.removeObserver(self)
    }

    private func addPreviewVideo() {
        PHCachingImageManager().requestPlayerItem(forVideo: videoAsset, options: options) { [weak self] (playerItem, info) in
            guard let self else { return }
            self.player = AVPlayer(playerItem: playerItem)
            self.player?.currentItem?.preferredForwardBufferDuration = 1.0
            let playerLayer = AVPlayerLayer(player: player)
            playerLayer.frame = playerView.bounds
            playerLayer.videoGravity = .resizeAspectFill
            self.playerView.layer.addSublayer(playerLayer)

            self.trimmerView.asset = playerItem?.asset
            if let url = (playerItem?.asset as? AVURLAsset)?.url {
                self.sourceVideoURL = url
            }
            self.playVideo()
        }
    }

    @objc func playTap() {
        playVideo()
        Mixpanel.mainInstance().track(event: "VideoEditorPlayTap")
    }

    @objc func cancelTap() {
        DispatchQueue.main.async {
            self.navigationController?.popViewController(animated: false)
        }
    }

    @objc func useVideoTap() {
        useButton.isEnabled = false
        useButton.alpha = 0.7
        pauseVideo()

        view.bringSubviewToFront(activityIndicator)
        activityIndicator.startAnimating()
        Mixpanel.mainInstance().track(event: "VideoEditorNextTap")

        // trim and export video
        exportVideo { [weak self] exportURL, errorMessage in
            guard let exportURL, let videoData = try? Data(contentsOf: exportURL, options: .mappedIfSafe), let self
            else {
                self?.showError(message: errorMessage ?? "")
                return
            }
            // create new video object from trimmed and compressed video
            let thumbnailImage = exportURL.getThumbnail()
            let coordinate = videoAsset.location?.coordinate ?? UserDataModel.shared.currentLocation.coordinate
            let video = VideoObject(
                id: UUID().uuidString,
                asset: PHAsset(),
                thumbnailImage: thumbnailImage,
                videoData: videoData,
                videoPath: exportURL,
                coordinate: coordinate,
                creationDate: Date(),
                fromCamera: false
            )
            self.delegate?.finishPassing(videoObject: video)

            self.activityIndicator.stopAnimating()
            self.useButton.isEnabled = true
            self.useButton.alpha = 1.0
            self.navigationController?.popViewController(animated: false)
        }
    }

    private func playVideo() {
        Mixpanel.mainInstance().track(event: "VideoEditorPlayTap")

        player?.play()
        addEndObserver()
        playButton.isHidden = true
        pauseButton.isHidden = false
        startPlaybackTimeChecker()
    }

    @objc func pauseTap() {
        Mixpanel.mainInstance().track(event: "VideoEditorPauseTap")

        pauseVideo()
    }

    private func pauseVideo() {
        player?.pause()
        removeEndObserver()
        playButton.isHidden = false
        pauseButton.isHidden = true
        stopPlaybackTimeChecker()
    }

    private func addEndObserver() {
        NotificationCenter.default.addObserver(forName: .AVPlayerItemDidPlayToEndTime, object: player?.currentItem, queue: nil) { [weak self] _ in
            if let startTime = self?.trimmerView.startTime {
                self?.player?.seek(to: startTime)
                if (self?.player?.status == .readyToPlay) {
                    self?.player?.play()
                }
            }
        }
    }

    private func removeEndObserver() {
        NotificationCenter.default.removeObserver(self)
    }

    func showError(message: String) {
        Mixpanel.mainInstance().track(event: "VideoEditorError")

        let alert = UIAlertController(
            title: "Something went wrong",
            message: message,
            preferredStyle: .alert
        )

        alert.addAction(
            UIAlertAction(title: "OK", style: .default)
        )
        present(alert, animated: true, completion: nil)

        activityIndicator.stopAnimating()
        useButton.isEnabled = true
    }
}

extension VideoEditorController: TrimmerViewDelegate {
    func didChangePositionBar(_ playerTime: CMTime) {
        stopPlaybackTimeChecker()
        pauseVideo()
        player?.seek(to: playerTime, toleranceBefore: CMTime.zero, toleranceAfter: CMTime.zero)
    }

    func positionBarStoppedMoving(_ playerTime: CMTime) {
        player?.seek(to: playerTime, toleranceBefore: CMTime.zero, toleranceAfter: CMTime.zero)
        playVideo()
    }

    func startPlaybackTimeChecker() {
        stopPlaybackTimeChecker()
        playbackTimeCheckerTimer = Timer.scheduledTimer(
            timeInterval: 0.01,
            target: self,
            selector: #selector(onPlaybackTimeChecker), userInfo: nil, repeats: true
        )
    }

    func stopPlaybackTimeChecker() {
        playbackTimeCheckerTimer?.invalidate()
        playbackTimeCheckerTimer = nil
    }

    @objc func onPlaybackTimeChecker() {
        guard let startTime = trimmerView.startTime, let endTime = trimmerView.endTime, let player = player else {
            return
        }

        let playBackTime = player.currentTime()
        trimmerView.seek(to: playBackTime)

        if playBackTime >= endTime {
            player.seek(to: startTime, toleranceBefore: CMTime.zero, toleranceAfter: CMTime.zero)
            trimmerView.seek(to: startTime)
        }
    }

    private func exportVideo(completion: @escaping(_ exportURL: URL?, _ errorMessage: String?) -> Void) {
        let fileManager = FileManager.default
        let documentDirectory = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]

        guard let sourceVideoURL else {
            completion(nil, "Export failed")
            return
        }
        let asset = AVAsset(url: sourceVideoURL)
        guard asset.isExportable,
              let sourceVideoTrack = asset.tracks(withMediaType: .video).first,
              let sourceAudioTrack = asset.tracks(withMediaType: .audio).first else {
            completion(nil, "Export failed")
            return
        }

        let composition = AVMutableComposition()
        let compositionVideoTrack = composition.addMutableTrack(withMediaType: .video, preferredTrackID: CMPersistentTrackID(kCMPersistentTrackID_Invalid))
        compositionVideoTrack?.preferredTransform = sourceVideoTrack.preferredTransform
        let compositionAudioTrack = composition.addMutableTrack(withMediaType: .audio, preferredTrackID: CMPersistentTrackID(kCMPersistentTrackID_Invalid))

        do {
            try compositionVideoTrack?.insertTimeRange(CMTimeRangeMake(start: .zero, duration: asset.duration), of: sourceVideoTrack, at: .zero)
            try compositionAudioTrack?.insertTimeRange(CMTimeRangeMake(start: .zero, duration: asset.duration), of: sourceAudioTrack, at: .zero)
        } catch {
            completion(nil, "Export failed")
            return
        }

        let compatiblePresets = AVAssetExportSession.exportPresets(compatibleWith: composition)
        var preset = AVAssetExportPresetPassthrough
        let preferredPreset = AVAssetExportPresetHighestQuality
        if compatiblePresets.contains(preferredPreset) {
            preset = preferredPreset
        }

        var outputURL = documentDirectory.appendingPathComponent("output")
        do {
            try fileManager.createDirectory(at: outputURL, withIntermediateDirectories: true, attributes: nil)
            outputURL = outputURL.appendingPathComponent("\(UUID().uuidString).\("mp4")")
        } catch let error {
            print(error.localizedDescription)
            completion(nil, "Export failed")
            return
        }
        try? fileManager.removeItem(at: outputURL)

        let fileType: AVFileType = .mp4
        guard let exportSession = AVAssetExportSession(asset: composition, presetName: preset),
              exportSession.supportedFileTypes.contains(fileType) else {
            completion(nil, "Try again")
            return
        }

        let timeRange = CMTimeRangeFromTimeToTime(start: trimmerView.startTime ?? .zero, end: trimmerView.endTime ?? .zero)
        exportSession.outputURL = outputURL
        exportSession.outputFileType = .mp4
        exportSession.timeRange = timeRange
        // 4 MB max
        exportSession.fileLengthLimit = (1024 * 1024 * 4)

        DispatchQueue.global().async {
            exportSession.exportAsynchronously(completionHandler: { [weak exportSession] in
                DispatchQueue.main.async {
                    guard exportSession?.error == nil else {
                        completion(nil, "Try again")
                        return
                    }
                    completion(outputURL, nil)
                }
            })
        }
        //src: https://img.ly/blog/trim-and-crop-video-in-swift/
        //src: https://stackoverflow.com/questions/35696188/how-to-trim-a-video-in-swift-for-a-particular-time
        //src: https://stackoverflow.com/questions/41544359/exporting-mp4-through-avassetexportsession-fails
    }
}
