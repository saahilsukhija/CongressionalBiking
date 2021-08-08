//
//  AdditionalInfoVC.swift
//  CongressionalAppBiking
//
//  Created by Saahil Sukhija on 8/5/21.
//

import UIKit
import FirebaseAuth

class AdditionalInfoVC: UIViewController {

    @IBOutlet weak var nameTextField: UITextField!
    @IBOutlet weak var phoneNumberTextField: UITextField!
    @IBOutlet weak var pictureChangeView: UIView!
    @IBOutlet weak var profilePictureImageView: UIImageView!
    
    var currentUser: User!
    
    var phoneNumber: String!
    override func viewDidLoad() {
        super.viewDidLoad()
        self.hideKeyboardWhenTappedAround()
        
        //Differentiate between textfields for delegate
        nameTextField.tag = 0
        phoneNumberTextField.tag = 1
        
        nameTextField.returnKeyType = .next
        phoneNumberTextField.returnKeyType = .done
        
        nameTextField.delegate = self
        phoneNumberTextField.delegate = self
        
        phoneNumberTextField.addTarget(self, action: #selector(textFieldDidChange(_:)), for: .editingChanged)
        
        //Round view
        pictureChangeView.layer.cornerRadius = 10
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(imageChoice(_:)))
        pictureChangeView.addGestureRecognizer(tapGesture)
        
        //Round image view
        profilePictureImageView.layer.cornerRadius = profilePictureImageView.frame.size.width / 2
        profilePictureImageView.layer.borderWidth = 1
        profilePictureImageView.layer.borderColor = UIColor.label.cgColor
        
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        if Authentication.hasPreviousSignIn() {
            currentUser = Auth.auth().currentUser
            nameTextField.text = currentUser.displayName
            phoneNumberTextField.text = phoneNumber
            //Profile Picture
            if let photoURL = currentUser.photoURL {
                DispatchQueue.global().async {
                    let data = try? Data(contentsOf: photoURL)
                    DispatchQueue.main.async {
                        if let data = data {
                            self.profilePictureImageView.image = UIImage(data: data)
                        }
                    }
                }
            }
        }
        else {
            showFailureToast(message: "Something went wrong logging in. Try Again.")
            self.dismiss(animated: true, completion: nil)
        }
    }
    
    func setPhoneNumberField(_ phone: String) {
        self.phoneNumber = phone
    }
    
    @IBAction func completedButtonTapped(_ sender: Any) {
        currentUser = Authentication.user
        guard let image = profilePictureImageView.image else {
            self.showFailureToast(message: "No Profile Picture Chosen.")
            return
        }
        
        guard nameTextField.text != "" && phoneNumberTextField.text != "" else {
            self.showFailureToast(message: "Empty TextField")
            return
        }
        
        guard let imageURL = NSURL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("TempImage.png") else {
            return
        }

        let loadingScreen = createLoadingScreen(frame: view.frame)
        view.addSubview(loadingScreen)
        
        let pngData = image.pngData();
        do {
            try pngData?.write(to: imageURL);
        } catch { }
        
        let currentUserEditor = currentUser.createProfileChangeRequest()
        currentUserEditor.displayName = nameTextField.text!
        currentUserEditor.photoURL = imageURL
        
        currentUserEditor.commitChanges { [self] error in
            if let error = error {
                print(error.localizedDescription)
            }
            
            showAnimationToast(animationName: "LoginSuccess", message: "Welcome, \(currentUser.displayName!)")
            StorageUpload().uploadPhoneNumber(phoneNumberTextField.text!, user: currentUser) { completed in
                loadingScreen.removeFromSuperview()
                
                if completed {
                    dismiss(animated: true) {
                        Authentication.user = Auth.auth().currentUser
                        NotificationCenter.default.post(name: .additionalInfoCompleted, object: nil)
                    }
                } else {
                    showFailureToast(message: "Something went wrong...")
                }
            }
            
        }
        
    }
    

}

