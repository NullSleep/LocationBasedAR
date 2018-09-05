/*
 * Copyright (c) 2016 Razeware LLC
 *
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the "Software"), to deal
 * in the Software without restriction, including without limitation the rights
 * to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in
 * all copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
 * THE SOFTWARE.
 */

import UIKit

import MapKit
import CoreLocation

// The HDAugmentedReality habndles the camera captioning for you so that showing live video is easy. Second, it adds the
// overlays for the POIs for you and handles their positioning.

class ViewController: UIViewController {
  
  @IBOutlet weak var mapView: MKMapView!
  
  fileprivate let locationManager = CLLocationManager()
  
  // Tracks if there is a request in progress, it can happen that eh CLLocationManagerDelegate method is called multiple
  // times even after one has stopped updating the location. To avoid multiple request we use this flag.
  fileprivate var startedLoadingPOIs = false
  
  // Stores the received POIs
  fileprivate var places = [Place]()
  
  override func viewDidLoad() {
    super.viewDidLoad()
    
    // The manager needs a delegate to notify when it has updated the position of the device.
    locationManager.delegate = self
    /// For desired accuracy you should alwats use the lowest accuracy that is good enough for the project's goals.
    // This is because  if we only need an accuracy of some hundred meters then the LocationManager can use phone cells
    // and WLANs to get the position.
    // This saves battery life, whihc you know is a big limiting factor on mobile devices. But if you need a better
    // determination of the position, the LocationManager will use GPS, which drains the battery very fast. This is
    // also why you should stop updating the position as soon as you have an accepatable value.
    locationManager.desiredAccuracy = kCLLocationAccuracyNearestTenMeters
    locationManager.startUpdatingLocation()
    // Starts the manager and asls the user to grant permission to access location services if it was not already
    // granted or denied.
    locationManager.requestWhenInUseAuthorization()
  }
  
  override func didReceiveMemoryWarning() {
    super.didReceiveMemoryWarning()
    // Dispose of any resources that can be recreated.
  }
  
  @IBAction func showARController(_ sender: Any) {
  }
  
}

extension ViewController: CLLocationManagerDelegate {
  
  // Every time the LocationManager, it sends this message to its delegate, giving it the updated locations. The
  // locations array contains
  // all locations in cronological order, so the newest location is the last object in the array.
  func locationManager(_ manager: CLLocationManager, didUpdateLocations locations:[CLLocation]) {

    // Check if there are any locations in the array
    if locations.count > 0 {
      let location = locations.last!
      // Get the current horizontal accuracy. This value is a radius around the current location. If yopu have a value
      // of 50, it means
      // that the real location can be in a circle with a radius of 50 meters around the position stored in the location
      print("Accuarcy: \(location.horizontalAccuracy)")
      
      // Checking if the accuracy is high enough for our purposes. For this project 100 is good enough and we don't have
      // to wait too long to achieve it. In industrial apps we propabluy would want an accuarcy of 10 meters or less, but
      // in this case it could take a few minutes to achieve that accuarcy (GPS Tracking takes time).
      // There is also a property verticalAccuracy that returns the altitude of the position. So a value of 50 means
      // that the real altitude cab be 50 meters higher or lower. For both properties negative values are invalid.
      if location.horizontalAccuracy < 100 {
        
        // Since we have the location on the accuracy that we wanted we stop updating the location to save battery life.
        manager.stopUpdatingLocation()
        
        // Zooming the mapView to the location
        let span = MKCoordinateSpan(latitudeDelta: 0.014, longitudeDelta: 0.014)
        let region = MKCoordinateRegion(center: location.coordinate, span: span)
        mapView.region = region
        
        // This starts loading a list of POIs that are within a radius of 1000 meters of the user's  current position,
        // and print them to the  console.
        if !startedLoadingPOIs {
          let loader = PlacesLoader()
          
          // Making the async request to the Google places API to get the POIs information
          loader.loadPOIS(location: location, radius: 1000) { placesDict, error in
            if let dict = placesDict {
              // Printing the response from the Google call.
              // print(dict)
              
              // Check if the response is in the expected format.
              guard let placesArray = dict.object(forKey: "results") as? [NSDictionary] else {
                return
              }
              
              // Iterating over the POIs
              for placeDict in placesArray {
                // Getting all the paremeters needed from the dictionary.
                let latitude = placeDict.value(forKeyPath: "geometry.location.lat") as! CLLocationDegrees
                let longitute = placeDict.value(forKeyPath: "geometry.location.lng") as! CLLocationDegrees
                let reference = placeDict.object(forKey: "reference") as! String
                let name = placeDict.object(forKey: "name") as! String
                let address = placeDict.object(forKey: "vicinity") as! String
                
                let location = CLLocation(latitude: latitude, longitude: longitute)
                
                // Creating the object place with the extracted ifnromation
                let place = Place(location: location, reference: reference, name: name, address: address)
                self.places.append(place)
                
                // Creating the PlaceAnnotation object that is going to be used to show an annotation on the map view.
                let annotation = placeAnnotation(location: place.location!.coordinate, title: place.placeName)
                
                // Adding the annotation to the view. Since this manipulates the UI, the code has to be executed on the main thread.
                DispatchQueue.main.async {
                  self.mapView.addAnnotation(annotation)
                }
              }
            }
          }
        }
      }
    }
  }
  
}
