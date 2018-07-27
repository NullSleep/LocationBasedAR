//
//  ARTrackingManager.swift
//  LocationBasedAR
//
//  Created by Carlos Arenas on 7/27/18.
//  Copyright © 2018 Carlos Arenas. All rights reserved.
//

import UIKit
import CoreMotion
import CoreLocation

@objc protocol ARTrackingManagerDelegate: NSObjectProtocol {
    @objc optional func arTrackingManager(_ trackingManager: ARTrackingManager, didUpdateUserLocation location: CLLocation?)
}

// Class used internally by the ARViewController for location and orientation calculations.
open class ARTrackingManager: NSObjectProtocol, CLLocationManagerDelegate {
    
}
