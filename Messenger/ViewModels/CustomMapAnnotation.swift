//
//  CustomMapAnnotation.swift
//  Messenger
//
//  Created by Jack Walker on 6/1/23.
//

import Foundation
import MapKit

class CustomMapAnnotation: NSObject, MKAnnotation {
    
    var coordinate: CLLocationCoordinate2D
    var title: String?
    var subtitle: String?
    var associatedUID: String?
    
    init(coordinate: CLLocationCoordinate2D) {
        self.coordinate = coordinate
    }
}
