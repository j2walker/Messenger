//
//  NotificationTableViewCell.swift
//  Messenger
//
//  Created by Jack Walker on 6/11/23.
//

import UIKit
import SDWebImage

class NotificationCell: UITableViewCell {
    
    static let identifier = "NotificationCell"
    
    var friendSafeEmail = ""
    
    var toDelete: (() -> Void)?
    
    private let userImageView: UIImageView = {
        let image = UIImageView()
        image.contentMode = .scaleAspectFill
        image.layer.cornerRadius = 35
        image.layer.masksToBounds = true
        return image
    }()
    
    private let userNameLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 17, weight: .semibold)
        label.textAlignment = .center
        return label
    }()
    
    private let addBackButton: UIButton = {
        let button = UIButton()
        button.setBackgroundImage(UIImage(systemName: "plus.circle"), for: .normal)
        button.tintColor = .green
        return button
    }()
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        contentView.addSubview(userImageView)
        contentView.addSubview(userNameLabel)
        contentView.addSubview(addBackButton)
        addBackButton.addTarget(self, action: #selector(didTapAddBack), for: .touchUpInside)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        
        userImageView.frame = CGRect(x: 20,
                                     y: 10,
                                     width: 70,
                                     height: 70)
        userNameLabel.frame = CGRect(x: contentView.left,
                                     y: 20,
                                     width: contentView.width,
                                     height: 50)
        addBackButton.frame = CGRect(x: contentView.width - 50,
                                     y: 30,
                                     width: 30,
                                     height: 30)
    }
    
    @objc func didTapAddBack() {
        print("Tapped add back")
        FriendManager.shared.addFriendBack(with: friendSafeEmail, completion: { [weak self] value in
            guard let strongSelf = self else { return }
            if value {
                strongSelf.toDelete?()
            }
        })
    }
    
    public func configure(with fr: FriendRequest) {
        userNameLabel.text = fr.firstName + " " +  fr.lastName
        friendSafeEmail = fr.friendSafeEmail
        let path = "images/\(fr.friendSafeEmail)_profile_picture.png"
        StorageManager.shared.downloadURL(for: path, completion: { [weak self] result in
            switch result {
            case .success(let url):
                DispatchQueue.main.async {
                    self?.userImageView.sd_setImage(with: url, completed: nil)
                }
            case .failure(let error):
                print("Failed to get image URL with error: \(error)")
            }
        })
    }

}
