//
//  SubmitPublicController.swift
//  Spot
//
//  Created by kbarone on 2/12/20.
//  Copyright © 2020 sp0t, LLC. All rights reserved.
//

import Firebase
import Foundation
import UIKit

class SubmitPublicController: UIViewController {
    var spotID = ""
    let db: Firestore! = Firestore.firestore()
    var titleLabel: UILabel!
    var descriptionLabel: UILabel!

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor(named: "SpotBlack")
        self.navigationController?.navigationBar.isUserInteractionEnabled = true

        titleLabel = UILabel(frame: CGRect(x: 14, y: 110, width: 270, height: 25))
        titleLabel.text = "Public submission tips"
        titleLabel.textColor = .white
        titleLabel.font = UIFont(name: "SFCamera-Semibold", size: 21)
        view.addSubview(titleLabel)

        descriptionLabel = UILabel(frame: CGRect(x: 14, y: 168, width: UIScreen.main.bounds.width - 28, height: 200))
        descriptionLabel.text = "- Your spot should be a business or public space: somewhere you would feel confortable running into a stranger\n\n- Once accepted, your submission becomes the spot's first post. Don’t worry about describing the spot perfectly: we’ll add any details you leave out"
        descriptionLabel.font = UIFont(name: "SFCamera-Regular", size: 18)
        descriptionLabel.textColor = UIColor(red: 0.61, green: 0.61, blue: 0.61, alpha: 1.0)
        descriptionLabel.numberOfLines = 0
        descriptionLabel.lineBreakMode = .byWordWrapping
        descriptionLabel.sizeToFit()
        view.addSubview(descriptionLabel)

        let submitImage = UIImage(named: "SubmitFeedbackButton")!.withRenderingMode(.alwaysOriginal)
        self.navigationItem.rightBarButtonItem = UIBarButtonItem(image: submitImage, style: UIBarButtonItem.Style.plain, target: self, action: #selector(submitTap(_:)))
    }

    @objc func submitTap(_ sender: UIBarButtonItem) {
        let submissionID = UUID().uuidString
        db.collection("submissions").document(submissionID).setData(["spotID": spotID])

        self.titleLabel.isHidden = true
        self.descriptionLabel.isHidden = true

        let exitImage = UIImage(named: "ExitButton")!.withRenderingMode(.alwaysOriginal)
        self.navigationItem.rightBarButtonItem = UIBarButtonItem(image: exitImage, style: UIBarButtonItem.Style.plain, target: self, action: #selector(exitTap(_:)))
        self.navigationItem.leftBarButtonItem = UIBarButtonItem()

        let checkIcon = UIImageView(frame: CGRect(x: 132, y: 236, width: 35, height: 35))
        checkIcon.image = UIImage(named: "CheckIcon")
        view.addSubview(checkIcon)

        let submitLabel = UILabel(frame: CGRect(x: 175, y: 241, width: 120, height: 25))
        submitLabel.text = "Submitted"
        submitLabel.font = UIFont(name: "SFCamera-Semibold", size: 21)
        submitLabel.textColor = UIColor(named: "SpotGreen")
        view.addSubview(submitLabel)

        let descriptionLabel = UILabel(frame: CGRect(x: 81, y: 297, width: UIScreen.main.bounds.width - 162, height: 40))
        descriptionLabel.text = "Thanks! You'll get a notification soon if your spot is accepted"
        descriptionLabel.font = UIFont(name: "SFCamera-Semibold", size: 16)
        descriptionLabel.textColor = UIColor(red: 0.61, green: 0.61, blue: 0.61, alpha: 1.0)
        descriptionLabel.numberOfLines = 0
        descriptionLabel.lineBreakMode = .byWordWrapping
        descriptionLabel.sizeToFit()
        descriptionLabel.textAlignment = .center
        view.addSubview(descriptionLabel)
    }

    @objc func exitTap(_ sender: UIBarButtonItem) {
        self.navigationController?.popViewController(animated: false)
    }
}
