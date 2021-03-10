//
//  SuccessViewController.swift
//  Spot
//
//  Created by kbarone on 4/7/19.
//  Copyright © 2019 sp0t, LLC. All rights reserved.
//

import UIKit
import Firebase

class SuccessViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
        Analytics.logEvent("successAppeared", parameters: nil)
        
        view.isUserInteractionEnabled = true

        self.view.backgroundColor = UIColor(named: "SpotBlack")
        
        let textLayer = UILabel(frame: CGRect(x: 24, y: 311, width: 327, height: 63))
        textLayer.lineBreakMode = .byWordWrapping
        textLayer.numberOfLines = 0
        textLayer.textColor = UIColor(named: "SpotGreen")
        textLayer.textAlignment = .center
        let textContent = "All set. Thanks for your submission. If your spot is approved, you’ll get a notification in a couple days."
        let textString = NSMutableAttributedString(string: textContent, attributes: [    NSAttributedString.Key.font: UIFont(name: "SFCamera-Regular", size: 18)!])
        let textRange = NSRange(location: 0, length: textString.length)
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineSpacing = 1.17
        textString.addAttribute(NSAttributedString.Key.paragraphStyle, value:paragraphStyle, range: textRange)
        textLayer.attributedText = textString
        textLayer.sizeToFit()
        self.view.addSubview(textLayer)
        
        let returnButton = UIButton(frame:CGRect(x: 80, y: 400, width: Int(UIScreen.main.bounds.width) - 160, height: 63))
        returnButton.setTitle("Return to Map", for: UIControl.State.normal)
        returnButton.setTitleColor(UIColor(named: "SpotGreen"), for: UIControl.State.normal)
        returnButton.titleLabel?.font = UIFont(name: "SFCamera-Semibold", size: 22)
        returnButton.backgroundColor = nil
        returnButton.layer.borderColor = UIColor(named: "SpotGreen")?.cgColor
        returnButton.layer.cornerRadius = 12
        returnButton.layer.borderWidth = 2
        returnButton.titleEdgeInsets = UIEdgeInsets(top: 2, left: 2, bottom: 2, right: 2)
        
      //  returnButton.sizeToFit()
        returnButton.addTarget(self, action: #selector(self.toMap), for: .touchUpInside)
            self.view.addSubview(returnButton)
    }
    
    
    @objc func toMap(_ sender:UIButton) {
        guard let controllers = navigationController?.viewControllers else { return }
        let count = controllers.count
        if count > 2 {
            // Third from the last is the viewController we want
            navigationController?.popToRootViewController(animated: false)
        }
    }
}
