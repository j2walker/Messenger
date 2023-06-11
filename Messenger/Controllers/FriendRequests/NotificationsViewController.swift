//
//  NotificationsViewController.swift
//  Messenger
//
//  Created by Jack Walker on 6/6/23.
//

import UIKit
import JGProgressHUD

class NotificationsViewController: UIViewController {
    
    public var friendRequests: [FriendRequest]
    
    private let spinner = JGProgressHUD(style: .dark)
    
    weak var fetchDelegate: NotificationFetchDelegate?
    
    public let tableView: UITableView = {
        let table = UITableView()
        table.register(NotificationCell.self, forCellReuseIdentifier: NotificationCell.identifier)
        table.isHidden = true
        return table
    }()
    
    private let noNotificationsLabel: UILabel = {
        let label = UILabel()
        label.text = "No Notifications :)"
        label.textAlignment = .center
        label.textColor = .gray
        label.isHidden = true
        label.font = .systemFont(ofSize: 21, weight: .medium)
        return label
    }()

    override func viewDidLoad() {
        super.viewDidLoad()
        view.addSubview(tableView)
        setupTableView()
        view.backgroundColor = .secondarySystemBackground
        if friendRequests.isEmpty {
            showLoadingIndicator()
        } else {
            tableView.isHidden = false
            tableView.reloadData()
        }
        view.addSubview(noNotificationsLabel)
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        tableView.frame = view.bounds
        noNotificationsLabel.frame = CGRect(x: 10,
                                            y: (view.height-100)/2,
                                            width: view.width - 20,
                                            height: 100)
    }
    
    init(friendRequests: [FriendRequest]) {
        self.friendRequests = friendRequests
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder aDecoder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
    }
    
    private func setupTableView() {
        tableView.delegate = self
        tableView.dataSource = self
    }
    
    public func showLoadingIndicator() {
        spinner.show(in: view)
        spinner.isHidden = false
        tableView.isHidden = true
    }
    
    public func hideLoadingIndicator() {
        spinner.dismiss()
        spinner.isHidden = true
        tableView.isHidden = false
    }
    
    public func showNoNotifications() {
        tableView.isHidden = true
        noNotificationsLabel.isHidden = false
    }
    
    public func hideNoNotifications() {
        tableView.isHidden = false
        noNotificationsLabel.isHidden = true
    }
    
    private func deleteNotification(at indexPath: IndexPath) {
        friendRequests.remove(at: indexPath.row)
        tableView.reloadData()
    }
}

extension NotificationsViewController: UITableViewDelegate, UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return friendRequests.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let fr = friendRequests[indexPath.row]
        let cell = tableView.dequeueReusableCell(withIdentifier: NotificationCell.identifier, for: indexPath) as! NotificationCell
        cell.configure(with: fr)
        cell.toDelete = {
            self.deleteNotification(at: indexPath)
        }
        return cell
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 90
    }
}

protocol NotificationFetchDelegate: AnyObject {
    func fetchCompleted(requests: [FriendRequest])
}
