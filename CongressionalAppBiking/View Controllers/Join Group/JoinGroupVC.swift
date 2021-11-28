//
//  JoinGroupVC.swift
//  CongressionalAppBiking
//
//  Created by Saahil Sukhija on 7/8/21.
//

import UIKit
import GoogleSignIn
import FirebaseDatabase
import FirebaseAuth
import Firebase

class JoinGroupVC: UIViewController {

    @IBOutlet weak var joinGroupButton: RoundedButton!
    @IBOutlet weak var createGroupButton: RoundedButton!
    
    @IBOutlet weak var joinGroupView: UIView!
    @IBOutlet weak var joinGroupCodeTextField: UITextField!
    
    @IBOutlet weak var createGroupView: UIView!
    @IBOutlet weak var createGroupNameTextField: UITextField!
    
    @IBOutlet weak var goButton: RoundedButton!
    
    @IBOutlet weak var changeRiderType: UIButton!
    
    @IBOutlet weak var profileView: UIView!
    @IBOutlet weak var profilePicture: UIImageView!
    @IBOutlet weak var profileName: UILabel!
    @IBOutlet weak var profilePhoneNumber: UILabel!
    var emergencyPhoneNumber: String?
    
    var groupSelectionType: GroupSelectionType!
    var groupID: String?
    var groupName: String?
    var riderType: RiderType! = .rider
    
    var currentUser: User!
    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
        
        self.showLoggedIn()
        self.hideKeyboardWhenTappedAround()
        Authentication.addProfileChangesNotification()
        
        joinGroupView.isHidden = true
        joinGroupCodeTextField.addTarget(self, action: #selector(textFieldDidChange(_:)), for: .editingChanged)
        joinGroupCodeTextField.tag = 0
        
        createGroupView.isHidden = true
        createGroupNameTextField.delegate = self
        createGroupNameTextField.addTarget(self, action: #selector(textFieldDidChange(_:)), for: .editingChanged)
        createGroupNameTextField.tag = 1
        
        //Verify profile view
        profileView.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(goToVerifyProfileVC)))
        profileView.layer.cornerRadius = 10
        profileView.layer.borderWidth = 1
        profileView.layer.borderColor = UIColor.label.cgColor
        
        profilePicture.layer.cornerRadius = profilePicture.frame.size.width / 2
        profilePicture.layer.borderWidth = 1
        profilePicture.layer.borderColor = UIColor.label.cgColor
        
        joinGroupButtonClicked(self)
        
