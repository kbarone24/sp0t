//
//  HomeScreenPopCoverPage.swift
//  Spot
//
//  Created by Kenny Barone on 9/5/23.
//  Copyright © 2023 sp0t, LLC. All rights reserved.
//

import Foundation
import UIKit
import SDWebImage
import Mixpanel
import AudioToolbox

protocol PopCoverDelegate: AnyObject {
    func inviteTap()
    func joinTap(pop: Spot)
    func swipeGesture()
}

class HomeScreenPopCoverPage: UIView {
    private lazy var backgroundImage: UIImageView = {
        let view = UIImageView()
        view.contentMode = .scaleAspectFill
        return view
    }()

    private lazy var playerView = PlayerView(videoGravity: .resizeAspectFill)

    private lazy var inviteButton: UIButton = {
        let button = PillButtonWithImage(
            backgroundColor: .clear,
            image: UIImage(named: "PopShareButton"),
            title: "invite",
            titleColor: .white,
            iconOrientation: .right,
            font: SpotFonts.SFCompactRoundedSemibold.fontWith(size: 22)
        )
        button.addTarget(self, action: #selector(inviteTap), for: .touchUpInside)
        return button
    }()

    private lazy var visitorsContainer = UIView()

    private lazy var visitorsIcon = UIImageView(image: UIImage(named: "PopVisitorsIcon"))

    private lazy var visitorsCount: UILabel = {
        let label = UILabel()
        label.font = SpotFonts.UniversCE.fontWith(size: 15)
        label.textColor = .white
        return label
    }()

    private lazy var titleLabel: UILabel = {
        let label = UILabel()
        label.textColor = .white
        label.font = SpotFonts.SFCompactRoundedBold.fontWith(size: 49)
        label.numberOfLines = 1
        label.adjustsFontSizeToFitWidth = true
        label.textAlignment = .center
        return label
    }()

    // set up in configure
    private lazy var statusLabel: UILabel = {
        let label = UILabel()
        label.textColor = .white
        return label
    }()

    private lazy var countdownLabel: UILabel = {
        let label = UILabel()
        label.font = SpotFonts.UniversCE.fontWith(size: 69)
        label.textColor = UIColor(red: 0.979, green: 0.979, blue: 0.979, alpha: 1)
        label.addShadow(shadowColor: UIColor.black.cgColor, opacity: 0.5, radius: 4, offset: CGSize(width: 0, height: 4))
        return label
    }()

    private lazy var joinButton: UIButton = {
        let gradient = CAGradientLayer()
        gradient.colors = [
            UIColor(red: 0.225, green: 0.952, blue: 1, alpha: 1).cgColor,
            UIColor(red: 0.345, green: 1, blue: 0.45, alpha: 1).cgColor
            ]
        gradient.locations = [0.3, 1]
        gradient.startPoint = CGPoint(x: 0.5, y: 0.0)
        gradient.endPoint = CGPoint(x: 0.5, y: 1.0)
        let button = GradientButton(layer: gradient, image: nil, text: "POP IN", cornerRadius: 30, font: SpotFonts.SFCompactRoundedHeavy.fontWith(size: 21))
        button.addTarget(self, action: #selector(joinTap), for: .touchUpInside)
        return button
    }()

    private lazy var swipeLabel: UILabel = {
        let label = UILabel()
        label.text = "swipe left to go home"
        label.textColor = UIColor(red: 1, green: 1, blue: 1, alpha: 0.9)
        label.font = SpotFonts.SFCompactRoundedSemibold.fontWith(size: 15)
        return label
    }()

    var audioPlayer: AVAudioPlayer?

    private lazy var popIcon = UIImageView(image: UIImage(named: "PopTabsIcon"))

    private lazy var fullScreenMask = UIView()

    weak var delegate: PopCoverDelegate?
    var pop: Spot?

    private var countdownTimer: Timer?
    var wasDismissed = false {
        didSet {
            if wasDismissed {
                audioPlayer?.stop()
                playerView.player?.pause()
            } else {
                audioPlayer?.play()
                playerView.player?.play()
            }
        }
    }

    deinit {
        countdownTimer?.invalidate()
        countdownTimer = nil
        NotificationCenter.default.removeObserver(self)
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        layoutIfNeeded()
        addMasks()
    }

    override func removeFromSuperview() {
        super.removeFromSuperview()
        countdownTimer?.invalidate()
        countdownTimer = nil
        NotificationCenter.default.removeObserver(self)
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = nil
        clipsToBounds = true

        let swipe = UISwipeGestureRecognizer(target: self, action: #selector(swipe(_:)))
        swipe.direction = .left
        addGestureRecognizer(swipe)

        addSubview(playerView)
        playerView.snp.makeConstraints {
            $0.edges.equalToSuperview()
        }

        addSubview(backgroundImage)
        backgroundImage.snp.makeConstraints {
            $0.edges.equalToSuperview()
        }

        addSubview(fullScreenMask)
        fullScreenMask.snp.makeConstraints {
            $0.edges.equalToSuperview()
        }

        addSubview(inviteButton)
        inviteButton.snp.makeConstraints {
            $0.top.equalTo(60)
            $0.trailing.equalTo(-35)
            $0.width.equalTo(100)
            $0.height.equalTo(30)
        }

        addSubview(visitorsContainer)
        visitorsContainer.translatesAutoresizingMaskIntoConstraints = false
        visitorsContainer.snp.makeConstraints {
            $0.centerY.equalToSuperview().offset(-157)
            $0.centerX.equalToSuperview()
        }

        visitorsContainer.addSubview(visitorsIcon)
        visitorsIcon.snp.makeConstraints {
            $0.leading.top.bottom.equalToSuperview()
        }

        visitorsContainer.addSubview(visitorsCount)
        visitorsCount.snp.makeConstraints {
            $0.leading.equalTo(visitorsIcon.snp.trailing).offset(4)
            $0.trailing.equalToSuperview()
            $0.centerY.equalToSuperview().offset(1.5)
        }

        addSubview(titleLabel)
        titleLabel.snp.makeConstraints {
            $0.top.equalTo(visitorsContainer.snp.bottom).offset(10)
            $0.leading.trailing.equalToSuperview().inset(20)
        }

        addSubview(statusLabel)
        statusLabel.snp.makeConstraints {
            $0.top.equalTo(titleLabel.snp.bottom).offset(8)
            $0.centerX.equalToSuperview()
        }

        addSubview(joinButton)
        joinButton.snp.makeConstraints {
            $0.top.equalTo(statusLabel.snp.bottom).offset(20)
            $0.leading.trailing.equalToSuperview().inset(40)
            $0.height.equalTo(59)
        }

        addSubview(countdownLabel)
        countdownLabel.snp.makeConstraints {
            $0.top.equalTo(statusLabel.snp.bottom).offset(16)
            $0.centerX.equalToSuperview()
        }

        addSubview(popIcon)
        popIcon.snp.makeConstraints {
            $0.bottom.equalToSuperview().offset(-40)
            $0.centerX.equalToSuperview()
        }

        addSubview(swipeLabel)
        swipeLabel.snp.makeConstraints {
            $0.bottom.equalTo(popIcon.snp.top).offset(-10)
            $0.centerX.equalToSuperview()
        }
    }

    func configure(pop: Spot, delegate: PopCoverDelegate) {
        self.delegate = delegate
        self.pop = pop

        // no prepareForReuse() on UIView so manually invalidate
        countdownTimer?.invalidate()
        countdownTimer = nil

        // set thumbnailimage regardless
        backgroundImage.sd_setImage(with: URL(string: pop.imageURL), placeholderImage: UIImage(color: .lightGray))

        // Set the audio session category
        do {
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setCategory(.playback, mode: .default, options: [.mixWithOthers])
      //      try audioSession.setActive(true)
        } catch {
            print("error setting up audio session")
        }

        if let videoURL = pop.videoURL, videoURL != "", let url = URL(string: videoURL) {
            let player = AVPlayer(url: url)
            playerView.player = player
            playerView.player?.isMuted = true

            NotificationCenter.default.addObserver(forName: .AVPlayerItemDidPlayToEndTime, object: playerView.player?.currentItem, queue: nil) { [weak self] _ in
                self?.playerView.player?.seek(to: CMTime.zero)
                self?.playerView.player?.play()
            }

            NotificationCenter.default.addObserver(self, selector: #selector(enteredForeground), name: UIApplication.willEnterForegroundNotification, object: nil)
            playerView.player?.addObserver(self, forKeyPath: "timeControlStatus", options: [.old, .new], context: nil)

        } else {
            playerView.isHidden = true
        }

        if let audioURL = pop.audioURL,
            audioURL != "",
            let url = URL(string: audioURL),
           !pop.popIsActive
        {
            loadAudio(url: url)
        }

        titleLabel.text = pop.spotName
        visitorsCount.text = String(pop.visitorList.count)

        configureStatusLabel(pop: pop)
        startCountdownTimer(pop: pop)
    }

    // called for listener updates
    func setVisitors(pop: Spot) {
        self.pop = pop
        visitorsCount.text = String(pop.visitorList.count)
    }

    private func configureStatusLabel(pop: Spot) {
        configureJoinState(pop: pop)

        if pop.popIsActive {
            statusLabel.font = SpotFonts.SFCompactRoundedHeavy.fontWith(size: 28)
            statusLabel.textColor =  UIColor(red: 0.259, green: 0.969, blue: 0.883, alpha: 1)
            statusLabel.text = "LIVE NOW. ENDS SOON."
            // stop audio player when pop starts
            audioPlayer?.stop()

        } else {
            statusLabel.font = SpotFonts.SFCompactRoundedSemibold.fontWith(size: 22)
            statusLabel.textColor = .white
            statusLabel.text = "starts in"
        }
    }

    private func configureJoinState(pop: Spot) {
        if pop.popIsActive {
            joinButton.isHidden = false
            countdownLabel.isHidden = true

        } else {
            joinButton.isHidden = true
            countdownLabel.isHidden = false
            configureTimeLeft(pop: pop)
        }
    }

    private func configureTimeLeft(pop: Spot) {
        guard let targetTimestamp = pop.startTimestamp else { return }
        let startDate = targetTimestamp.dateValue()

        let currentTime = Date()
        let timeRemaining = startDate.timeIntervalSince(currentTime)
        guard timeRemaining > 0 else { return }

        let formatter = DateComponentsFormatter()
        formatter.unitsStyle = .positional
        if timeRemaining > 60 * 60 {
            formatter.allowedUnits = [.hour, .minute, .second]
        } else {
            formatter.allowedUnits = [.minute, .second]
            formatter.zeroFormattingBehavior = .pad
        }

        if timeRemaining < 1 {
            // final vibrate + play beginning sound
            UIImpactFeedbackGenerator(style: .soft).impactOccurred()
            AudioServicesPlayAlertSound(UInt32(1001))

        } else if timeRemaining < 10 {
            // countdown vibration
            UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
        }

        if let formattedString = formatter.string(from: timeRemaining) {
            countdownLabel.text = formattedString
        }
    }

    private func startCountdownTimer(pop: Spot) {
        self.countdownTimer = Timer.scheduledTimer(withTimeInterval: TimeInterval(1), repeats: true) { [weak self] timer in
            self?.configureStatusLabel(pop: pop)
        }

        countdownTimer?.tolerance = 0.1
        RunLoop.current.add(countdownTimer ?? Timer(), forMode: .common)
    }

    private func addMasks() {
        for layer in fullScreenMask.layer.sublayers ?? [] { layer.removeFromSuperlayer() }
        let mask = CAGradientLayer()
        mask.frame = fullScreenMask.bounds
        mask.colors = [
            UIColor.black.withAlphaComponent(0.7).cgColor,
            UIColor.black.withAlphaComponent(0.3).cgColor,
            UIColor.black.withAlphaComponent(0.3).cgColor,
            UIColor.black.withAlphaComponent(0.7).cgColor
        ]
        mask.locations = [0, 0.22, 0.78, 1.0]
        mask.startPoint = CGPoint(x: 0.5, y: 0)
        mask.endPoint = CGPoint(x: 0.5, y: 1.0)
        fullScreenMask.layer.addSublayer(mask)
    }

    private func loadAudio(url: URL) {
        let session = URLSession.shared

        let task = session.dataTask(with: url) { (data, response, error) in
            guard error == nil, let soundData = data else {
                print("Error loading audio")
                return
            }
            do {
                guard !self.wasDismissed else { return }

                // Initialize the AVAudioPlayer with the audio data
                self.audioPlayer = try AVAudioPlayer(data: soundData)
                self.audioPlayer?.volume = 0.7
                self.audioPlayer?.prepareToPlay()
                self.audioPlayer?.play()

            } catch {
                print("Error initializing audio player: \(error.localizedDescription)")
            }
        }

        // Start the data task
        task.resume()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    @objc func swipe(_ gesture: UISwipeGestureRecognizer) {
        Mixpanel.mainInstance().track(event: "PopCoverPageSwipeToHome")
        animateOffscreen(swipe: true)
    }

    @objc func joinTap() {
        guard let pop else { return }
        Mixpanel.mainInstance().track(event: "PopCoverPageJoinTap")
        animateOffscreen(swipe: false)
        delegate?.joinTap(pop: pop)
    }

    @objc func inviteTap() {
        Mixpanel.mainInstance().track(event: "PopCoverPageInviteTap")
        delegate?.inviteTap()
    }

    private func animateOffscreen(swipe: Bool) {
        UIView.animate(withDuration: 0.35, animations: {
            self.transform = CGAffineTransform(translationX: -UIScreen.main.bounds.width, y: 0)
        }) { [weak self] _ in
            self?.wasDismissed = true
            if swipe {
                self?.delegate?.swipeGesture()
            }
        }
    }

    override public func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        if keyPath == "timeControlStatus", let change = change, let newValue = change[NSKeyValueChangeKey.newKey] as? Int, let oldValue = change[NSKeyValueChangeKey.oldKey] as? Int {
            let oldStatus = AVPlayer.TimeControlStatus(rawValue: oldValue)
            let newStatus = AVPlayer.TimeControlStatus(rawValue: newValue)
            if newStatus != oldStatus {
                DispatchQueue.main.async {[weak self] in
                    if newStatus == .playing {
                        self?.backgroundImage.isHidden = true
                    }
                }
            }
        }
    }
    // src: https://stackoverflow.com/questions/42743343/avplayer-show-and-hide-loading-indicator-when-buffering


    @objc func enteredForeground() {
        DispatchQueue.main.async {
            if !self.wasDismissed {
                // set background image to hidden to show while video is buffering
                self.backgroundImage.isHidden = false
                self.playerView.player?.play()
                self.audioPlayer?.play()
            }
        }
    }
}
