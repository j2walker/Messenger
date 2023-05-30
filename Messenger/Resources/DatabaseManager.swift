//
//  DatabaseManager.swift
//  Messenger
//
//  Created by Jack Walker on 11/18/22.
//

import Foundation
import FirebaseDatabase
import MessageKit
import CoreLocation

final class DatabaseManager {
    static let shared = DatabaseManager()
    private let database = Database.database().reference()
    
    static func safeEmail(emailAddress: String) -> String {
        var safeEmail = emailAddress.replacingOccurrences(of: ".", with: "-")
        safeEmail = safeEmail.replacingOccurrences(of: "@", with: "-")
        return safeEmail
    }
}

extension DatabaseManager {
    
    public func getDataFor(path: String, completion: @escaping (Result<Any, Error>) -> Void) {
        database.child("\(path)").observeSingleEvent(of: .value, with: { snapshot in
            guard let value = snapshot.value else {
                completion(.failure(DatabseError.failedToFetch))
                return
            }
            completion(.success(value))
        })
    }
    
}

// MARK: - Acount Mgmt

extension DatabaseManager {
    
    public func userExists(with email: String, completion: @escaping ((Bool) -> Void)) {
        let safeEmail = DatabaseManager.safeEmail(emailAddress: email)
        database.child(safeEmail).observeSingleEvent(of: .value, with: { snapshot in
            guard snapshot.value as? [String: Any] != nil else {
                completion(false)
                return
            }
            completion(true)
        })
    }
    
    /// Inserts new user to database
    public func insertUser(with user: ChatAppUser, completion: @escaping (Bool) -> Void) {
        database.child(user.safeEmail).setValue([
            "firstName" : user.firstName,
            "lastName" : user.lastName
        ], withCompletionBlock: { [weak self] error, _ in
            
            guard let strongSelf = self else {
                return
            }
            
            guard error == nil else {
                print("Failed to write to database")
                completion(false)
                return
            }
            
            strongSelf.database.child("users").observeSingleEvent(of: .value, with: { snapshot in
                if var usersCollection = snapshot.value as? [[String: String]] {
                    // append to user array
                    let newElement = ["name" : user.firstName + " " + user.lastName,
                                      "email" : user.safeEmail
                    ]
                    usersCollection.append(newElement)
                    
                    strongSelf.database.child("users").setValue(usersCollection, withCompletionBlock: { error, _ in
                        guard error == nil else {
                            completion(false)
                            return
                        }
                        completion(true)
                    })
                }
                else {
                    // create array of users
                    let newCollection: [[String: String]] = [
                        ["name" : user.firstName + " " + user.lastName,
                         "email" : user.safeEmail
                        ]
                    ]
                    strongSelf.database.child("users").setValue(newCollection, withCompletionBlock: { error, _ in
                        guard error == nil else {
                            completion(false)
                            return
                        }
                        completion(true)
                    })
                }
            })
        })
    }
    
    public func getAllUsers(completion: @escaping (Result<[[String: String]], Error>) -> Void) {
        database.child("users").observeSingleEvent(of: .value, with: { snapshot in
            guard let value = snapshot.value as? [[String: String]] else {
                completion(.failure(DatabseError.failedToFetch))
                return
            }
            completion(.success(value))
        })
    }
    
    public enum DatabseError: Error {
        case failedToFetch
    }
    
}

// MARK: - Sending Messages / conversations
extension DatabaseManager {
    
