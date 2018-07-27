//
//  ARViewController.swift
//  LocationBasedAR
//
//  Created by Carlos Arenas on 7/25/18.
//  Copyright © 2018 Carlos Arenas. All rights reserved.
//

import UIKit
import AVFoundation
import CoreLocation

/**
 *      Augmented Reality View Controller
 *
 *      How to use:
 *      1. Initialize the controller and set the datasource (and other properties if needed)
 *      2. Use the setAnnotations method to set annotations.
 *      3. Present controller modally.
 *      4. Implement ARDataSource to provide annotation view in your data source
 *
 *      Properties maxVerticalLevel, maxVisibleAnnotations and maxDistance can be used to optimize performance.
 *      Use trackingManager.userDistanceFilter and trackingManager.reloadDistanceFilter to set how ofter the data is refreshed/reloaded.
 */

open class ARViewController: UIViewController {
    
}
