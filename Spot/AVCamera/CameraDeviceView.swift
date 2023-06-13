//
//  CameraDeviceView.swift
//  Spot
//
//  Created by Kenny Barone on 6/1/23.
//  Copyright © 2023 sp0t, LLC. All rights reserved.
//

import Foundation
import UIKit
import NextLevel

class CameraDeviceView: UIView {
    var devices = [AVCaptureDevice]()
    init(devices: [AVCaptureDevice]) {
        super.init(frame: .zero)
        self.devices = devices
        backgroundColor = UIColor.white.withAlphaComponent(0.1)
        layer.cornerRadius = 20
        setButtonSizes(selectedIndex: 1)
    }

    private func setButtonSizes(selectedIndex: Int) {
        for view in subviews { view.removeFromSuperview() }
        for i in 0..<devices.count {
            let selected = i == selectedIndex
            let size: CGFloat = selected ? 45 : 30

            let button = DeviceTypeButton(isActiveDevice: selected)
            button.addTarget(self, action: #selector(buttonTap(_:)), for: .touchUpInside)
            button.tag = i
            addSubview(button)

            switch devices[i].deviceType {
            case .builtInUltraWideCamera:
                let title = selected ? "0.5x" : "0.5"
                button.setTitle(title, for: .normal)

                button.snp.makeConstraints {
                    $0.leading.equalToSuperview().inset(8)
                    $0.height.width.equalTo(size)
                    $0.height.width.equalTo(size)

                    if selected {
                        $0.top.bottom.equalToSuperview().inset(8)
                    } else {
                        $0.centerY.equalToSuperview()
                    }
                }

            case .builtInWideAngleCamera:
                let title = selected ? "1x" : "1"
                button.setTitle(title, for: .normal)

                button.snp.makeConstraints {
                    $0.height.width.equalTo(size)
                    // 8 from boundary if its the first camera, otherwise adjust if wide angle is selected or not
                    let leadingOffset: CGFloat = i == 0 ? 8 : selectedIndex == 0 ? 62 : 47
                    $0.leading.equalTo(leadingOffset)

                    if selected {
                        $0.top.bottom.equalToSuperview().inset(8)
                    } else {
                        $0.centerY.equalToSuperview()
                    }

                    if !devices.contains(where: {$0.deviceType == .builtInTelephotoCamera}) {
                        $0.trailing.equalToSuperview().inset(8)
                    }
                }

            case .builtInTelephotoCamera:
                let title = selected ? "3x" : "3"
                button.setTitle(title, for: .normal)

                button.snp.makeConstraints {
                    $0.trailing.equalToSuperview().inset(8)
                    $0.height.width.equalTo(size)

                    if selected {
                        $0.top.bottom.equalToSuperview().inset(8)
                    } else {
                        $0.centerY.equalToSuperview()
                    }

                    if i == 1 {
                        // don't know if this will ever be true
                        $0.leading.equalTo(47)
                    } else if selected {
                        $0.leading.equalTo(85)
                    } else {
                        $0.leading.equalTo(100)
                    }
                    
                }
            default: continue
            }
        }

    }

    @objc func buttonTap(_ sender: UIButton) {
        // 1. resize buttons with selected index
        setButtonSizes(selectedIndex: sender.tag)
        switch sender.tag {
        case 0:
            try? NextLevel.shared.changeCaptureDeviceIfAvailable(captureDevice: .ultraWideAngleCamera)
        case 1:
            if devices.contains(where: { $0.deviceType == .builtInUltraWideCamera }) {
                try? NextLevel.shared.changeCaptureDeviceIfAvailable(captureDevice: .wideAngleCamera)
            } else {
                try? NextLevel.shared.changeCaptureDeviceIfAvailable(captureDevice: .telephotoCamera)
            }
        case 2:
            try? NextLevel.shared.changeCaptureDeviceIfAvailable(captureDevice: .telephotoCamera)
        default: return
        }
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

class DeviceTypeButton: UIButton {
    let unselectedSize: CGFloat = 30
    let selectedSize: CGFloat = 45
    init(isActiveDevice: Bool) {
        super.init(frame: .zero)
        backgroundColor = UIColor.white.withAlphaComponent(0.3)
        setUp(isActiveDevice: isActiveDevice)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setUp(isActiveDevice: Bool) {
        if isActiveDevice {
            setTitleColor(.systemYellow, for: .normal)
            titleLabel?.font = UIFont(name: "SFCompactText-Semibold", size: 13)
            layer.cornerRadius = selectedSize / 2
        } else {
            titleLabel?.font = UIFont(name: "SFCompactText-Semibold", size: 11.5)
            setTitleColor(.white, for: .normal)
            layer.cornerRadius = unselectedSize / 2
        }
    }
}
