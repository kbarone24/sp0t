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

class VideoEditorController: UIViewController {
    private var player: AVPlayer?
    private var sourceVideoURL: URL?
    
    private lazy var playerView = UIView()
    private lazy var trimmerView: TrimmerView = {
        let trimmerView = TrimmerView()
        trimmerView.delegate = self
        trimmerView.positionBarColor = .white
        trimmerView.handleColor = UIColor(named: "SpotGreen") ?? .black
        trimmerView.mainColor = UIColor(hexString: "2d2d2d")
        trimmerView.maxDuration = 7
        trimmerView.minDuration = 0.5
        return trimmerView
    }()

    let symbolConfig = UIImage.SymbolConfiguration(weight: .regular)
    let buttonConfig: UIButton.Configuration = {
        var config = UIButton.Configuration.plain()
        config.contentInsets = NSDirectionalEdgeInsets(top: 5, leading: 5, bottom: 5, trailing: 5)
        return config
    }()
    private lazy var playButton: UIButton = {
        let button = UIButton(configuration: buttonConfig)
        button.setImage(UIImage(systemName: "play.square", withConfiguration: symbolConfig), for: .normal)
        button.imageView?.tintColor = .white
        button.contentHorizontalAlignment = .fill
        button.contentVerticalAlignment = .fill
        button.addTarget(self, action: #selector(playTap), for: .touchUpInside)
        return button
    }()
    private lazy var pauseButton: UIButton = {
        let button = UIButton(configuration: buttonConfig)
        button.setImage(UIImage(systemName: "pause.rectangle", withConfiguration: symbolConfig), for: .normal)
        button.imageView?.tintColor = .white
        button.contentHorizontalAlignment = .fill
        button.contentVerticalAlignment = .fill
        button.addTarget(self, action: #selector(pauseTap), for: .touchUpInside)
        return button
    }()
    lazy var nextButton: UIButton = {
        let button = UIButton()
        button.setTitle("Next", for: .normal)
        button.setTitleColor(.black, for: .normal)
        button.titleLabel?.font = UIFont(name: "SFCompactText-Bold", size: 15)
        button.backgroundColor = UIColor(named: "SpotGreen")
        button.layer.cornerRadius = 8
        button.addTarget(self, action: #selector(nextTap), for: .touchUpInside)
        return button
    }()

    private(set) lazy var activityIndicator: UIActivityIndicatorView = {
        let view = UIActivityIndicatorView(style: .large)
        view.color = .white
        return view
    }()

    var imageObject: ImageObject?

    let options: PHVideoRequestOptions = {
        let options = PHVideoRequestOptions()
        options.deliveryMode = .highQualityFormat
        options.isNetworkAccessAllowed = true
        return options
    }()

    var playbackTimeCheckerTimer: Timer?
    var trimmerPositionChangedTimer: Timer?

    init(imageObject: ImageObject) {
        super.init(nibName: nil, bundle: nil)
        self.imageObject = imageObject
        view.backgroundColor = UIColor(named: "SpotBlack")

        view.addSubview(playerView)
        playerView.snp.makeConstraints {
            $0.top.equalToSuperview().offset(10)
            $0.leading.trailing.equalToSuperview().inset(40)
            $0.height.equalTo((UIScreen.main.bounds.width - 80) * UserDataModel.shared.maxAspect)
        }

        view.addSubview(nextButton)
        let nextBottom: CGFloat = UserDataModel.shared.screenSize == 0 ? 30 : 45
        nextButton.snp.makeConstraints {
            $0.trailing.equalToSuperview().inset(15)
            $0.bottom.equalToSuperview().inset(nextBottom)
            $0.width.equalTo(94)
            $0.height.equalTo(40)
        }

        view.addSubview(trimmerView)
        trimmerView.snp.makeConstraints {
            $0.leading.equalToSuperview().offset(50)
            $0.trailing.equalToSuperview().offset(-20)
            $0.bottom.equalTo(nextButton.snp.top).offset(-14)
            $0.height.equalTo(60)
        }

        view.addSubview(playButton)
        playButton.tintColor = .white
        playButton.snp.makeConstraints {
            $0.trailing.equalTo(trimmerView.snp.leading)
            $0.centerY.equalTo(trimmerView)
            $0.height.width.equalTo(40)
        }

        view.addSubview(pauseButton)
        pauseButton.tintColor = .white
        pauseButton.isHidden = true
        pauseButton.snp.makeConstraints {
            $0.trailing.centerY.equalTo(playButton)
            $0.height.width.equalTo(40)
        }

        view.addSubview(activityIndicator)
        activityIndicator.snp.makeConstraints {
            $0.centerX.equalToSuperview()
            $0.centerY.equalToSuperview().offset(-150)
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
        navigationController?.navigationBar.addBlackBackground()

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
        guard let asset = imageObject?.asset else { return }
        PHCachingImageManager().requestPlayerItem(forVideo: asset, options: options) { [weak self] (playerItem, info) in
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
    }

    @objc func nextTap() {
        nextButton.isEnabled = false
        nextButton.alpha = 0.7
        pauseVideo()
        activityIndicator.startAnimating()

        // trim and export video
        exportVideo { [weak self] exportURL, errorMessage in
            guard let exportURL, let videoData = try? Data(contentsOf: exportURL, options: .mappedIfSafe), let self
            else {
                self?.showError(message: errorMessage ?? "")
                return
            }
            let thumbnailImage = getThumbnailFor(url: exportURL)
            DispatchQueue.main.async {
                let vc = ImagePreviewController()
                vc.mode = .video(url: exportURL)
                let object = VideoObject(
                    id: UUID().uuidString,
                    asset: PHAsset(),
                    thumbnailImage: thumbnailImage,
                    videoData: videoData,
                    videoPath: exportURL,
                    rawLocation: self.imageObject?.rawLocation ?? UserDataModel.shared.currentLocation,
                    creationDate: Date(),
                    fromCamera: true
                )
                vc.videoObject = object
                self.navigationController?.pushViewController(vc, animated: false)

                self.activityIndicator.stopAnimating()
                self.nextButton.isEnabled = true
                self.nextButton.alpha = 1.0
            }
        }
    }

    private func playVideo() {
        player?.play()
        addEndObserver()
        playButton.isHidden = true
        pauseButton.isHidden = false
        startPlaybackTimeChecker()
    }

    @objc func pauseTap() {
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
        nextButton.isEnabled = true
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

    private func getThumbnailFor(url: URL) -> UIImage {
        // we want to get a fresh thumbnail in case the user changed the start time of the video
        do {
            let asset = AVURLAsset(url: url, options: nil)
            let imgGenerator = AVAssetImageGenerator(asset: asset)
            imgGenerator.appliesPreferredTrackTransform = true
            let cgImage = try imgGenerator.copyCGImage(at: .zero, actualTime: nil)
            return UIImage(cgImage: cgImage)
        } catch let error {
            print("Error generating thumbnail: \(error.localizedDescription)")
            return self.imageObject?.stillImage ?? UIImage()
        }
    }
}