        updateChangeRiderTypeButton(with: "You are joining as a Rider. Change.")
        
        
    }
    
    @IBAction func goToMainPage(_ sender: Any) {
        
        //Make sure ride type is specified
        guard groupSelectionType != nil else {
            Alert.showDefaultAlert(title: "No Ride Type Selected", message: "Before continuing, you must select if you are creating a group or joining one.", self)
            return
        }
        
        //Joining existing group
        if groupSelectionType == .join {
            let loadingView = createLoadingScreen(frame: view.frame)
            view.addSubview(loadingView)
            Group.joinGroup(with: Int(joinGroupCodeTextField.text!)!, checkForExistingIDs: true) { completed, name in
                
                guard completed else {
                    self.showFailureToast(message: "Group does not exist.")
                    loadingView.removeFromSuperview()
                    return
                }
                
                self.groupName = name
                self.showSuccessToast(message: "Joined!")
                self.goToBikingVC()
                
                DispatchQueue.main.async {
                    loadingView.removeFromSuperview()
                }
            }
        }
        else if groupSelectionType == .create {
            createGroup()
        }
        
        
        
    }
    
    func goToBikingVC() {
        let loadingScreen = createLoadingScreen(frame: view.frame, message: "Initializing...")
        self.view.addSubview(loadingScreen)
        
        //Go to Next Page
        let storyboard = UIStoryboard(name: "MainPage", bundle: nil)
        var goToVC: BikingGroupVC!
        
        goToVC = storyboard.instantiateViewController(identifier: "bikingGroupScreen")
        goToVC.groupID = groupID
        goToVC.groupName = groupName
        UserLocationsUpload.uploadUserRideType(riderType, group: groupID!)
        Authentication.riderType = riderType
        //Locations.groupID = groupID
        let navigationController = UINavigationController(rootViewController: goToVC)
        navigationController.modalPresentationStyle = .fullScreen

        self.present(navigationController, animated: true, completion: nil)
        
        loadingScreen.removeFromSuperview()
    }
    
    
    @IBAction func joinGroupButtonClicked(_ sender: Any) {
        //Unselect Create Button
        createGroupButton.backgroundColor = .unselectedGrayColor
        createGroupView.isHidden = true
        
        joinGroupView.isHidden = false
        
        //Code must be entered before go button is clicked (if "join" is selected)
        if joinGroupCodeTextField.text!.count != 6 {
            removeActionFromButton(goButton)
            goButton.backgroundColor = .unselectedGrayColor
        } else {
            addActionToButton(goButton)
            goButton.backgroundColor = .selectedBlueColor
        }
        
        joinGroupButton.backgroundColor = .selectedBlueColor
        groupSelectionType = .join
    }
    
    @IBAction func createGroupButtonClicked(_ sender: Any) {
        //Unselect Join Button
        joinGroupButton.backgroundColor = .unselectedGrayColor
        joinGroupView.isHidden = true
        
        createGroupView.isHidden = false
        
        createGroupButton.backgroundColor = .selectedBlueColor
        
        //Name must be entered before go button is clicked (if "join" is selected)
        if createGroupNameTextField.text!.count == 0 {
            removeActionFromButton(goButton)
            goButton.backgroundColor = .unselectedGrayColor
        } else {
            addActionToButton(goButton)
            goButton.backgroundColor = .selectedBlueColor
        }
        
        groupSelectionType = .create
        
    }
    
    func createGroup() {
        let loadingView = createLoadingScreen(frame: view.frame)
        view.addSubview(loadingView)
        Group.generateGroupNumber { id in
            loadingView.removeFromSuperview()
            Group.uploadGroupName(self.createGroupNameTextField.text!, for: id)
            self.showSuccessToast(message: "Created group, ID: \(id)")
            self.groupName = self.createGroupNameTextField.text
            self.groupID = id
            self.goToBikingVC()
        }
    }
    
    @IBAction func changeRiderType(_ sender: Any) {
        let changeChoices = UIAlertController(title: "Change Ride Type", message: "Join as a specific role. Defaulted to Rider", preferredStyle: .actionSheet)
        changeChoices.view.tintColor = .accentColor
        
        changeChoices.addAction(UIAlertAction(title: "Rider", style: .default, handler: { [self] _ in
            riderType = .rider
            updateChangeRiderTypeButton(with: "You are joining as a Rider. Change.")
            NotificationCenter.default.post(name: .userIsRider, object: nil)
        }))
        changeChoices.addAction(UIAlertAction(title: "Non-Rider / Spectator", style: .default, handler: { [self] _ in
            riderType = .spectator
            updateChangeRiderTypeButton(with: "You are joining as a Non-Rider. Change.")
            NotificationCenter.default.post(name: .userIsNonRider, object: nil)
        }))
        
        
        changeChoices.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))
        self.present(changeChoices, animated: true, completion: nil)
        
    }
    
    func savedRideChosen(_ id: String) {
        joinGroupButtonClicked(self)
        joinGroupCodeTextField.text = id
        self.groupID = id
    }
    
    func updateChangeRiderTypeButton(with string: String) {
        let mutableTitle = NSMutableAttributedString(string: string, attributes: [NSAttributedString.Key.font : UIFont(name: "Sinhala Sangam MN", size: 20)!])
        mutableTitle.setColor(color: .accentColor, forText: "Change.")
        changeRiderType.setAttributedTitle(mutableTitle, for: .normal)
    }
    
    override func viewDidAppear(_ animated: Bool) {
        checkFirstLaunch()
        updateProfileView()
    }
    
    //Show Toast Saying "Welcome, (user)"
    func showLoggedIn() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            if Authentication.hasPreviousSignIn() {
                //Set Up User Object
                self.currentUser = Authentication.user
                self.showAnimationToast(animationName: "LoginSuccess", message: "Welcome, " + self.currentUser.displayName!, color: .systemBlue, fontColor: .systemBlue)
                
            }
        }
    }
    
    func updateProfileView() {
        profileView.isUserInteractionEnabled = false
        profileName.text = "Loading..."
        profilePhoneNumber.text = "Loading..."
        profilePicture.image = UIImage(systemName: "person.fill")
        
        StorageRetrieve().getGroupUser(from: Authentication.user?.email ?? "") { [self] groupUser in
            profileView.isUserInteractionEnabled = true
            guard let user = groupUser else { print("no user"); return }
            
            profileName.text = user.displayName
            emergencyPhoneNumber = user.emergencyPhoneNumber
            profilePhoneNumber.text = user.phoneNumber
            Authentication.phoneNumber = user.phoneNumber
            Authentication.emergencyPhoneNumber = user.emergencyPhoneNumber
            
            profilePicture.image = user.profilePicture?.toImage()
            
        }
        
    }
    
    @objc func goToVerifyProfileVC() {
        let vc = UIStoryboard(name: "InitialLaunch", bundle: nil).instantiateViewController(identifier: "additionalInfoScreen") as! AdditionalInfoVC
        vc.modalPresentationStyle = .fullScreen
        vc.setPhoneNumberField(profilePhoneNumber.text!)
        vc.setEmergencyPhoneNumberField(emergencyPhoneNumber ?? "")
        present(vc, animated: true)
    }

}