    /// Creates a new conversation with target user email and first message sent
    public func createNewConversation(with otherUserEmail: String, name: String, firstMessage: Message, completion: @escaping (Bool) -> Void) {
        guard let currentEmail = UserDefaults.standard.value(forKey: "email") as? String,
              let currentName = UserDefaults.standard.value(forKey: "name") as? String else {
            return
        }
        let safeEmail = DatabaseManager.safeEmail(emailAddress: currentEmail)
        let ref = database.child("\(safeEmail)")
        
        ref.observeSingleEvent(of: .value, with: { [weak self] snapshot in
            guard var userNode = snapshot.value as? [String: Any] else {
                completion(false)
                print("fatal: user not found")
                return
            }
            
            let messageDate = firstMessage.sentDate
            let dateString = ChatViewController.dateFormatter.string(from: messageDate)
            let kind = firstMessage.kind
            
            var message = ""
            
            switch firstMessage.kind {
            case .text(let messageText):
                message = messageText
            case .attributedText(_):
                break
            case .photo(_):
                break
            case .video(_):
                break
            case .location(_):
                break
            case .emoji(_):
                break
            case .audio(_):
                break
            case .contact(_):
                break
            case .linkPreview(_):
                break
            case .custom(_):
                break
            }
            
            let conversationID = "conversation_\(firstMessage.messageId)"
            
            let newConversationData: [String: Any] = [
                "id": conversationID,
                "other_user_email": otherUserEmail,
                "name": name,
                "latest_message": [
                    "date": dateString,
                    "message": message,
                    "is_read": false,
                    "kind" : kind.messageKindString
                ]
            ]
            
            let receipient_newConversationData: [String: Any] = [
                "id": conversationID,
                "other_user_email": safeEmail,
                "name": currentName,
                "latest_message": [
                    "date": dateString,
                    "message": message,
                    "is_read": false,
                    "kind" : kind.messageKindString
                ]
            ]
            
            // Update recipient conversation entry
            self?.database.child("\(otherUserEmail)/conversations").observeSingleEvent(of: .value, with: { [weak self] snapshot in
                if var conversations = snapshot.value as? [[String : Any]] {
                    // append
                    conversations.append(receipient_newConversationData)
                    self?.database.child("\(otherUserEmail)/conversations").setValue(conversations)
                }
                else {
                    // create
                    self?.database.child("\(otherUserEmail)/conversations").setValue([receipient_newConversationData])
                }
            })
            
            // Update current user conversation entry
            if var conversations = userNode["conversations"] as? [[String: Any]] {
                // conversation array exists for current user
                // you should append
                conversations.append(newConversationData)
                userNode["conversations"] = conversations
                ref.setValue(userNode, withCompletionBlock: { [weak self] error, _ in
                    guard error == nil else {
                        completion(false)
                        return
                    }
                    self?.finishCreatingConversation(name: name,
                                                     conversationID: conversationID,
                                                     firstMessage: firstMessage,
                                                     completion: completion)
                })
            } else {
                // conversation array does not exist, create it
                userNode["conversations"] = [newConversationData]
                ref.setValue(userNode, withCompletionBlock: { [weak self] error, _ in
                    guard error == nil else {
                        completion(false)
                        return
                    }
                    self?.finishCreatingConversation(name: name,
                                                     conversationID: conversationID,
                                                     firstMessage: firstMessage,
                                                     completion: completion)
                })
            }
        })
    }
    
    private func finishCreatingConversation(name: String, conversationID: String, firstMessage: Message, completion: @escaping (Bool) -> Void) {
        
        let messageDate = firstMessage.sentDate
        let dateString = ChatViewController.dateFormatter.string(from: messageDate)
        
        var message = ""
        switch firstMessage.kind {
        case .text(let messageText):
            message = messageText
        case .attributedText(_):
            break
        case .photo(_):
            break
        case .video(_):
            break
        case .location(_):
            break
        case .emoji(_):
            break
        case .audio(_):
            break
        case .contact(_):
            break
        case .linkPreview(_):
            break
        case .custom(_):
            break
        }
        
        guard let myEmail = UserDefaults.standard.value(forKey: "email") as? String else {
            completion(false)
            return
        }
        
        let currentUserEmail = DatabaseManager.safeEmail(emailAddress: myEmail)
        
        let collectionMessage: [String: Any] = [
            "id": firstMessage.messageId,
            "type": firstMessage.kind.messageKindString,
            "content": message,
            "date": dateString,
            "sender_email": currentUserEmail,
            "is_read": false,
            "name": name
        ]
        
        let value: [String: Any] = [
            "messages" : [
                collectionMessage
            ]
        ]
        
        database.child("\(conversationID)").setValue(value, withCompletionBlock: { error, _ in
            guard error == nil else {
                completion(false)
                return
            }
            completion(true)
        })
    }
    
