//
//  ProfileViewController.swift
//  Messenger
//
//  Created by Jack Walker on 11/17/22.
//

import UIKit
import FirebaseAuth
import FBSDKLoginKit
import GoogleSignIn
import SDWebImage

enum ProfileViewModelType {
    case info, logout
}

struct ProfileViewModel {
    let viewModelType: ProfileViewModelType
    let title: String
    let hanlder: (() -> Void)?
}

class ProfileViewController: UIViewController, UIImagePickerControllerDelegate & UINavigationControllerDelegate {
    
    @IBOutlet var tableView: UITableView!

    var data = [ProfileViewModel]()
    
    private var pictureButton = UIButton()
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        tableView.register(ProfileTableViewCell.self, forCellReuseIdentifier: ProfileTableViewCell.identifier)
        data.append(ProfileViewModel(viewModelType: .info,
                                     title: "Name: \(UserDefaults.standard.value(forKey: "name") as? String ?? "No Name")",
                                     hanlder: nil))
        data.append(ProfileViewModel(viewModelType: .info,
                                     title: "Email: \(UserDefaults.standard.value(forKey: "email") as? String ?? "No Email")",
                                     hanlder: nil))
        data.append(ProfileViewModel(viewModelType: .logout, title: "Log Out", hanlder: { [weak self] in
            guard let strongSelf = self else {
                return
            }
            let actionSheet = UIAlertController(title: "Log Out Confirmation",
                                                message: "Are you sure you want to log out?",
                                                preferredStyle: .actionSheet)
            actionSheet.addAction(UIAlertAction(title: "Log Out",
                                                style: .destructive,
                                                handler: { [weak self] _ in
                guard let strongSelf = self else {
                    return
                }
                
                UserDefaults.standard.set(nil, forKey: "email")
                UserDefaults.standard.set(nil, forKey: "name")
                
                FBSDKLoginKit.LoginManager().logOut()
                GIDSignIn.sharedInstance.signOut()
                do {
                    try FirebaseAuth.Auth.auth().signOut()
                    let vc = LoginViewController()
                    let nav = UINavigationController(rootViewController: vc)
                    nav.modalPresentationStyle = .fullScreen
                    nav.navigationBar.backgroundColor = .gray
                    strongSelf.present(nav, animated: false)
                }
                catch {
                    print("Failed to log out")
                }
            }))
            
            actionSheet.addAction(UIAlertAction(title: "Cancel",
                                                style: .cancel))
            strongSelf.present(actionSheet, animated: true)
            
        }))
        
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "cell")
        tableView.delegate = self
        tableView.dataSource = self
        tableView.tableHeaderView = createTableHeader()
    }
    
    func createTableHeader() -> UIView? {
        guard let email = UserDefaults.standard.value(forKey: "email") as? String else { return nil }
        let safeEmail = DatabaseManager.safeEmail(emailAddress: email)
        let fileName = safeEmail + "_profile_picture.png"
        let path = "images/" + fileName
        
        let headerView = UIView(frame: CGRect(x: 0,
                                        y: 0,
                                        width: self.view.width,
                                        height: 200))
        headerView.backgroundColor = .link
        
        pictureButton = UIButton(frame: CGRect(x: (view.width - 150) / 2,
                                                   y: 25,
                                                   width: 150,
                                                   height: 150))
        
        pictureButton.contentMode = .scaleAspectFill
        pictureButton.backgroundColor = .white
        pictureButton.layer.borderColor = UIColor.white.cgColor
        pictureButton.layer.borderWidth = 2
        pictureButton.layer.masksToBounds = true
        pictureButton.layer.cornerRadius = pictureButton.width/2
        pictureButton.addTarget(self, action: #selector(presentProfilePictureChange), for: .touchUpInside)
        
        headerView.addSubview(pictureButton)
        
        StorageManager.shared.downloadURL(for: path, completion: { [weak self] result in
            switch result {
            case .success(let url):
                self?.pictureButton.sd_setImage(with: url, for: .normal)
            case .failure(let error):
                print("Failed to get download url: \(error)")
            }
        })
        return headerView
    }
    
    @objc func presentProfilePictureChange(_ sender: UIButton) {
        let actionSheet = UIAlertController(title: "Change Profile Picture",
                                            message: "How do you want to upload a new profile picture?",
                                            preferredStyle: .actionSheet)
        actionSheet.addAction(UIAlertAction(title: "Upload Photo", style: .default, handler: { [weak self] _ in
            self?.presentPhotoPicker()
        }))
        actionSheet.addAction(UIAlertAction(title: "Take Photo", style: .default, handler: { [weak self] _ in
            self?.presentCamera()
        }))
        actionSheet.addAction(UIAlertAction(title: "Cancel", style: .destructive, handler: nil))
        present(actionSheet, animated: true)
    }
    
    func presentCamera() {
        let vc = UIImagePickerController()
        vc.sourceType = .camera
        vc.allowsEditing = true
        vc.delegate = self
        present(vc, animated: true)
    }
    
    func presentPhotoPicker() {
        let vc = UIImagePickerController()
        vc.sourceType = .photoLibrary
        vc.delegate = self
        vc.allowsEditing = true
        present(vc, animated: true)
    }
    
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
        picker.dismiss(animated: true, completion: nil)
        guard let selectedImage = info[UIImagePickerController.InfoKey.editedImage] as? UIImage else {
            return
        }
        pictureButton.setImage(selectedImage, for: .normal)
        updateProfilePicture(with: selectedImage)
    }
    
    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        picker.dismiss(animated: true, completion: nil)
    }
        
    func updateProfilePicture(with selectedImage: UIImage) {
        guard let firstName = UserDefaults.standard.value(forKey: "firstName") as? String else {
            print("No first name")
                  return }
        guard let lastName = UserDefaults.standard.value(forKey: "lastName") as? String else {
            print("no last name")
            return }
        guard let email = UserDefaults.standard.value(forKey: "email") as? String else {
            print("no email")
                  return }
        
        let chatUser = ChatAppUser(firstName: firstName,
                                   lastName: lastName,
                                   emailAddress: email)
        
        let fileName = chatUser.profilePictureFileName
        guard let data = selectedImage.pngData() else { print("no pngData")
            return }
        StorageManager.shared.uploadProfilePicture(with: data, fileName: fileName, completion: { result in
            switch result {
            case .success(let downloadURL):
                print("sucessfully updated profile picture in db")
                UserDefaults.standard.set(downloadURL, forKey: "profile_picture_url")
            case .failure(let error):
                print("Error upadting new image: \(error)")
            }
        })
    }
}

extension ProfileViewController: UITableViewDelegate, UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return data.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let viewModel = data[indexPath.row]
        let cell = tableView.dequeueReusableCell(withIdentifier: ProfileTableViewCell.identifier,
                                                 for: indexPath) as! ProfileTableViewCell
        cell.setup(with: viewModel)
        return cell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        data[indexPath.row].hanlder?()
    }
}

class ProfileTableViewCell: UITableViewCell {
    
    static let identifier = "ProfileTableViewCell"
    
    public func setup(with viewModel: ProfileViewModel) {
        textLabel?.text = viewModel.title
        switch viewModel.viewModelType {
        case .info:
            textLabel?.textAlignment = .left
            selectionStyle = .none
        case .logout:
            textLabel?.textColor = .red
            textLabel?.textAlignment = .center
        }
    }
}