//MARK: Code Enter TextField
extension JoinGroupVC: UITextFieldDelegate {
    
    @objc func textFieldDidChange(_ textField: UITextField) {
        
        if textField.tag == 0 {
            if textField.text!.count > 6 {
                //Shorten text to 6.
                textField.text?.removeLast()
                textField.endEditing(true)
                
                goButton.backgroundColor = .selectedBlueColor
                addActionToButton(goButton)
                
                groupID = textField.text!
            } else if textField.text!.count == 6 {
                textField.endEditing(true)
                goButton.backgroundColor = .selectedBlueColor
                addActionToButton(goButton)
                
                groupID = textField.text!
            } else {
                goButton.backgroundColor = .unselectedGrayColor
                removeActionFromButton(goButton)
            }
        } else if textField.tag == 1 {
            if textField.text!.count > 0 {
                goButton.backgroundColor = .selectedBlueColor
                addActionToButton(goButton)
            } else {
                goButton.backgroundColor = .unselectedGrayColor
                removeActionFromButton(goButton)
            }
        }
    }
    
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        view.endEditing(true)
        
        return true
    }
}

//MARK: Initial Launch
extension JoinGroupVC {
    func checkFirstLaunch() {
        //Track if this is the first launch
        
        if !Authentication.hasPreviousSignIn() {
            UserDefaults.standard.setValue(true, forKey: "hasLaunched")
            
            //Initialize signup screen
            let storyboard = UIStoryboard(name: "InitialLaunch", bundle: nil)
            let signUpScreen = storyboard.instantiateViewController(withIdentifier: "loginScreen") as! LoginVC
            signUpScreen.modalPresentationStyle = .fullScreen
            
            self.present(signUpScreen, animated: true, completion: nil)
        }
    }
}

//MARK: Quality of life (cleanup) functions
extension JoinGroupVC {
    ///Grayed out Go Button not doing anything when clicked.
    func removeActionFromButton(_ button: UIButton, selector: Selector = #selector(goToMainPage)) {
        button.removeTarget(self, action: selector, for: .touchUpInside)
    }
    
    ///Add function back to go button
    func addActionToButton(_ button: UIButton, selector: Selector = #selector(goToMainPage)) {
        button.addTarget(self, action: selector, for: .touchUpInside)
    }
}

enum GroupSelectionType {
    case create
    case join
}

enum RiderType {
    case rider
    case spectator
}

extension UILabel {
    func setTextWhileKeepingAttributes(string: String) {
        if let newAttributedText = self.attributedText {
            let mutableAttributedText = newAttributedText.mutableCopy()

            (mutableAttributedText as AnyObject).mutableString.setString(string)

            self.attributedText = mutableAttributedText as? NSAttributedString
        }
    }
}
