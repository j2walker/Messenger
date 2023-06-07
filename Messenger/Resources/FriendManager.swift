//
//  Friend.swift
//  Messenger
//
//  Created by Jack Walker on 2/28/23.
//

import Foundation
import FirebaseDatabase
import CoreLocation

struct FriendRequest {
    public var friendSafeEmail: String
    public var sentAt: Date
    public var firstName: String
    public var lastName: String
}

final class FriendManager {
    static let shared = FriendManager()
    
    private let database = Database.database().reference()
    
    // MARK: Adding Friend
    // Function called when adding a friend in the UI
    public func addFriend(with friendsSafeEmail: String, completion: @escaping (Bool)->Void) {
        let email = UserDefaults.standard.value(forKey: "email")
        guard let email = email as? String else {
            completion(false)
            return
        }
        let safeEmail = DatabaseManager.safeEmail(emailAddress: email)
        database.child("\(safeEmail)/friends/\(friendsSafeEmail)").observeSingleEvent(of: .value, with: { [weak self] snapshot in
            guard let strongSelf = self else { return }
            if snapshot.exists() {
                // friend exists already, do nothing
                completion(false)
            } else {
                // friend doesn't exist, send friend request
                // needs to be handled by friend once they accept
//                self?.database.child("\(safeEmail)/friends/\(friendsSafeEmail)").setValue(true)
                let friendsKnowObj = strongSelf.createFriendKnowledgeObj()
                guard let friendsKnowObj = friendsKnowObj else { return }
                var userKnowObj = [String: Any]()
                userKnowObj["to"] = friendsSafeEmail
                userKnowObj["accepted"] = false
                strongSelf.uploadKnowledgeObjects(friendsKnowObj: friendsKnowObj, userKnowObj: userKnowObj, friendsSafeEmail: friendsSafeEmail, completion: { result in
                    if result {
                        completion(true)
                    } else {
                        completion(false)
                    }
                })
            }
        })
    }
    
    // Creates the friend's knowledge object, has two values: from and time
    private func createFriendKnowledgeObj()->([String: String])? {
        guard let email = UserDefaults.standard.value(forKey: "email") as? String else { return nil }
        let safeEmail = DatabaseManager.safeEmail(emailAddress: email)
        var friendKnowObj = [String: String]()
        friendKnowObj["from"] = safeEmail
        friendKnowObj["time"] = Utilities.getCurrentNumericTimeAsString()
        return friendKnowObj
    }
    
    // Uploads both the friend and the user's friend request knowledge objects
    private func uploadKnowledgeObjects(friendsKnowObj: [String: String], userKnowObj: [String: Any], friendsSafeEmail: String, completion: @escaping(Bool)->Void) {
        guard let email = UserDefaults.standard.value(forKey: "email") as? String else {
            completion(false)
            return
        }
        let safeEmail = DatabaseManager.safeEmail(emailAddress: email)
        let friendfReqRef = database.child("\(friendsSafeEmail)").child("friendReqs")
        let userfReqSentRef = database.child("\(safeEmail)").child("friendReqsSent")
        
        friendfReqRef.observeSingleEvent(of: .value, with: { snapshot in
            if snapshot.exists() {
                guard var friendReqs = snapshot.value as? [[String: String]] else {
                    completion(false)
                    return
                }
                friendReqs.append(friendsKnowObj)
                friendfReqRef.setValue(friendReqs)
            } else {
                let initialRequests = [friendsKnowObj]
                friendfReqRef.setValue(initialRequests)
            }
            userfReqSentRef.observeSingleEvent(of: .value, with: { snapshot in
                if (snapshot.exists()) {
                    guard var sentReqs = snapshot.value as? [[String: Any]] else {
                        completion(false)
                        return
                    }
                    sentReqs.append(userKnowObj)
                    userfReqSentRef.setValue(sentReqs)
                    
                } else {
                    let initialRequests = [userKnowObj]
                    userfReqSentRef.setValue(initialRequests)
                }
                completion(true)
            })
        })
    }
    
