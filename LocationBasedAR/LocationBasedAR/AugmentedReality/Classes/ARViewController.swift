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
    
    // Total maximum number of visible annotation view. Default value is 100. Max value is 500.
    open var maxVisibleAnnotations = 0 {
        didSet {
            if (maxVisibleAnnotations > MAX_VISIBLE_ANNOTATIONS) {
                maxVisibleAnnotations = MAX_VISIBLE_ANNOTATIONS
            }
        }
    }
    
    /**
     *  The maximum distance (in meters) for an annotation to be shown.
     *  If the distance from an annotation to the user's location is greater than this value, then that annotation will not be shown.
     *  Also, this property, in conjunction with maxVerticalLevel, define how are annotations aligned vertically. Meaning an annotation
     *  that are closer to this value will be higher.
     *  Default value is 0 meters, which means that distances of annotations don't affect their visibility.
     */
    open var maxDistance: Double = 0
    
    // Class for managing geographical calculations. Use it to set properties like reloadDistanceFilter, userDistanceFilter and altitudeSensitive.
    fileprivate(set) open var trackingManager: ARTrackingManager = ARTrackingManager()
    
    // UIImage for the close button. If not set, the deafult one is used.
    open var closeButtonImage: UIImage? {
        didSet {
            closeButton?.setImage(self.closeButtonImage, for: UIControlState())
        }
    }
    
    // Enables map debugging and some other debuggin features, set before the controller is shown.
    @available(*, deprecated, message: "Will be removed in the next version, use uiOptions.debugEnabled.")
    open var debugEnabled = true {
        didSet {
            self.uiOptions.debugEnabled = debugEnabled
        }
    }
    
    // Smoothing factor for heading in range 0-1. It affects horizontal movement of annotation views. the lower the value the bigger the smoothing.
    // Value 1 means no smoothing. It should be greater than 0
    open var headingSmoothingFactor: Double = 1
    
    // Called every 5 seonds after the location tracking has started but failed to deliver the location. It is also called when tracking has just
    // started with timeElapsed = 0. This timer is restarted when the app comes from the background or on didAppear.
    open var onDidFailToFindLocation: ((_ timeElapsed: TimeInterval, _ acquiredLocationBefore: Bool) -> Void)?
}
