//
//  Utilities.swift
//  Messenger
//
//  Created by Jack Walker on 6/6/23.
//

import Foundation

final class Utilities {
    
    static public func getCurrentNumericTimeAsString() -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyyMMddHHmmss"
        let currentNumericDate = Date()
        let numericTimeString = dateFormatter.string(from: currentNumericDate)
        return numericTimeString
    }
    
    static public func getDateFromString(utcTimeString: String) -> Date? {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyyMMddHHmmss"
        dateFormatter.timeZone = TimeZone(abbreviation: "UTC")
        return dateFormatter.date(from: utcTimeString)
    }
}