    public func getAllFriendRequests(completion: @escaping(Result<[FriendRequest], Error>)->Void) {
        guard var safeEmail = UserDefaults.standard.value(forKey: "email") as? String else {
            completion(.failure(FriendManagerErrors.failedToFetchRequests)) // not really
            return
        }
        safeEmail = DatabaseManager.safeEmail(emailAddress: safeEmail)
        database.child("\(safeEmail)/friendReqs").observe(.value, with: { [weak self] snapshot in
            guard let requests = snapshot.value as? [[String: String]], let strongSelf = self else {
                completion(.failure(FriendManagerErrors.failedToFetchRequests))
                return
            }
            let dispatchGroup = DispatchGroup()
            var allRequests = [FriendRequest]()
            for request in requests {
                guard let sender = request["from"] as? String,
                      let time = request["time"] as? String else {
                    completion(.failure(FriendManagerErrors.failedToFetchRequests))
                    return
                }
                let timeAsDate = Utilities.getDateFromString(utcTimeString: time)
                guard let timeAsDate = timeAsDate as? Date else {
                    completion(.failure(FriendManagerErrors.failedToFetchRequests))
                    return
                }
                dispatchGroup.enter()
                strongSelf.database.child("\(sender)").observeSingleEvent(of: .value, with: { snapshot in
                    if let userData = snapshot.value as? [String: Any],
                       let firstName = userData["firstName"] as? String,
                       let lastName = userData["lastName"] as? String {
                        let friendRequest = FriendRequest(friendSafeEmail: sender, sentAt: timeAsDate, firstName: firstName, lastName: lastName)
                        allRequests.append(friendRequest)
                    }
                    dispatchGroup.leave()
                })
            }
            dispatchGroup.notify(queue: .main) {
                completion(.success(allRequests))
            }
        })
    }
    
    public func removeFriend(with friendsSafeEmail: String, completion: @escaping (Bool)->Void) {
        let email = UserDefaults.standard.value(forKey: "email")
        guard let email = email as? String else {
            return
        }
        let safeEmail = DatabaseManager.safeEmail(emailAddress: email)
        database.child("\(safeEmail)/friends/\(friendsSafeEmail)").observeSingleEvent(of: .value, with: { [weak self] snapshot in
            if snapshot.exists() {
                // friend exists already, do nothing
                self?.database.child("\(safeEmail)/friends/\(friendsSafeEmail)").removeValue()
                completion(true)
            } else {
                // friend doesn't exists, add to friends
                completion(false)
            }
            
        })
    }
    
    public func updateFriend(with friendsSafeEmail: String, update: Bool, completion: @escaping (Bool)->Void) {
        let email = UserDefaults.standard.value(forKey: "email")
        guard let email = email as? String else {
            return
        }
        let safeEmail = DatabaseManager.safeEmail(emailAddress: email)
        database.child("\(safeEmail)/friends/\(friendsSafeEmail)").observeSingleEvent(of: .value, with: { [weak self] snapshot in
            if snapshot.exists() {
                // friend exists already, do nothing
                self?.database.child("\(safeEmail)/friends/\(friendsSafeEmail)").setValue(update)
                completion(true)
            } else {
                // friend doesn't exists, add to friends
                completion(false)
            }
        })
    }
    
    public func isFriends(with friendsSafeEmail: String, completion: @escaping (Bool)->Void) {
        let email = UserDefaults.standard.value(forKey: "email")
        guard let email = email as? String else {
            return
        }
        let safeEmail = DatabaseManager.safeEmail(emailAddress: email)
        database.child("\(safeEmail)/friends/\(friendsSafeEmail)").observeSingleEvent(of: .value, with: { snapshot in
            completion(snapshot.exists())
        })
    }
    
    public func getFriendsLocations(completion: @escaping([String:CLLocationCoordinate2D]?)->Void) {
        let email = UserDefaults.standard.value(forKey: "email")
        guard let email = email as? String else { return }
        let safeEmail = DatabaseManager.safeEmail(emailAddress: email)
        database.child("\(safeEmail)/friends").observeSingleEvent(of: .value, with: { [weak self] snapshot in
            guard let snapshotValue = snapshot.value as? [String:Bool], let self = self else { return }
            var friendsDict: [String: CLLocationCoordinate2D] = [:]
            let dispatchGroup = DispatchGroup()
            
            for (key, _) in snapshotValue {
                dispatchGroup.enter()
                self.retrieveLocation(with: key, completion: { location in
                    friendsDict[key] = location
                    dispatchGroup.leave()
                })
            }
            dispatchGroup.notify(queue: .main) {
                completion(friendsDict)
            }
        })
    }
    
    private func retrieveLocation(with safeEmail: String, completion: @escaping(CLLocationCoordinate2D)->Void) {
        database.child("\(safeEmail)/currentLocation/currentLocation").observeSingleEvent(of: .value, with: { snapshot in
            guard let coordinatesString = snapshot.value as? String else { return }
            let components = coordinatesString.components(separatedBy: ",")
            guard let latitude = Double(components[1]), let longitude = Double(components[0]) else { return }
            let coordinates = CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
            completion(coordinates)
        })
    }
    
    public func retrieveFriendName(with safeEmail: String, completion: @escaping(String)->Void) {
        database.child("\(safeEmail)/firstName").observeSingleEvent(of: .value, with: { [weak self] snapshot in
            guard let firstName = snapshot.value as? String else { return }
            self?.database.child("\(safeEmail)/lastName").observeSingleEvent(of: .value, with: { snapshot in
                guard let lastName = snapshot.value as? String else { return }
                    completion(firstName + " " + lastName)
            })
        })
    }
    
    public enum FriendManagerErrors: Error {
        case failedToFetchRequests
    }
    
}