    /// Fetches and returns all conversations for the user with  passed in email
    public func getAllConversations(for email: String, completion: @escaping(Result<[Conversation], Error>) -> Void) {
        database.child("\(email)/conversations").observe(.value, with: { snapshot in
            
            guard let value = snapshot.value as? [[String: Any]] else {
                completion(.failure(DatabseError.failedToFetch))
                return
            }
            
            let conversations: [Conversation] = value.compactMap({ dictionary in
                guard let conversationID = dictionary["id"] as? String,
                      let name = dictionary["name"] as? String,
                      let otherUserEmail = dictionary["other_user_email"] as? String,
                      let latestMessage = dictionary["latest_message"] as? [String: Any],
                      let date = latestMessage["date"] as? String,
                      let message = latestMessage["message"] as? String,
                      let isRead = latestMessage["is_read"] as? Bool,
                      let kind = latestMessage["kind"] as? String else {
                    return nil
                }
                
                let latestMessageObject = LatestMessage(date: date,
                                                        text: message,
                                                        isRead: isRead,
                                                        kind: kind)
                return Conversation(id: conversationID,
                                    name: name,
                                    otherUserEmail: otherUserEmail,
                                    latestMessage: latestMessageObject)
            })
            completion(.success(conversations))
        })
    }
    
    /// Gets all messages for given conversation
    public func getAllMessagesForConversation(with id: String, completion: @escaping(Result<[Message], Error>) -> Void) {
        database.child("\(id)/messages").observe(.value, with: { snapshot in
            print("recieved new message")
            guard let value = snapshot.value as? [[String: Any]] else {
                completion(.failure(DatabseError.failedToFetch))
                return
            }
            
            let messages: [Message] = value.compactMap({ dictionary in
                guard let name = dictionary["name"] as? String,
                      let isRead = dictionary["is_read"] as? Bool,
                      let messageID = dictionary["id"] as? String,
                      let content = dictionary["content"] as? String,
                      let senderEmail = dictionary["sender_email"] as? String,
                      let type = dictionary["type"] as? String,
                      let dateString = dictionary["date"] as? String,
                      let date = ChatViewController.dateFormatter.date(from: dateString) else {
                    return nil
                }
                
                var kind: MessageKind?
                if type == "photo" {
                    guard let imageURL = URL(string: content),
                          let placeholder = UIImage(systemName: "plus") else {
                        return nil
                    }
                    let media = Media(url: imageURL,
                                      image: nil,
                                      placeholderImage: placeholder,
                                      size: CGSize(width: 300, height: 300))
                    kind = .photo(media)
                } else if type == "video" {
                    guard let videoURL = URL(string: content),
                          let placeholder = UIImage(named: "video_placeholder") else {
                        return nil
                    }
                    let media = Media(url: videoURL,
                                      image: nil,
                                      placeholderImage: placeholder,
                                      size: CGSize(width: 300, height: 300))
                    kind = .video(media)
                } else if type == "location" {
                    let locationComponents = content.components(separatedBy: ",")
                    guard let longitude = Double(locationComponents[0]),
                          let latitude = Double(locationComponents[1]) else {
                        return nil
                    }
                    let location = Location(location: CLLocation(latitude: latitude, longitude: longitude),
                                            size: CGSize(width: 300, height: 300))
                    kind = .location(location)
                }
                
                else {
                    
                    kind = .text(content)
                }
                
                guard let finalKind = kind else {
                    return nil
                }
                
                let sender = Sender(photoURL: "",
                                    senderId: senderEmail,
                                    displayName: name)
                
                return Message(sender: sender,
                               messageId: messageID,
                               sentDate: date,
                               kind: finalKind)
                
            })
            completion(.success(messages))
        })
    }
    
