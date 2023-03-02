//
//  ConversationTableViewCell.swift
//  Messenger
//
//  Created by Jack Walker on 11/22/22.
//

import UIKit
import SDWebImage

class ConversationTableViewCell: UITableViewCell {
    
    static let identifer = "ConversationTableViewCell"
    
    private let userImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFill
        imageView.layer.cornerRadius = 50
        imageView.layer.masksToBounds = true
        return imageView
    }()
    
    private let userNameLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 22, weight: .semibold)
        return label
    }()
    
    private let userMessageLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 19, weight: .regular)
        label.numberOfLines = 0
        return label
    }()
    

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        contentView.addSubview(userImageView)
        contentView.addSubview(userNameLabel)
        contentView.addSubview(userMessageLabel)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        
        userImageView.frame = CGRect(x: 10,
                                     y: 10,
                                     width: 100,
                                     height: 100)
        userNameLabel.frame = CGRect(x: userImageView.right + 10,
                                     y: 5,
                                     width: contentView.width - 20 - userImageView.width,
                                     height: (contentView.height - 20) / 2)
        userMessageLabel.frame = CGRect(x: userImageView.right + 10,
                                        y: userNameLabel.bottom - 15,
                                     width: contentView.width - 20 - userImageView.width,
                                     height: (contentView.height - 20) / 2)
    }
    
    public func configure(with model: Conversation) {
        
        guard let kind = model.latestMessage.kind as String? else {
            return
        }
        
        var previewText = ""
        
        switch kind {
        case "test":
            previewText = model.latestMessage.text
        case "attributed_text":
            break
        case "photo":
            previewText = "Attachment: 1 Photo"
            break
        case "video":
            previewText = "Attachment: 1 Video"
            break
        case "location":
            previewText = "Attachment: 1 Location"
            break
        case "emoji":
            break
        case "audio":
            break
        case "contact":
            break
        case "linkPreview":
            break
        case "custom":
            break
        default:
            previewText = model.latestMessage.text
        }
        
        userMessageLabel.text = previewText
        userNameLabel.text = model.name
        
        let path = "images/\(model.otherUserEmail)_profile_picture.png"
        StorageManager.shared.downloadURL(for: path, completion: { [weak self] result in
            switch result {
            case .success(let url):
                DispatchQueue.main.async {
                    self?.userImageView.sd_setImage(with: url, completed: nil)
                }
            case .failure(let error):
                print("Failed to get image url: \(error)")
            }
        })
    }
}
