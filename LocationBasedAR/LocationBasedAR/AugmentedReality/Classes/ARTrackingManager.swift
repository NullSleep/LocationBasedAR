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
    @objc optional func arTrackingManager(_ trackingManager: ARTrackingManager, didUpdateReloadLocation location: CLLocation?)
    @objc optional func arTrackingmanager(_ trackingManager: ARTrackingManager, didFailToFindLocationAfter elapsedSeconds: TimeInterval)
    @objc optional func logText(_ text: String)
}

// Class used internally by the ARViewController for location and orientation calculations.
open class ARTrackingManager: NSObjectProtocol, CLLocationManagerDelegate {
    
    /**
     * Defines whether altitude is taken into account when calculating distances. Set this to falsew if your annotations don't have altitude values.
     * Note that this is only used for distance calculation, it doesn't have effect on vertical levels of annotations. Default value is false.
     */
    open var altitudeSensitive = false
    
    /**
     * Specifies how often the visibilities of annotations are reevaluated.
     *
     * Annotation's visibility depens on the number of factors - azimuth distance from user, vertical level etc.
     * Note: Thse calculations are quite heavy if many annotations are present, so don't use a value lower than 50m. The default value is 25m.
     */
    open var reloadDistanceFilter: CLLocationDistance! // Will be set in init
    
    // Specifies how often are distances and azimuths recalculated for visible annotations. The default value is 25m.
    open var userDistanceFilter: CLLocationDistance! {
        didSet {
            self.locationManager.distanceFilter = self.userDistanceFilter
        }
    }
    
    // Internal Variables
    fileprivate(set) internal var locationManager: CLLocationManager = CLLocationManager()
    fileprivate(set) internal var tracking = false
    fileprivate(set) internal var userLocation: CLLocation?
    fileprivate(set) internal var heading: Double = 0
    internal weak var delegate: ARTrackingManagerDelegate?
    internal var orientation: CLDeviceOrientation = CLDeviceOrientation.portrait {
        didSet {
            self.locationManager.headingOrientation = self.orientation
        }
    }
    internal var pitch: Double
}
