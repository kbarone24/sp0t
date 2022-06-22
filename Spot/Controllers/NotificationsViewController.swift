//
//  NotificationsController.swift
//  Spot
//
//  Created by kbarone on 8/15/19.
//  Copyright © 2019 sp0t, LLC. All rights reserved.
//

import Foundation
import UIKit
import Firebase
import Mixpanel
import FirebaseUI

class NotificationsController: UIViewController {
class NotificationsController: UIViewController, UITableViewDelegate, UITableViewDataSource {
    
    var notifications: [Notification] = []
    var tableView = UITableView()
    var tableData = ["Beach", "Clubs", "Chill", "Dance"]
    
    let db: Firestore! = Firestore.firestore()
    let uid: String = Auth.auth().currentUser?.uid ?? "invalid ID"
    
    var friendRequestListener: ListenerRegistration!
    var activityListener: ListenerRegistration!
    
    unowned var mapVC: MapController!
    
    

    
    override func viewDidLoad() {
        super.viewDidLoad()
        tableView = UITableView(frame: self.view.bounds, style: UITableView.Style.plain)
        tableView.dataSource = self
        tableView.delegate = self
        tableView.backgroundColor = UIColor.white
        
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "my")
        view.addSubview(tableView)
        // Do any additional setup after loading the view, typically from a nib.
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        
        let cell = tableView.dequeueReusableCell(withIdentifier: "my", for: indexPath)
        cell.textLabel?.text = "This is row \(tableData[indexPath.row])"
        
        return cell
        
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return tableData.count
    }

}
