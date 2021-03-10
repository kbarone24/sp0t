//
//  EventsOverviewController.swift
//  Spot
//
//  Created by kbarone on 12/11/19.
//  Copyright © 2019 sp0t, LLC. All rights reserved.
//

import Foundation
import UIKit
import Firebase
import CoreLocation

class EventsOverviewController: UIViewController {
    var event: Event!
    var currentLocation: CLLocation!
    var mainScroll: UIScrollView!
    
    override func viewDidLoad() {
        self.navigationItem.title = event.eventName
        Analytics.logEvent("EventsPageOpened", parameters: nil)
        
        mainScroll = UIScrollView(frame: view.frame)
        mainScroll.backgroundColor = UIColor(named: "SpotBlack")
        mainScroll.isScrollEnabled = true
        mainScroll.isUserInteractionEnabled = true
        mainScroll.showsVerticalScrollIndicator = false
        view.addSubview(mainScroll)

        var imageHeight: CGFloat = 0
        if event.eventImage != UIImage() {
            let aspect = event.eventImage!.size.height / event.eventImage!.size.width
            imageHeight = UIScreen.main.bounds.width * aspect
            
            let imageView = UIImageView(frame: CGRect(x: 0, y: -2, width: UIScreen.main.bounds.width, height: imageHeight))
            imageView.clipsToBounds = true
            imageView.image = event.eventImage!
            mainScroll.addSubview(imageView)
            
            let timeAndPrice = UILabel(frame: CGRect(x: 14, y: imageHeight + 5, width: 200, height: 16))
            timeAndPrice.font = UIFont(name: "SFCamera-Semibold", size: 14)
            timeAndPrice.textColor = UIColor(red:0.61, green:0.61, blue:0.61, alpha:1.0)
            timeAndPrice.text = formatDate(date: event.date, price: event.price)
            timeAndPrice.sizeToFit()
            mainScroll.addSubview(timeAndPrice)
            
            let eventName = UILabel(frame: CGRect(x: 13, y: imageHeight + 20, width: UIScreen.main.bounds.width - 26, height: 34))
            eventName.textColor = .white
            eventName.font = UIFont(name: "SFCamera-Semibold", size: 28)
            eventName.text = event.eventName
            eventName.lineBreakMode = .byWordWrapping
            eventName.numberOfLines = 0
            eventName.sizeToFit()
            mainScroll.addSubview(eventName)
            
            let spotName = UIButton(frame: CGRect(x: 15, y: eventName.frame.maxY, width: 150, height: 16))
            spotName.setTitleColor(UIColor(red:0.82, green:0.82, blue:0.82, alpha:1.0), for: .normal)
            spotName.titleLabel?.font = UIFont(name: "SFCamera-Semibold", size: 16)
            spotName.setTitle(event.spotName, for: .normal)
            spotName.addTarget(self, action: #selector(spotNameTap(_:)), for: .touchUpInside)
            let attTitle = NSAttributedString(string: (spotName.titleLabel?.text)!, attributes: [NSAttributedString.Key.kern: 0.5])
            spotName.setAttributedTitle(attTitle, for: .normal)
            spotName.sizeToFit()
            mainScroll.addSubview(spotName)
            
            let description = UILabel(frame: CGRect(x: 14, y: spotName.frame.maxY + 5, width: UIScreen.main.bounds.width - 28, height: 20))
            description.textColor = UIColor(red:0.82, green:0.82, blue:0.82, alpha:1.0)
            description.font = UIFont(name: "SFCamera-regular", size: 14)
            description.text = event.description
            description.numberOfLines = 0
            description.lineBreakMode = .byWordWrapping
            description.sizeToFit()
            mainScroll.addSubview(description)
            
            mainScroll.contentSize = CGSize(width: UIScreen.main.bounds.width, height: description.frame.maxY + 200)
        }
        
    }
    
    func formatDate(date: Date, price: Int) -> String {
        let rawDate = date
        var fullString = ""
        
        let dateFormatter1 = DateFormatter()
        var secondsFromGMT: Int { return TimeZone.current.secondsFromGMT() }
        dateFormatter1.timeZone = TimeZone(secondsFromGMT: secondsFromGMT)
        dateFormatter1.locale = NSLocale.current
        dateFormatter1.setLocalizedDateFormatFromTemplate("h:mm a")
        
        let dateFormatter2 = DateFormatter()
        dateFormatter2.timeZone = TimeZone(secondsFromGMT: secondsFromGMT)
        dateFormatter2.locale = NSLocale.current
        
        var tString = ""
        let calendar = Calendar.current
        if calendar.isDateInToday(rawDate) {
            tString = "Today"
        } else if calendar.isDateInTomorrow(rawDate) {
            tString = "Tomorrow"
        }
        
        if tString == "" {
            dateFormatter2.setLocalizedDateFormatFromTemplate("MMM d")
            let temp1 = dateFormatter1.string(from: rawDate)
            let temp2 = dateFormatter2.string(from: rawDate)
            fullString = "\(temp2) ∙ \(temp1)"
        } else {
            let temp = dateFormatter1.string(from: rawDate)
            fullString = "\(tString) ∙ \(temp)"
        }
        
        if price == 0 {
            fullString = "\(fullString) ∙ FREE"
            return fullString
        } else {
            fullString = "\(fullString) ∙ $\(price)"
            return fullString
        }
    }
    
    
    @objc func spotNameTap(_ sender: UIButton) {
        Analytics.logEvent("eventSpotNameTapped", parameters: nil)
        
        let storyboard = UIStoryboard(name: "SpotPage", bundle: nil)
        let vc = storyboard.instantiateViewController(withIdentifier: "SpotPage") as! SpotViewController
       
        vc.spotLat = event!.spotLat
        vc.spotLong = event!.spotLong
        vc.spotID = event!.spotID
        
        vc.navigationItem.backBarButtonItem?.title = ""
        
        self.navigationController!.pushViewController(vc, animated: true)
        
    }
}
