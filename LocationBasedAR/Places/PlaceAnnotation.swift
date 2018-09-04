//
//  PlaceAnnotation.swift
//  Places
//
//  Created by Carlos Arenas on 8/31/18.
//  Copyright © 2018 Razeware LLC. All rights reserved.
//

import Foundation
import MapKit

class placeAnnotation: NSObject, MKAnnotation {
  let coordinate: CLLocationCoordinate2D
  let title: String?
  
  init(location: CLLocationCoordinate2D, title: String) {
    self.coordinate = location
    self.title = title
    
    super.init()
  }
  
}
