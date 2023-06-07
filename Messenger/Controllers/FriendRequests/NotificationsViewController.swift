//
//  NotificationsViewController.swift
//  Messenger
//
//  Created by Jack Walker on 6/6/23.
//

import UIKit

class NotificationsViewController: UIViewController {
    
    private var friendRequests: [FriendRequest]
    
    private let tableView: UITableView = {
        let table = UITableView()
        table.register(UITableViewCell.self, forCellReuseIdentifier: "Cell")
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
        tableView.reloadData()
        tableView.isHidden = false
        view.backgroundColor = .secondarySystemBackground
        print(friendRequests)
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
}

extension NotificationsViewController: UITableViewDelegate, UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return friendRequests.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "Cell", for: indexPath)
        cell.textLabel?.text = friendRequests[indexPath.row].firstName + " " + friendRequests[indexPath.row].lastName
        cell.textLabel?.textColor = .white
        return cell
    }
}
