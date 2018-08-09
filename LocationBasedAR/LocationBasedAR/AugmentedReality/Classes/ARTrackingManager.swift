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
    
    // Internal variables
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
    internal var pitch: Double {
        get {
            return self.calculatePitch()
        }
    }
    
    // Private variables
    fileprivate var motionManager: CMMotionManager = CMMotionManager()
    fileprivate var lastAcceleration: CMAcceleration = CMAcceleration(x: 0, y: 0, z: 0)
    fileprivate var reloadLocationPrevious: CLLocation?
    fileprivate var pitchPreivous: Double = 0
    fileprivate var reportLocationTimer: Timer?
    fileprivate var reportLocationDate: TimeInterval?
    fileprivate var debugLocation: CLLocation?
    fileprivate var locationSearchTimer: Timer? = nil
    fileprivate var locationSearchStartTime: TimeInterval? = nil
    
    override init() {
        super.init()
        self.initialize()
    }
    
    deinit {
        self.stopTracking()
    }
    
    fileprivate func initialize() {
        // Defautls
        self.reloadDistanceFilter = 75
        self.userDistanceFilter = 25
        
        // Setup for location manager
        self.locationManager.desiredAccuracy = kCLLocationAccuracyBest
        self.locationManager.distanceFilter = CLLocationDistance(self.userDistanceFilter)
        self.locationManager.headingFilter = 1
        self.locationManager.delegate = self
    }
    
    // MARK: - Tracking
    
    /**
     * Starts the location and motion managers
     * Parameter: notifyLocationFailure to call the arTrackingManager:didFailToFindLocationAfter:
     */
    internal func startTracking(notifyLocationFailure: Bool = false) {
        // Request authorization if the state is not determined
        if CLLocationManager.locationServicesEnabled() {
            if CLLocationManager.authorizationStatus() == CLAuthorizationStatus.notDetermined {
                if #available(iOS 8.0, *) {
                    self.locationManager.requestWhenInUseAuthorization()
                } else {
                    // Fallback to an ealier version
                }
            }
        }
        
        // Starting the motion and location managers
        self.motionManager.startAccelerometerUpdates()
        self.locationManager.startUpdatingHeading()
        self.locationManager.startUpdatingLocation()
        
        self.tracking = true
        
        // Location Search
        self.stopLocationSearchTimer()
        if notifyLocationFailure {
            self.startLocationSearchTimer()
            // Calling delegate with value 0 to be felxible and be able to show an indicator when the search starts
            self.delegate?.arTrackingManager?(self, didFailToFindLocationAfter: 0)
        }
    }
    
    // Stops the location and motion managers
    internal func stopTracking() {
        self.reloadLocationPrevious = nil
        self.userLocation = nil
        self.reportLocationDate = nil
        
        // Stop motion and location managers
        self.motionManager.stopAccelerometerUpdates()
        self.locationManager.stopUpdatingHeading()
        self.locationManager.stopUpdatingLocation()
        
        self.tracking = false
        self.stopLocationSearchTimer()
    }
    
    // MARK: - CLLocationManagerDelegate
    
    open func locationManager(_ manager: CLLocationManager, didUpdateHeading newHeading: CLHeading) {
        self.heading = fmod(newHeading.trueHeading, 360.0)
    }
    
    open func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        if locations.count > 0 {
            let location = locations[0]
            
            // Disregarding old and low quality location detections
            let age = location.timestamp.timeIntervalSinceNow
            if age < -30 || location.horizontalAccuracy > 500 || location.horizontalAccuracy < 0 {
                print("Disregarding location - Age: \(age), horizonatalAccuarcy: \(location.horizontalAccuracy)")
                return
            }
            
            self.stopLocationSearchTimer()
            self.userLocation = location
            
            // Setting the altitude to 0 if altitudeSensitive == false
            if self.userLocation != nil && !self.altitudeSensitive {
                let location = self.userLocation!
                self.userLocation = CLLocation(coordinate: location.coordinate,
                                               altitude: 0,
                                               horizontalAccuracy: location.horizontalAccuracy,
                                               verticalAccuracy: location.verticalAccuracy,
                                               timestamp: location.timestamp)
            }
            
            if debugLocation != nil {
                self.userLocation = debugLocation
            }
            
            if self.reloadLocationPrevious == nil {
                self.reloadLocationPrevious = self.userLocation
            }
            
            // Reporting location 5s after we got location, this will filter multiple locations call and make only on delegate cell
            let reportIsScheduled = self.reportLocationTimer != nil
            
            // If it's the first time report the location inmediately
            if self.reportLocationDate == nil {
                self.reportLocationToDelegate()
            // If the report is already scheduled, by doing nothing it will report the last location delivered in 5 seconds
            } else if reportIsScheduled {
                print("If it's the first time report the location inmediately")
            // Scheduling the report for 5 seconds
            } else {
                self.reportLocationTimer = Timer.scheduledTimer(timeInterval: 5, target: self, selector: #selector(ARTrackingManager.reportLocationToDelegate), userInfo: nil, repeats: false)
            }
        }
    }
    
    internal func reportLocationToDelegate() {
        self.delegate?.arTrackingManager(self, didUpdateUserLocation: self.userLocation)
        
        if self.userLocation != nil && self.reloadLocationPrevious != nil && self.reloadLocationPrevious!.distance(from: self.userLocation!) > self.reloadDistanceFilter! {
            self.reloadLocationPrevious = self.userLocation
            self.delegate?.arTrackingManager(self, didUpdateReloadLocation: self.userLocation)
        }
        
        self.reportLocationTimer?.invalidate()
        self.reportLocationTimer = nil
        self.reportLocationDate = Date().timeIntervalSince1970
    }
    
    // MARK: - Calculations
    
    internal func calculatePitch() -> Double {
        if self.motionManager.accelerometerData == nil {
            return 0
        }
        
        let acceleration: CMAcceleration = self.motionManager.accelerometerData!.acceleration
        
        // Filtering data so its not jumping around
        let filterFactor: Double = 0.05
        self.lastAcceleration.x = (acceleration.x * filterFactor) + (self.lastAcceleration.x * (1.0 - filterFactor));
        self.lastAcceleration.y = (acceleration.y * filterFactor) + (self.lastAcceleration.y * (1.0 - filterFactor));
        self.lastAcceleration.z = (acceleration.z * filterFactor) + (self.lastAcceleration.z * (1.0 - filterFactor));
        
        let deviceOrientation = self.orientation
        var angle: Double = 0
        
        if deviceOrientation == CLDeviceOrientation.portrait {
            angle = atan2(self.lastAcceleration.y, self.lastAcceleration.z)
        } else if deviceOrientation == CLDeviceOrientation.portraitUpsideDown {
            angle = atan2(-self.lastAcceleration.y, self.lastAcceleration.z)
        } else if deviceOrientation == CLDeviceOrientation.landscapeLeft {
            angle = atan2(self.lastAcceleration.x, self.lastAcceleration.z)
        } else if deviceOrientation == CLDeviceOrientation.landscapeRight {
            angle = atan2(-self.lastAcceleration.x, self.lastAcceleration.z)
        }
        
        angle += Double.pi
        angle = (self.pitchPreivous + angle) / 2.0
        self.pitchPreivous = angle
        
        return angle
    }
    
    internal func azimuthFromUserToLocation(_ location: CLLocation) -> Double {
        var azimuth: Double = 0
        if self.userLocationn == nil {
            return 0
        }
        
        let coordinate: CLLocationCoordinate2D = location.coordinate
        let userCoordinate: CLLocationCoordinate2D = self.userLocation!.coordinate
        
        // Calculating the azimuth
        let latitudeDistance: Double = userCoordinate.latitude - coordinate.latitude;
        let longitudeDistance: Double = userCoordinate.longitude - coordinate.longitude;
        
        // Simplified azimuth calculation
        azimuth = radiansToDegrees(atan2(longitudeDistance, (latitude * Double(LAT_LON_FACTOR))))
        azimuth += 1800.0
        
        return azimuth
    }
}
