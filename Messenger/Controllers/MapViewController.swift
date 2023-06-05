//
//  MapViewController.swift
//  Messenger
//
//  Created by Jack Walker on 1/26/23.
//

import UIKit
import MapKit
import CoreLocation
import JGProgressHUD

class MapViewController: UIViewController, CLLocationManagerDelegate, MKMapViewDelegate {
    
    let manager = CLLocationManager()
    
    var lastPin = MKPointAnnotation()
    
    let spinner = JGProgressHUD(style: .dark)
    
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
        map.delegate = self
        map.showsUserLocation = true
        NSLayoutConstraint.activate([
            map.topAnchor.constraint(equalTo: view.topAnchor),
            map.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),
            map.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            map.leadingAnchor.constraint(equalTo: view.leadingAnchor),
        ])
        
        button.clipsToBounds = true
        button.addTarget(self, action: #selector(buttonTapped), for: .touchUpInside)
        view.addSubview(button)
        updateFriendsLocations()
    }
    
    public func updateFriendsLocations() {
        updateFriendsLocations(completion: { [weak self] in
            guard let self = self else {return}
            for (key, _) in friendsLocations {
                guard let location = friendsLocations[key] else { return }
                addPin(with: location, safeEmail: key)
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
        spinner.show(in: view)
        manager.desiredAccuracy = kCLLocationAccuracyBest
        manager.delegate = self
        manager.requestWhenInUseAuthorization()
        manager.startUpdatingLocation()
        updateFriendsLocations()
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
        let pin = MKUserLocation()
        map.addAnnotation(pin)
    }
    
    private func addPin(with location: CLLocationCoordinate2D, safeEmail: String) {
        let newPin = CustomMapAnnotation(coordinate: location)
        DatabaseManager.shared.retrieveFriendName(with: safeEmail, completion: { [weak self] result in
            newPin.title = result
            newPin.associatedUID = safeEmail
            self?.map.addAnnotation(newPin)
        })
    }
    
    func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
        guard !(annotation is MKUserLocation) else {
            return nil
        }
        guard let myAnnotation = annotation as? CustomMapAnnotation else { return nil }
        
        var annotationView = map.dequeueReusableAnnotationView(withIdentifier: "custom")
        
        if annotationView == nil {
            // no view yet, creat
            annotationView = MKAnnotationView(annotation: myAnnotation, reuseIdentifier: "custom")
            annotationView?.canShowCallout = true
        } else {
            annotationView?.annotation = myAnnotation
        }
        
        let UID = myAnnotation.associatedUID ?? "nil"
        let path = "images/\(UID)_profile_picture.png"
        StorageManager.shared.downloadURL(for: path, completion: { result in
            switch result {
            case .success(let url):
                StorageManager.shared.downloadImageFromURL(from: url, completion: { [weak self] image in
                    guard let strongSelf = self else { return }
                    DispatchQueue.main.async {
                        if let resizedImage = image?.sd_resizedImage(with: CGSize(width: 50, height: 50), scaleMode: .aspectFill) {
                            let imageView = UIImageView(image: resizedImage)
                            imageView.frame = CGRect(x: 0, y: 0, width: 50, height: 50)
                            imageView.layer.cornerRadius = imageView.bounds.width / 2
                            imageView.clipsToBounds = true
                            
                            annotationView?.image = UIGraphicsImageRenderer(size: imageView.bounds.size).image { _ in
                                imageView.drawHierarchy(in: imageView.bounds, afterScreenUpdates: true)
                                strongSelf.spinner.dismiss()
                            }
                        }
                    }
                     
                })
            case .failure(let error):
                print(error)
            }
        })
        
        return annotationView
    }
}