//MARK: -Image Pickers
extension AdditionalInfoVC: UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    @objc func imageChoice(_ sender: UIView) {
        let alert = UIAlertController(title: "Choose Image", message: nil, preferredStyle: .actionSheet)
        alert.addAction(UIAlertAction(title: "Camera", style: .default, handler: { _ in
            self.openCamera()
        }))
        
        alert.addAction(UIAlertAction(title: "Gallery", style: .default, handler: { _ in
            self.openGallery()
        }))
        
        alert.addAction(UIAlertAction.init(title: "Cancel", style: .cancel, handler: nil))
        
        /*If you want work actionsheet on ipad
         then you have to use popoverPresentationController to present the actionsheet,
         otherwise app will crash on iPad */
        switch UIDevice.current.userInterfaceIdiom {
        case .pad:
            alert.popoverPresentationController?.sourceView = sender
            alert.popoverPresentationController?.sourceRect = sender.bounds
            alert.popoverPresentationController?.permittedArrowDirections = .up
        default:
            break
        }
        
        self.present(alert, animated: true, completion: nil)
    }
    
    func openCamera() {
        let imagePickerController = UIImagePickerController()
        imagePickerController.delegate = self
        imagePickerController.sourceType = .camera
        imagePickerController.allowsEditing = true
        self.present(imagePickerController, animated: true, completion: nil)
        
    }
    
    func openGallery() {
        let imagePickerController = UIImagePickerController()
        imagePickerController.delegate = self
        imagePickerController.sourceType = .photoLibrary
        imagePickerController.allowsEditing = true
        self.present(imagePickerController, animated: true, completion: nil)
    }
    
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
        
        let image = info[.editedImage] as! UIImage
        profilePictureImageView.image = image
        picker.dismiss(animated: true, completion: nil)
    }
    
    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        picker.dismiss(animated:  true, completion: nil)
    }
    
    func cropImageToSquare(_ image: UIImage) -> UIImage {
        let orientation: UIDeviceOrientation = UIDevice.current.orientation
        var imageWidth = image.size.width
        var imageHeight = image.size.height
        switch orientation {
        case .landscapeLeft, .landscapeRight:
            // Swap width and height if orientation is landscape
            imageWidth = image.size.height
            imageHeight = image.size.width
        default:
            break
        }
        
        // The center coordinate along Y axis
        let rcy = imageHeight * 0.5
        let rect = CGRect(x: rcy - imageWidth * 0.5, y: 0, width: imageWidth, height: imageWidth)
        let imageRef = image.cgImage?.cropping(to: rect)
        return UIImage(cgImage: imageRef!, scale: 1.0, orientation: image.imageOrientation)
    }
    
}

//MARK: -Textfield Functions
extension AdditionalInfoVC: UITextFieldDelegate {
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        if textField.tag == 0 {
            //Is name enter
            phoneNumberTextField.becomeFirstResponder()
        } else if textField.tag == 1 {
            //Is phone number
            view.endEditing(true)
        }
        return true
    }
    
    //Reformat phone number text field to show proper phone number
    @objc func textFieldDidChange(_ textField: UITextField) {
        if textField.text!.count == 14 {
            view.endEditing(true)
        }
        textField.text = format(with: "(XXX) XXX-XXXX", phone: textField.text!)
    }
    
    /// mask example: `+X (XXX) XXX-XXXX`
    func format(with mask: String, phone: String) -> String {
        let numbers = phone.replacingOccurrences(of: "[^0-9]", with: "", options: .regularExpression)
        var result = ""
        var index = numbers.startIndex // numbers iterator

        // iterate over the mask characters until the iterator of numbers ends
        for ch in mask where index < numbers.endIndex {
            if ch == "X" {
                // mask requires a number in this place, so take the next one
                result.append(numbers[index])

                // move numbers iterator to the next index
                index = numbers.index(after: index)

            } else {
                result.append(ch) // just append a mask character
            }
        }
        return result
    }
    
}