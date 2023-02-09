//
//  MapViewController.swift
//  Messenger
//
//  Created by Jack Walker on 1/26/23.
//

import UIKit
import MapKit

class MapViewController: UIViewController {
    
    let map: MKMapView = {
       let map = MKMapView()
        map.overrideUserInterfaceStyle = .dark
        map.translatesAutoresizingMaskIntoConstraints = false
        return map
    }()
    
    let annotation : MKPointAnnotation = {
        let annotation = MKPointAnnotation()
        annotation.coordinate = CLLocationCoordinate2D(latitude: 30.289670, longitude: -97.746940)
        return annotation
    }()
    
    let region = CLLocationCoordinate2D(latitude: 30.267153, longitude: -97.743057)
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.addSubview(map)
        NSLayoutConstraint.activate([
            map.topAnchor.constraint(equalTo: view.topAnchor),
            map.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),
            map.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            map.leadingAnchor.constraint(equalTo: view.leadingAnchor),
        ])
        map.setRegion(MKCoordinateRegion(center: region, span: MKCoordinateSpan(latitudeDelta: 0.1, longitudeDelta: 0.1)), animated: true)
        map.addAnnotation(annotation)
    }

}
