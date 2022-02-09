//
//  ActiveFilterView.swift
//  Spot
//
//  Created by Kenny Barone on 1/17/22.
//  Copyright © 2022 sp0t, LLC. All rights reserved.
//

import Foundation
import UIKit
import FirebaseUI

class ActiveFilterView: UIView {
    
    var closeButton: UIButton!
    var filterName: UILabel!
    var filterimage: UIImageView!
    
    override init(frame: CGRect) {
        super.init(frame: frame)
    }
    
    deinit {
        filterimage.sd_cancelCurrentImageLoad()
    }
    
    func setUpFilter(name: String, image: UIImage, imageURL: String) {
        
        backgroundColor =  UIColor(red: 0.58, green: 0.58, blue: 0.58, alpha: 0.65)
        layer.borderColor = UIColor(red: 0.93, green: 0.93, blue: 0.93, alpha: 1.00).cgColor
        layer.borderWidth = 1
        layer.cornerRadius = 7.5

        filterimage = UIImageView(frame: CGRect(x: 8, y: 5, width: 20, height: 20))
        filterimage.backgroundColor = nil
        
        /// get from image url for user profile picture or  tag from db
        if image == UIImage() {
            /// returns same URL for profile pic, fetches new one for tag from DB
            getImageURL(name: name, imageURL: imageURL) { [weak self] url in
                guard let self = self else { return }
                if url == "" { return }
                
                let transformer = SDImageResizingTransformer(size: CGSize(width: 70, height: 70), scaleMode: .aspectFill)
                self.filterimage.sd_setImage(with: URL(string: url), placeholderImage: nil, options: .highPriority, context: [.imageTransformer: transformer], progress: nil) { [weak self] (image, _, _, _) in
                    guard let self = self else { return }
                    if image != nil { self.filterimage.image = image!}
                    self.filterimage.layer.cornerRadius = 10
                    self.filterimage.layer.masksToBounds = true
                }
            }
        } else { filterimage.image = image }
        
        filterimage.contentMode = .scaleAspectFit
        self.addSubview(filterimage)
        
        filterName = UILabel(frame: CGRect(x: filterimage.frame.maxX + 5, y: 8, width: 40, height: 15))
        filterName.text = name
        filterName.font = UIFont(name: "SFCompactText-Semibold", size: 12)
        filterName.textColor = .white
        if image == UIImage() { filterName.sizeToFit() }
        self.addSubview(filterName)
        
        closeButton = UIButton(frame: CGRect(x: bounds.width - 29, y: 1, width: 28, height: 28))
        closeButton.imageEdgeInsets = UIEdgeInsets(top: 6, left: 6, bottom: 6, right: 6)
        closeButton.setImage(UIImage(named: "CheckInX"), for: .normal)
        self.addSubview(closeButton)
    }
    
    func getImageURL(name: String, imageURL: String, completion: @escaping (_ URL: String) -> Void) {
        if imageURL != "" { completion(imageURL); return }
        let tag = Tag(name: name)
        tag.getImageURL { url in
            completion(url)
        }
    }

    required init(coder: NSCoder) {
        fatalError()
    }
    
}