    /// Sends a message with target conversation and message
    public func sendMessage(to conversation: String, otherUserEmail: String, name: String, newMessage: Message, completion: @escaping(Bool) -> Void) {
        // add new message to messages
        // update sender latest message
        // update receipent latest message
        
        guard let myEmail = UserDefaults.standard.value(forKey: "email") as? String else {
            completion(false)
            return
        }
        
        let currentEmail = DatabaseManager.safeEmail(emailAddress: myEmail)
        
        database.child("\(conversation)/messages").observeSingleEvent(of: .value, with: { [weak self] snapshot in
            guard let strongSelf = self else {
                return
            }
            
            guard var currentMessages = snapshot.value as? [[String: Any]] else {
                completion(false)
                return
            }
            
            let messageDate = newMessage.sentDate
            let dateString = ChatViewController.dateFormatter.string(from: messageDate)
            let kind = newMessage.kind
            
            var message = ""
            switch newMessage.kind {
            case .text(let messageText):
                message = messageText
            case .attributedText(_):
                break
            case .photo(let mediaItem):
                if let targetURLString = mediaItem.url?.absoluteString {
                    message = targetURLString
                }
                break
            case .video(let mediaItem):
                if let targetURLString = mediaItem.url?.absoluteString {
                    message = targetURLString
                }
                break
            case .location(let locationData):
                let location = locationData.location
                message = "\(location.coordinate.longitude),\(location.coordinate.latitude)"
                break
            case .emoji(_):
                break
            case .audio(_):
                break
            case .contact(_):
                break
            case .linkPreview(_):
                break
            case .custom(_):
                break
            }
            
            guard let myEmail = UserDefaults.standard.value(forKey: "email") as? String else {
                completion(false)
                return
            }
            
            let currentUserEmail = DatabaseManager.safeEmail(emailAddress: myEmail)
            
            let newMessageEntry: [String: Any] = [
                "id": newMessage.messageId,
                "type": newMessage.kind.messageKindString,
                "content": message,
                "date": dateString,
                "sender_email": currentUserEmail,
                "is_read": false,
                "name": name
            ]
            
            currentMessages.append(newMessageEntry)
            
            strongSelf.database.child("\(conversation)/messages").setValue(currentMessages) { (error, _) in
                guard error == nil else {
                    completion(false)
                    return
                }
                
                strongSelf.database.child("\(currentEmail)/conversations").observeSingleEvent(of: .value, with: { snapshot in
                    var databaseEntryConversations = [[String : Any]]()
                    let updatedValue: [String: Any] = [
                        "date": dateString,
                        "is_read": false,
                        "message": message,
                        "kind" : kind.messageKindString
                    ]
                    
                    if var currentUserConversations = snapshot.value as? [[String: Any]] {
                        var targetConversation: [String: Any]?
                        var position = 0
                        
                        for conversationDictionary in currentUserConversations {
                            if let currentID = conversationDictionary["id"] as? String, currentID == conversation {
                                targetConversation = conversationDictionary
                                break
                            }
                            position += 1
                            
                        }
                        
                        if var targetConversation = targetConversation {
                            targetConversation["latest_message"] = updatedValue
                            currentUserConversations[position] = targetConversation
                            databaseEntryConversations = currentUserConversations
                        } else {
                            let newConversationData: [String: Any] = [
                                "id": conversation,
                                "other_user_email": DatabaseManager.safeEmail(emailAddress: otherUserEmail),
                                "name": name,
                                "latest_message": updatedValue
                            ]
                            currentUserConversations.append(newConversationData)
                            databaseEntryConversations = currentUserConversations
                        }
                        
                    } else {
                        let newConversationData: [String: Any] = [
                            "id": conversation,
                            "other_user_email": DatabaseManager.safeEmail(emailAddress: otherUserEmail),
                            "name": name,
                            "latest_message": updatedValue
                        ]
                        databaseEntryConversations = [
                            newConversationData
                        ]
                    }
                    
                    strongSelf.database.child("\(currentEmail)/conversations").setValue(databaseEntryConversations, withCompletionBlock: { error, _ in
                        guard error == nil else {
                            completion(false)
                            return
                        }
                        
                        // Update latest message for receipient user
                        strongSelf.database.child("\(otherUserEmail)/conversations").observeSingleEvent(of: .value, with: { snapshot in
                            let updatedValue: [String: Any] = [
                                "date": dateString,
                                "is_read": false,
                                "message": message,
                                "kind" : kind.messageKindString
                            ]
                            var databaseEntryConversations = [[String : Any]]()
                            
                            guard let currentName = UserDefaults.standard.value(forKey: "name") as? String else {
                                return
                            }
                            
                            if var otherUserConversations = snapshot.value as? [[String: Any]] {
                                var targetConversation: [String: Any]?
                                
                                var position = 0
                                
                                for conversationDictionary in otherUserConversations {
                                    if let currentID = conversationDictionary["id"] as? String, currentID == conversation {
                                        targetConversation = conversationDictionary
                                        break
                                    }
                                    position += 1
                                }
                                
                                if var targetConversation = targetConversation {
                                    targetConversation["latest_message"] = updatedValue
                                    otherUserConversations[position] = targetConversation
                                    databaseEntryConversations = otherUserConversations
                                } else {
                                    // current find current conversation
                                    let newConversationData: [String: Any] = [
                                        "id": conversation,
                                        "other_user_email": DatabaseManager.safeEmail(emailAddress: currentEmail),
                                        "name": currentName,
                                        "latest_message": updatedValue
                                    ]
                                    otherUserConversations.append(newConversationData)
                                    databaseEntryConversations = otherUserConversations
                                }
                            } else {
                                // current collection does not exist
                                let newConversationData: [String: Any] = [
                                    "id": conversation,
                                    "other_user_email": DatabaseManager.safeEmail(emailAddress: currentEmail),
                                    "name": currentName,
                                    "latest_message": updatedValue
                                ]
                                databaseEntryConversations = [
                                    newConversationData
                                ]
                            }
                            
                            strongSelf.database.child("\(otherUserEmail)/conversations").setValue(databaseEntryConversations, withCompletionBlock: { error, _ in
                                guard error == nil else {
                                    completion(false)
                                    return
                                }
                                completion(true)
                                
                            })
                        })
                    })
                })
            }
        })
    }
    
