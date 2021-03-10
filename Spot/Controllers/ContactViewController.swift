//
//  ContactViewController.swift
//  Spot
//
//  Created by kbarone on 7/29/19.
//  Copyright © 2019 comp523. All rights reserved.
//
/*
import Foundation
import UIKit
import Firebase
import FirebaseFirestore
import FirebaseAuth

class ContactViewController: UIViewController {
    
    let db: Firestore! = Firestore.firestore()
    let uid: String = Auth.auth().currentUser?.uid ?? "invalid ID"
    
    var scrollView: UIScrollView!
    
    var label: UILabel!
    var textView: UITextView!
    var submitButton: UIButton!
    
    var faqLabel: UILabel!
    var question0, question1, question2, question3, question4, question5, question6: UILabel!
    var answer0, answer1, answer2, answer3, answer4, answer5, answer6: UILabel!
    
    var constantHeight: CGFloat!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor(named: "SpotBlack")
        self.navigationItem.backBarButtonItem?.title = ""
        self.navigationItem.title = "Beta test"
        
        constantHeight = 30
        setUpFields()
    }
    func setUpFields() {
        scrollView = UIScrollView(frame: view.frame)
        scrollView.backgroundColor = UIColor(named: "SpotBlack")
        scrollView.isScrollEnabled = true
        scrollView.isUserInteractionEnabled = true
        scrollView.showsVerticalScrollIndicator = false
        view.addSubview(scrollView)
        
        
        label = UILabel(frame: CGRect(x: 22, y: constantHeight, width: UIScreen.main.bounds.width - 29, height: 20))
        label.text = "Question? Encounter a bug? Feature request? Tell us here:"
        label.lineBreakMode = .byWordWrapping
        label.numberOfLines = 0
        label.textColor = UIColor(red:0.88, green:0.88, blue:0.88, alpha:1.0)
        label.font = UIFont(name: "SFCamera-Semibold", size: 13)
        label.sizeToFit()
        scrollView.addSubview(label)
        
        constantHeight = constantHeight + label.bounds.height + 12
        
        textView = UITextView(frame: CGRect(x: 20, y: constantHeight, width: UIScreen.main.bounds.width - 40, height: 120))
        textView.backgroundColor = nil
        textView.layer.borderColor = UIColor(named: "SpotGreen")?.cgColor
        textView.layer.borderWidth = 1
        textView.layer.cornerRadius = 12
        textView.textColor = UIColor.white
        textView.font = UIFont(name: "SFCamera-regular", size: 14)!
        textView.isScrollEnabled = false
        textView.textContainer.lineBreakMode = .byTruncatingHead
        scrollView.addSubview(textView)
        
        constantHeight = constantHeight + 135
        
        submitButton = UIButton(frame: CGRect(x: UIScreen.main.bounds.width - 86, y: constantHeight, width: 61, height: 24))
        submitButton.setImage(UIImage(named: "SubmitFeedbackButton"), for: .normal)
        submitButton.contentMode = .scaleAspectFit
        submitButton.addTarget(self, action: #selector(submitTap), for: UIControl.Event.touchUpInside)
        scrollView.addSubview(submitButton)
        
        constantHeight = constantHeight + 45
        
        faqLabel = UILabel(frame: CGRect(x: 25, y: constantHeight, width: 50, height: 17))
        faqLabel.text = "FAQs"
        faqLabel.font = UIFont(name: "SFCamera-Semibold", size: 13)
        faqLabel.textColor =  UIColor(red: 0.898, green: 0.898, blue: 0.898, alpha: 1)
        scrollView.addSubview(faqLabel)
        
        constantHeight += 32
        
        question0 = UILabel(frame: CGRect(x: 25, y: constantHeight, width: 200, height: 17))
        question0.text = "What is sp0t?"
        question0.font = UIFont(name: "SFCamera-Semibold", size: 12)
        question0.textColor = UIColor(red: 0.898, green: 0.898, blue: 0.898, alpha: 1)
        scrollView.addSubview(question0)
        
        constantHeight += 20
        
        answer0 = UILabel(frame: CGRect(x: 25, y: constantHeight, width: UIScreen.main.bounds.width - 50, height: 18))
        answer0.text = "sp0t’s an app for sharing place-based content with friends."
        answer0.font = UIFont(name: "SFCamera-Regular", size: 12)
        answer0.textColor = UIColor(red: 0.898, green: 0.898, blue: 0.898, alpha: 1)
        answer0.lineBreakMode = .byWordWrapping
        answer0.numberOfLines = 0
        answer0.sizeToFit()
        scrollView.addSubview(answer0)
        
        constantHeight += answer0.bounds.height + 8
        
        question1 = UILabel(frame: CGRect(x: 25, y: constantHeight, width: UIScreen.main.bounds.width - 50, height: 17))
        question1.text = "What does it mean to beta test?"
        question1.font = UIFont(name: "SFCamera-Semibold", size: 12)
        question1.textColor = UIColor(red: 0.898, green: 0.898, blue: 0.898, alpha: 1)
        scrollView.addSubview(question1)
        
        constantHeight += 20
        
        answer1 = UILabel(frame: CGRect(x: 25, y: constantHeight, width: UIScreen.main.bounds.width - 50, height: 18))
        answer1.text = "By beta testing, you’re one of the first to try out sp0t. Your feedback and activity on the beta helps us figure out what to build and fix"
        answer1.font = UIFont(name: "SFCamera-Regular", size: 12)
        answer1.textColor = UIColor(red: 0.898, green: 0.898, blue: 0.898, alpha: 1)
        answer1.lineBreakMode = .byWordWrapping
        answer1.numberOfLines = 0
        answer1.sizeToFit()
        scrollView.addSubview(answer1)
        
        constantHeight += answer1.bounds.height + 8
        
        question2 = UILabel(frame: CGRect(x: 25, y: constantHeight, width: UIScreen.main.bounds.width - 50, height: 17))
        question2.text = "Not sure where to start?"
        question2.font = UIFont(name: "SFCamera-Semibold", size: 12)
        question2.textColor = UIColor(red: 0.898, green: 0.898, blue: 0.898, alpha: 1)
        scrollView.addSubview(question2)
        
        constantHeight += 20
        
        answer2 = UILabel(frame: CGRect(x: 25, y: constantHeight, width: UIScreen.main.bounds.width - 50, height: 18))
        answer2.text = "Try creating a spot, adding some friends, or ask us any questions you have, above ^"
        answer2.font = UIFont(name: "SFCamera-Regular", size: 12)
        answer2.textColor = UIColor(red: 0.898, green: 0.898, blue: 0.898, alpha: 1)
        answer2.lineBreakMode = .byWordWrapping
        answer2.numberOfLines = 0
        answer2.sizeToFit()
        scrollView.addSubview(answer2)
        
        constantHeight += answer2.bounds.height + 8
        
        question3 = UILabel(frame: CGRect(x: 25, y: constantHeight, width: UIScreen.main.bounds.width - 50, height: 17))
        question3.text = "What should I post?"
        question3.font = UIFont(name: "SFCamera-Semibold", size: 12)
        question3.textColor = UIColor(red: 0.898, green: 0.898, blue: 0.898, alpha: 1)
        scrollView.addSubview(question3)
        
        constantHeight += 20
        
        answer3 = UILabel(frame: CGRect(x: 25, y: constantHeight, width: UIScreen.main.bounds.width - 50, height: 18))
        answer3.text = "People use sp0t to recommend cool places, archive adventures and travels, and share personal moments (only your friends can see your spots)"
        answer3.font = UIFont(name: "SFCamera-Regular", size: 12)
        answer3.textColor = UIColor(red: 0.898, green: 0.898, blue: 0.898, alpha: 1)
        answer3.lineBreakMode = .byWordWrapping
        answer3.numberOfLines = 0
        answer3.sizeToFit()
        scrollView.addSubview(answer3)
        
        constantHeight += answer3.bounds.height + 8
        
        question4 = UILabel(frame: CGRect(x: 25, y: constantHeight, width: UIScreen.main.bounds.width - 50, height: 17))
        question4.text = "Can I post a spot if I'm not there?"
        question4.font = UIFont(name: "SFCamera-Semibold", size: 12)
        question4.textColor = UIColor(red: 0.898, green: 0.898, blue: 0.898, alpha: 1)
        scrollView.addSubview(question4)
        
        constantHeight += 20
        
        answer4 = UILabel(frame: CGRect(x: 25, y: constantHeight, width: UIScreen.main.bounds.width - 50, height: 18))
        answer4.text = "You can upload spots in the moment or retroactively. You'll be able to adjust the location of your spot before you upload"
        answer4.font = UIFont(name: "SFCamera-Regular", size: 12)
        answer4.textColor = UIColor(red: 0.898, green: 0.898, blue: 0.898, alpha: 1)
        answer4.lineBreakMode = .byWordWrapping
        answer4.numberOfLines = 0
        answer4.sizeToFit()
        scrollView.addSubview(answer4)
        
        constantHeight += answer4.bounds.height + 8
        
        question5 = UILabel(frame: CGRect(x: 25, y: constantHeight, width: UIScreen.main.bounds.width - 50, height: 17))
        question5.text = "Will I lose my posts once sp0t's in the App Store?"
        question5.font = UIFont(name: "SFCamera-Semibold", size: 12)
        question5.textColor = UIColor(red: 0.898, green: 0.898, blue: 0.898, alpha: 1)
        scrollView.addSubview(question5)
        
        constantHeight += 20
        
        answer5 = UILabel(frame: CGRect(x: 25, y: constantHeight, width: UIScreen.main.bounds.width - 50, height: 18))
        answer5.text = "No!"
        answer5.font = UIFont(name: "SFCamera-Regular", size: 12)
        answer5.textColor = UIColor(red: 0.898, green: 0.898, blue: 0.898, alpha: 1)
        answer5.lineBreakMode = .byWordWrapping
        answer5.numberOfLines = 0
        answer5.sizeToFit()
        scrollView.addSubview(answer5)
        
        constantHeight += answer5.bounds.height + 8
        
        question6 = UILabel(frame: CGRect(x: 25, y: constantHeight, width: UIScreen.main.bounds.width - 50, height: 17))
        question6.text = "Can I invite my friends to sp0t?"
        question6.font = UIFont(name: "SFCamera-Semibold", size: 12)
        question6.textColor = UIColor(red: 0.898, green: 0.898, blue: 0.898, alpha: 1)
        scrollView.addSubview(question6)
        
        constantHeight += 20
        
        answer6 = UILabel(frame: CGRect(x: 25, y: constantHeight, width: UIScreen.main.bounds.width - 50, height: 18))
        answer6.text = "If you have interested friends, we’d love to have them beta test with you. Send us their name and email and we’ll send them an invite."
        answer6.font = UIFont(name: "SFCamera-Regular", size: 12)
        answer6.textColor = UIColor(red: 0.898, green: 0.898, blue: 0.898, alpha: 1)
        answer6.lineBreakMode = .byWordWrapping
        answer6.numberOfLines = 0
        answer6.sizeToFit()
        scrollView.addSubview(answer6)
        
        constantHeight += answer6.bounds.height + 8
        
        scrollView.contentSize = CGSize(width: UIScreen.main.bounds.width, height: answer6.frame.maxY + 20)
        
        
        if (self.uid == "kwpjnnDCSKcTZ0YKB3tevLI1Qdi2" || self.uid == "Za1OQPFoCWWbAdxB5yu98iE8WZT2") {
            let moreButton = UIButton(frame: CGRect(x: UIScreen.main.bounds.width/2 - 30, y: constantHeight + 10, width: 60, height: 20))
            moreButton.setImage(UIImage(named: "more"), for: UIControl.State.normal)
            moreButton.addTarget(self, action: #selector(moreTap), for: UIControl.Event.touchUpInside)
            scrollView.addSubview(moreButton)
        }
        
    }
    
    @objc func submitTap(){
        var feedback = ""
        
        if (!textView.text.isEmpty) {
            feedback = textView.text!
            let postID = UUID().uuidString
            self.db.collection("contact").document(postID).setData(["feedback" : feedback, "user" : self.uid])
            
            for sub in self.scrollView.subviews {
                sub.removeFromSuperview()
            }
            scrollView.isScrollEnabled = false
            
            let successLabel = UILabel(frame: CGRect(x: 20, y: 300, width: UIScreen.main.bounds.width - 40, height: 100))
            successLabel.text = "Thanks 🙏 🙏"
            successLabel.font = UIFont(name: "SFCamera-regular", size: 15)
            successLabel.textColor = UIColor.white
            successLabel.textAlignment = .center
            successLabel.lineBreakMode = .byWordWrapping
            scrollView.addSubview(successLabel)
            
            let successButton = UIButton(frame: CGRect(x: 100, y: 400, width: UIScreen.main.bounds.width - 200, height: 40))
            successButton.backgroundColor = nil
            successButton.titleLabel?.textColor = UIColor(named: "SpotGreen")
            successButton.setTitle("Return", for: UIControl.State.normal)
            successButton.layer.borderWidth = 1
            successButton.layer.borderColor = UIColor(named: "SpotGreen")?.cgColor
            successButton.layer.cornerRadius = 12
            successButton.titleLabel?.font = UIFont(name: "SFCamera-Semibold", size: 15)
            successButton.addTarget(self, action: #selector(returnToProfile), for: UIControl.Event.touchUpInside)
            scrollView.addSubview(successButton)
            
        }
        
    }
    
    @objc func returnToProfile(_ sender:UIButton) {
        navigationController?.popToRootViewController(animated: false)
    }
}
*/
