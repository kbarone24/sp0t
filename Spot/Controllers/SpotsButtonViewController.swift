//
//  SpotsButtonViewController.swift
//
//
//  Created by nishit on 4/4/19.
//
import UIKit
import Firebase
import FirebaseFirestore

class SpotsButtonViewController: UIViewController {

    let db: Firestore! = Firestore.firestore()
    let id: String = Auth.auth().currentUser?.uid ?? "invalid ID"
    let email: String = Auth.auth().currentUser?.email ?? "Invalid User"
    var nameGlobal : String = "";
    var usernameGlobal : String = "";
    var nametestGlobal : String?;
    var usertestGlobal : String?;
    var navigationBarAppearace = UINavigationBar.appearance()
    var userHasImage = false
    var friends : String = "";
    var friendName : String = "";
    var spotInt = 0;
    var friendsInt = 0;
    var friendsArray = [String]()
    var spotsInt = 0;
    var spotsArray = [String]()
    var userBioString : String = "";
    var userHasBio = false
    var userURL : String = "";
    var friendsIntLabel = UILabel(frame: CGRect(x: 0, y: 0, width: 250, height: 100))

    
    
    @IBOutlet weak var label: UILabel!
    override func viewDidLoad() {
        super.viewDidLoad()

        
        // Do any additional setup after loading the view.
    }
    
    func reloadContent(_ buttonName: String){
        friendsIntLabel.removeFromSuperview()
        label.text = buttonName
    }
    
    func reloadFriends(_ Name: String) {
        label.text = ""
        print(Name)
        getFriends()
    }
    
    func reloadSpots () {
        
    }
    
    func getFriends() {
        self.db.collection("users").document(self.id).getDocument { (snapshot, err) in
            if let err = err {
                print("Error getting documents: \(err)")
            }else {
                
                //Getting number of friends
                self.friendsArray = snapshot?.get("friendsList") as! [String]
                self.friendsInt = self.friendsArray.count
                print ("Getting number of friends")
                print (self.friendsArray)
                
                if (self.friendsInt != 0){
                    print (self.friendsArray)
                    self.friends = self.friendsArray[0]
                    self.friends = String(self.friends)
                    
                    
                    self.findFriendName(friendId: self.friends)
                    
                }
                //find FriendName
                
                
            }
        }
    }
    
    func findFriendName(friendId: String) {
        print(friends)
        print("Entered function")
        friends = String (friends)
        self.db.collection("users").document(friendId).getDocument { (snapshot, err) in
            if let err = err {
                print("Error getting documents: \(err)")
            }else {
                print("\n I got to this point \n")
                self.friendName = snapshot?.get("name") as! String
                print (self.friendName)
                
                
                //Adding the friends number label
                self.friendsIntLabel.textAlignment = .center //For center alignment
                let friendsIntString = String(self.friendName)
                self.friendsIntLabel.text = friendsIntString
                self.friendsIntLabel.textColor = .green
                self.friendsIntLabel.font = UIFont.systemFont(ofSize: 14)
                self.view.addSubview(self.friendsIntLabel)
            }
        }
    }
    
    
    /*
     // MARK: - Navigation
     // In a storyboard-based application, you will often want to do a little preparation before navigation
     override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
     // Get the new view controller using segue.destination.
     // Pass the selected object to the new view controller.
     }
     */
    
}
