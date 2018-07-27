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
     Defines whether altitude is taken into account when calculating distances. Set this to falsew if your annotations don't have altitude values.
     Note that this is only used for distance calculation, it doesn't have effect on vertical levels of annotations. Default value is false.
     */
}
