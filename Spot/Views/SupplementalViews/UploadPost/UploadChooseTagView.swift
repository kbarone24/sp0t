//
//  UploadChooseTagCell.swift
//  Spot
//
//  Created by Kenny Barone on 9/16/21.
//  Copyright © 2021 sp0t, LLC. All rights reserved.
//

import Foundation
import UIKit

protocol ChooseTagDelegate {
    func finishPassingTag(tag: Tag)
}

class UploadChooseTagView: UIView {
    
    var chooseTagCollection: UICollectionView  = UICollectionView(frame: CGRect.zero, collectionViewLayout: UICollectionViewFlowLayout.init())
    var tags: [Tag] = [Tag(name: "Active"), Tag(name: "Art"), Tag(name: "Boogie"), Tag(name: "Chill"), Tag(name: "Coffee"), Tag(name: "Drink"), Tag(name: "Eat"), Tag(name: "Historic"), Tag(name: "Home"), Tag(name: "Nature"), Tag(name: "Shop"), Tag(name: "Smoke"), Tag(name: "Sunset"), Tag(name: "Swim"), Tag(name: "View"), Tag(name: "Weird")]
    var delegate: ChooseTagDelegate?

    func setUp(tag: String) {
        
        backgroundColor = UIColor(named: "SpotBlack")
        
        resetView()
                
        let layout = UICollectionViewFlowLayout()
        layout.scrollDirection = .horizontal
        layout.itemSize = CGSize(width: 40, height: 40)
        layout.minimumLineSpacing = 8
        layout.minimumInteritemSpacing = 8
        layout.sectionInset = UIEdgeInsets(top: 0, left: 13, bottom: 0, right: 13)
        
        chooseTagCollection.frame = CGRect(x: 0, y: 30, width: UIScreen.main.bounds.width, height: 89)
        chooseTagCollection.backgroundColor = nil
        chooseTagCollection.delegate = self
        chooseTagCollection.dataSource = self
        chooseTagCollection.register(UploadTagCell.self, forCellWithReuseIdentifier: "TagCell")
        chooseTagCollection.showsHorizontalScrollIndicator = false
        chooseTagCollection.setCollectionViewLayout(layout, animated: false)
        addSubview(chooseTagCollection)
        
        if tag != "", let index = tags.firstIndex(where: {$0.name == tag}) { tags[index].selected = true }
        chooseTagCollection.reloadData()
    }
        
    func resetView() {
       // chooseTagCollection.removeFromSuperview()
    }
}

extension UploadChooseTagView: UICollectionViewDelegate, UICollectionViewDataSource, UICollectionViewDelegateFlowLayout {
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return tags.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        
        guard let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "TagCell", for: indexPath) as? UploadTagCell else { return UICollectionViewCell() }
        cell.setUp(tag: tags[indexPath.row])
        
        let alpha: CGFloat = tags.contains(where: {$0.selected}) && !tags[indexPath.row].selected ? 0.6 : 1.0
        cell.setAlphas(alpha: alpha)
        
        return cell
    }
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        print("select")
        var tag = tags[indexPath.row]
        tag.selected = !tag.selected
        delegate?.finishPassingTag(tag: tag)
    }
}

class UploadTagCell: UICollectionViewCell {
    
    var tagImage: UIImageView!
    var postTag: Tag!
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        
        layer.borderWidth = 1
        layer.cornerRadius = 7.5
        layer.cornerCurve = .continuous
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func setUp(tag: Tag) {
        
        postTag = tag
        
        if tagImage != nil { tagImage.image = UIImage() }
        tagImage = UIImageView(frame: CGRect(x: 9, y: 9, width: 24, height: 24))
        tagImage.image = tag.image
        addSubview(tagImage)
    }
    
    func setAlphas(alpha: CGFloat) {
        tagImage.alpha = alpha
        backgroundColor = postTag.selected ? UIColor(red: 0.00, green: 0.09, blue: 0.09, alpha: 1.00) : UIColor(red: 0.094, green: 0.094, blue: 0.094, alpha: 1).withAlphaComponent(alpha)
        layer.borderColor = postTag.selected ? UIColor(named: "SpotGreen")!.cgColor : UIColor(red: 0.112, green: 0.112, blue: 0.112, alpha: 1).cgColor
    }
}
