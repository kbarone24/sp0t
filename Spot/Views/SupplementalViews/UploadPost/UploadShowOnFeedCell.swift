//
//  UploadShowOnFeedCell.swift
//  Spot
//
//  Created by Kenny Barone on 9/22/21.
//  Copyright © 2021 sp0t, LLC. All rights reserved.
//

import Foundation
import UIKit
import Mixpanel

class UploadShowOnFeedCell: UITableViewCell {
    
    var icon: UIImageView!
    var topLine: UIView!
    var label: UILabel!
    var toggle: UIButton!
    
    var hide = false
    
    func setUp(hide: Bool) {
        
        backgroundColor = .black
        contentView.backgroundColor = .black
        
        self.hide = hide
        resetCell()
        
        topLine = UIView(frame: CGRect(x: 0, y: 0, width: UIScreen.main.bounds.width, height: 1))
        topLine.backgroundColor = UIColor(red: 0.129, green: 0.129, blue: 0.129, alpha: 1)
        contentView.addSubview(topLine)
        
        icon = UIImageView(frame: CGRect(x: 14, y: 12, width: 28, height: 25))
        icon.image = UIImage(named: "ShowOnFeedIcon")
        icon.contentMode = .scaleAspectFit
        contentView.addSubview(icon)
        
        if label != nil { label.text = "" }
        label = UILabel(frame: CGRect(x: 49, y: 15, width: 150, height: 18))
        label.text = "Post to friends feed"
        label.textColor = UIColor(red: 0.471, green: 0.471, blue: 0.471, alpha: 1)
        label.font = UIFont(name: "SFCamera-Regular", size: 13.5)
        contentView.addSubview(label)
        
        toggle = UIButton(frame: CGRect(x: UIScreen.main.bounds.width - 71.5, y: 5, width: 57.5, height: 38))
        let image = hide ? UIImage(named: "HideToggleOff") : UIImage(named: "HideToggleOn")
        toggle.setImage(image, for: .normal)
        toggle.imageEdgeInsets = UIEdgeInsets(top: 5, left: 5, bottom: 5, right: 5)
        toggle.addTarget(self, action: #selector(toggle(_:)), for: .touchUpInside)
        contentView.addSubview(toggle)
     
    }
    
    func resetCell() {
        if topLine != nil { topLine.backgroundColor = nil }
        if icon != nil { icon.image = UIImage() }
        if toggle != nil { toggle.setImage(UIImage(), for: .normal) }

    }
    
    @objc func toggle(_ sender: UIButton) {
        
        hide = !hide
        let image = hide ? UIImage(named: "HideToggleOff") : UIImage(named: "HideToggleOn")
        toggle.setImage(image, for: .normal)
        
        guard let uploadVC = viewContainingController() as? UploadPostController else { return }
        uploadVC.postObject.hideFromFeed = hide
        
        let event = hide ? "HideToggleOff" : "HideToggleOn"
        Mixpanel.mainInstance().track(event: event)
    }
}