    /// Delete the conversation
    public func deleteConversation(conversationID: String, completion: @escaping (Bool) -> Void) {
        guard let email = UserDefaults.standard.value(forKey: "email") as? String else {
            return
        }
        let safeEmail = DatabaseManager.safeEmail(emailAddress: email)
        
        print("deleting conversation with ID: \(conversationID)")
        
        // Get all conversations for current user
        // delete conversation in collection with target ID
        // reset those conversations for the user in databse
        let ref = database.child("\(safeEmail)/conversations")
        ref.observeSingleEvent(of: .value, with: { snapshot in
            if var conversations = snapshot.value as? [[String: Any]] {
                var positionToRemove = 0
                for conversation in conversations {
                    if let id = conversation["id"] as? String,
                       id == conversationID {
                        print("found conversation to delete")
                        break
                    }
                    positionToRemove += 1
                }
                
                conversations.remove(at: positionToRemove)
                ref.setValue(conversations, withCompletionBlock: { error, _ in
                    guard error == nil else {
                        completion(false)
                        print("failed to write new conversation array")
                        return
                    }
                    print("delted conversation")
                    completion(true)
                })
            }
        })
    }
    
    /// Find if conversation exists
    public func conversationExists(with targetRecipientEmail: String, completion: @escaping (Result<String, Error>) -> Void) {
        let safeRecipientEmail = DatabaseManager.safeEmail(emailAddress: targetRecipientEmail)
        guard let senderEmail = UserDefaults.standard.value(forKey: "email") as? String else {
            return
        }
        let safeSenderEmail = DatabaseManager.safeEmail(emailAddress: senderEmail)
        
        database.child("\(safeRecipientEmail)/conversations").observeSingleEvent(of: .value, with: { snapshot in
            guard let collection = snapshot.value as? [[String: Any]] else {
                completion(.failure(DatabseError.failedToFetch))
                return
            }
            // iterate and find conversation with target sender
            if let conversation = collection.first(where: {
                guard let targetSenderEmail = $0["other_user_email"] as? String else {
                    return false
                }
                return safeSenderEmail == targetSenderEmail
            }) {
                // get id and return success
                guard let id = conversation["id"] as? String else {
                    completion(.failure(DatabseError.failedToFetch))
                    return
                }
                completion(.success(id))
                return
            }
            completion(.failure(DatabseError.failedToFetch))
            return
        })
        
        
    }
    
