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
 *  Augmented Reality View Controller
 *
 *  How to use:
 *  1. Initialize the controller and set the datasource (and other properties if needed)
 *  2. Use the setAnnotations method to set annotations.
 *  3. Present controller modally.
 *  4. Implement ARDataSource to provide annotation view in your data source
 *
 *  Properties maxVerticalLevel, maxVisibleAnnotations and maxDistance can be used to optimize performance.
 *  Use trackingManager.userDistanceFilter and trackingManager.reloadDistanceFilter to set how ofter the data is refreshed/reloaded.
 */

open class ARViewController: UIViewController {
    
    // MARK: - Class properites
    
    // Data Source
    open weak var dataSource: ARDataSource?
    
    // Orientation mask for view controller. Make sure orientations are enabled in the project settings also.
    open var interfaceOrientationMask: UIInterfaceOrientationMask = UIInterfaceOrientationMask.all
    
    /**
     *  Defines how many vertical levels can annotations be stacked. The default value is 5.
     *  Annotations are initially vertically arranged by distance from the user, but if two annotations visible collide with each other,
     *  the farhter annotation is puth higher, meaning it is moved onto next vertical level. If annotaiton is moved onto a level higher
     *  than this value, then it will not be visible.
     *  NOTE: This property greatly impacts performance because collision detection is a heavy operation, use it in range 1-10. Max value is 10.
     */
    open var maxVerticalLevel = 0 {
        didSet {
            if (maxVerticalLevel > MAX_VERTICAL_LEVELS) {
                maxVerticalLevel = MAX_VERTICAL_LEVELS
            }
        }
    }
}
