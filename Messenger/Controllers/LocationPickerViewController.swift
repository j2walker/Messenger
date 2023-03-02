//
//  LocationPickerViewController.swift
//  Messenger
//
//  Created by Jack Walker on 2/9/23.
//

import UIKit
import MapKit
import CoreLocation

class LocationPickerViewController: UIViewController {
    
    public var completion: ((CLLocationCoordinate2D) -> Void)?
    
    private var coordinates: CLLocationCoordinate2D?
    
    private var isPickable = true
    
    private let map: MKMapView = {
        let map = MKMapView()
        map.translatesAutoresizingMaskIntoConstraints = false
        return map
    }()
    
    init(coordinates: CLLocationCoordinate2D?) {
        guard let coordinates = coordinates else {
            isPickable = true
            super.init(nibName: nil, bundle: nil)
            return
        }
        self.coordinates = coordinates
        self.isPickable = false
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        if isPickable {
            navigationItem.rightBarButtonItem = UIBarButtonItem(title: "Send",
                                                                style: .done,
                                                                target: self,
                                                                action: #selector(sendButtonTapped))
            map.isUserInteractionEnabled = true
            
            let gesture = UITapGestureRecognizer(target: self, action: #selector(didTapMap(_:)))
            gesture.numberOfTouchesRequired = 1
            gesture.numberOfTapsRequired = 1
            map.addGestureRecognizer(gesture)
        } else {
            guard let coordinate = self.coordinates else {
                return
            }
            let pin = MKPointAnnotation()
            pin.coordinate = coordinate
            map.addAnnotation(pin)
            map.setRegion(MKCoordinateRegion(center: coordinate, span: MKCoordinateSpan(latitudeDelta: 0.1, longitudeDelta: 0.1)), animated: true)
        }
        view.addSubview(map)
        NSLayoutConstraint.activate([
            map.topAnchor.constraint(equalTo: view.topAnchor),
            map.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),
            map.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            map.leadingAnchor.constraint(equalTo: view.leadingAnchor),
        ])
    }
    
    @objc func sendButtonTapped() {
        guard let coordinates = coordinates else {
            return
        }
        navigationController?.popViewController(animated: true)
        completion?(coordinates)
    }
    
    @objc func didTapMap(_ gesture: UITapGestureRecognizer) {
        let locationInview = gesture.location(in: map)
        let coordinates = map.convert(locationInview, toCoordinateFrom: map)
        self.coordinates = coordinates
        
        for annotation in map.annotations {
            map.removeAnnotation(annotation)
        }
        // drop in on that location to see where the pin is dropped
        let pin = MKPointAnnotation()
        pin.coordinate = coordinates
        map.addAnnotation(pin)
    }
}
