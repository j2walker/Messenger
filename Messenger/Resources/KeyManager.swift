//
//  KeyManager.swift
//  Messenger
//
//  Created by Jack Walker on 4/10/23.
//

import Foundation
import CryptoKit
import Security

final class KeyManager {
    static let shared = KeyManager()
}

extension KeyManager {
    
    public func createPrivateKey() {
        let attributes: CFDictionary =
        [
            kSecAttrKeyType as String: kSecAttrKeyTypeRSA,
            kSecAttrKeySizeInBits as String: 2048,
            kSecPrivateKeyAttrs as String:
            [
                kSecAttrIsPermanent as String: true,
                kSecAttrApplicationTag as String: "com.Messenger.privateKey"
            ]
        ] as CFDictionary
        
        
        var error: Unmanaged<CFError>?
        guard let privateKey = SecKeyCreateRandomKey(attributes as CFDictionary, &error) else {
            print("Failed to create private key")
            return
        }
        print("Secret key created")
        print("\(privateKey)")
    }
    
    private func getPrivateKey() -> SecKey? {
        let keyQuery: CFDictionary =
        [
            kSecClass as String: kSecClassKey,
            kSecAttrApplicationTag as String: "com.Messenger.privateKey",
            kSecAttrKeyType as String: kSecAttrKeyTypeRSA,
            kSecReturnRef as String: true
        ] as CFDictionary
        
        var item: CFTypeRef?
        let status = SecItemCopyMatching(keyQuery as CFDictionary, &item)
        guard status == errSecSuccess else {
            print("Failed to find private key. Has it been generated?")
            return nil
        }
        
        return item as! SecKey
    }
    
    
}