    // MARK: Current Location Uploading
    public func uploadLocationData(with currentLocation: CLLocationCoordinate2D, messageDate: Date, completion: @escaping (Bool)->Void) {
        // get current user's email from standard defaults
        let email = UserDefaults.standard.value(forKey: "email")
        guard let email = email as? String else {
            return
        }
        
        let safeEmail = DatabaseManager.safeEmail(emailAddress: email)
        
        let dateString = ChatViewController.dateFormatter.string(from: messageDate)
        
        // the two fields that we want to set are currentLocation and the date it was updated at
        let currentLocationData : [String : Any] = [
            "currentLocation" : "\(currentLocation.longitude),\(currentLocation.latitude)",
            "updatedAt" : dateString
        ]
        
        // We set these fields in the user's currentLocation node
        database.child("\(safeEmail)/currentLocation").setValue(currentLocationData, withCompletionBlock: { error, _ in
            
            // if there's an error, return false to the completion handler
            guard error == nil else {
                completion(false)
                return
            }
            completion(true)
        })
    }
    
    public func addFriend(with friendsSafeEmail: String, completion: @escaping (Bool)->Void) {
        let email = UserDefaults.standard.value(forKey: "email")
        guard let email = email as? String else {
            return
        }
        let safeEmail = DatabaseManager.safeEmail(emailAddress: email)
        database.child("\(safeEmail)/friends/\(friendsSafeEmail)").observeSingleEvent(of: .value, with: { [weak self] snapshot in
            if snapshot.exists() {
                // friend exists already, do nothing
                completion(false)
            } else {
                // friend doesn't exists, add to friends
                self?.database.child("\(safeEmail)/friends/\(friendsSafeEmail)").setValue(true)
                completion(true)
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
    
    public func retrieveLocation(with safeEmail: String, completion: @escaping(CLLocationCoordinate2D)->Void) {
        database.child("\(safeEmail)/currentLocation/currentLocation").observeSingleEvent(of: .value, with: { snapshot in
            guard let coordinatesString = snapshot.value as? String else { return }
            let components = coordinatesString.components(separatedBy: ",")
            guard let latitude = Double(components[1]), let longitude = Double(components[0]) else { return }
            let coordinates = CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
            completion(coordinates)
        })
    }
}

struct ChatAppUser {
    let firstName: String
    let lastName: String
    let emailAddress: String
    var safeEmail: String {
        var safeEmail = emailAddress.replacingOccurrences(of: ".", with: "-")
        safeEmail = safeEmail.replacingOccurrences(of: "@", with: "-")
        return safeEmail
    }
    var profilePictureFileName: String {
        return "\(safeEmail)_profile_picture.png"
    }
}
