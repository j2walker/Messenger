//
//  MapViewController.swift
//  Messenger
//
//  Created by Jack Walker on 1/26/23.
//

import UIKit
import MapKit
import CoreLocation

class MapViewController: UIViewController, CLLocationManagerDelegate {
    
    let manager = CLLocationManager()
    
    var lastPin = MKPointAnnotation()
    
    var friendsLocations : [String : CLLocationCoordinate2D] = [:]
    
    let button: UIButton = {
        let button = UIButton()
        button.setImage(UIImage(systemName: "location.circle"), for: .normal)
        button.backgroundColor = .white
        button.clipsToBounds = true;
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()
    
    let map: MKMapView = {
        let map = MKMapView()
        map.overrideUserInterfaceStyle = .dark
        map.translatesAutoresizingMaskIntoConstraints = false
        return map
    }()
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.addSubview(map)
        NSLayoutConstraint.activate([
            map.topAnchor.constraint(equalTo: view.topAnchor),
            map.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),
            map.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            map.leadingAnchor.constraint(equalTo: view.leadingAnchor),
        ])
        button.clipsToBounds = true
        button.addTarget(self, action: #selector(buttonTapped), for: .touchUpInside)
        view.addSubview(button)
        updateFriendsLocations(completion: { [weak self] in
            guard let self = self else {return}
            for (key, _) in friendsLocations {
                guard let location = friendsLocations[key] else { return }
                addPin(with: location)
            }
        })
    }
    
    @objc func buttonTapped(_ sender:UIButton!) {
        manager.startUpdatingLocation()
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        button.frame = CGRect(x: 25, y: 150, width: 50, height: 50)
        button.layer.cornerRadius = 0.5 * button.bounds.size.width
    }
    
    private func updateFriendsLocations(completion: @escaping () -> Void) {
        DatabaseManager.shared.getFriendsLocations(completion: { [weak self] location in
            guard let location = location, let strongSelf = self else { return }
            strongSelf.friendsLocations = location
            completion()
        })
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        manager.desiredAccuracy = kCLLocationAccuracyBest
        manager.delegate = self
        manager.requestWhenInUseAuthorization()
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        if let location = locations.first {
            manager.stopUpdatingLocation()
            render(location)
            DatabaseManager.shared.uploadLocationData(with: location.coordinate, messageDate: Date(), completion: { result in
                guard result else {
                    print("Unable to upload current user's location data to db")
                    return
                }
                print("Sucessfully uploaded current user's location data to db")
            })
        }
    }
    
    func render(_ location: CLLocation) {
        let region = MKCoordinateRegion(center: location.coordinate, span: MKCoordinateSpan(latitudeDelta: 0.1, longitudeDelta: 0.1))
        map.setRegion(region, animated: true)
        
        let pin = MKPointAnnotation()
        pin.coordinate = location.coordinate
        if (self.map.view(for: lastPin) != nil) {
            map.removeAnnotation(lastPin)
        }
        lastPin = pin
        map.addAnnotation(pin)
        
    }
    
    private func addPin(with location: CLLocationCoordinate2D) {
        let pin = MKPointAnnotation()
        pin.coordinate = location
        map.addAnnotation(pin)
    }
    
}
