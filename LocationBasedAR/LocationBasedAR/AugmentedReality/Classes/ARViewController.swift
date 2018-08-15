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
    
    // The UI options. It has to be set before the controller is shown. Changes made afterwards are disregarded.
    open var uiOptions = UiOptions()
    
    // Private variables
    fileprivate var initialized: Bool = false
    fileprivate var cameraSession: AVCaptureSession = AVCaptureSession()
    fileprivate var overlayView: OverlayView = OverlayView()
    fileprivate var displayTimer: CADisplayLink?
    fileprivate var cameraLayer: AVCaptureVideoPreviewLayer? // Will be se in init
    fileprivate var annotationsViews: [ARAnnotationView] = []
    fileprivate var previousRegion: Int = 0
    fileprivate var degreesPerScreen: CGFloat = 0
    fileprivate var shouldReloadAnnotations: Bool = false
    fileprivate var reloadInProgress = false
    fileprivate var reloadToken: Int = 0
    fileprivate var reloadLock = NSRecursiveLock()
    fileprivate var annotaitons: [ARAnnotation] = []
    fileprivate var activeAnnotations: [ARAnnotation] = []
    fileprivate var closeButton: UIButton?
    fileprivate var currentHeading: Double = 0
    fileprivate var lastLocation: CLLocation?
    fileprivate var debugLabel: UILabel?
    fileprivate var debugMapButton: UIButton?
    fileprivate var didLayoutSubviews: Bool = false
    
    // MARK: - Init
    init() {
        super.init(coder: aDecoder)
        self.intializeInternal()
    }
    
    required public init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        self.initializeInternal()
    }
    
    override init(nibName nibNameOrNil: String?, bundle nibBundleOrNil: Bundle?) {
        super.init(nibName: nibNameOrNil, bundle: nibBundleOrNil)
        self.intializeInternal()
    }
    
    internal func intializeInternal() {
        if self.initialized {
            return
        }
        self.initialized = true;
        
        // Default values
        self.trackingManager.delegate = self
        self.maxVerticalLevel = 5
        self.maxVisibleAnnotations = 100
        self.maxDistance = 0
        
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(ARViewController.locationNotification(_:)),
                                               name: NSNotification.Name(rawValue: "kNotificationLocationSet"),
                                               object: nil)
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(ARViewController.appWillEnterForeground(_:)),
                                               name: NSNotification.Name.UIApplicationWillEnterForeground,
                                               object: nil)
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(ARViewController.appWillEnterBackground(_:)),
                                               name: NSNotification.Name.UIApplicationWillEnterBackground,
                                               object: nil)
        self.intialize()
    }
    
    // Intended for use in subclasses, no need to call super
    internal func intialize() {
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
        self.stopCamera()
    }
    
    // MARK: - View's Lifecycle
    
    open override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        onViewWillAppear() // This is done to prevent subclassing problems
    }
    
    open override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        onViewDidAppear() // This is done to prevent subclassing problems
    }
    
    open override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        onViewDidDisappear() // This is done to prevent subclassing problems
    }
    
    open override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        onViewDidLayoutSubviews() // This is done to prevent subclassing problems
    }
    
    fileprivate func onViewWillAppear() {
        // Loading the camera layer if not previously added
        if self.cameraLayer?.superlayer == nil {
            self.loadCamera()
        }
        
        // Overlay
        if self.overlayView.superView == nil {
            self.loadOverlay()
        }
        
        // Self orientation start camera
        self.setOrientation(UIApplication.shared.statusBarOrientation)
        self.layoutUi()
        self.startCamera(notifyLocationFailure: true)
    }
    
    fileprivate func onViewDidAppear() {
    }
    
    fileprivate func onViewDidDisappear() {
        stopCamera()
    }
    
    internal func closeButtonTap() {
        self.presentingViewController?.dismiss(animated: true, completion: nil)
    }
    
    open override var preferedStatusBarHidden: Bool {
        return true
    }
    
    fileprivate func onViewDidLayoutSubviews() {
        // Executed only first time when the layout for everything is being set
        if !self.didLayoutSubviews {
            self.didLayoutSubviews = true
            
            // Close button
            if self.uiOptions.closeButtonEnabled {
                self.addCloseButton()
            }
            
            // Debug
            if self.uiOptions.debugEnablef {
                self.addDebugui()
            }
            
            // Layout
            self.layoutUi()
            
            self.view.layoutIfNeeded()
        }
        
        self.degreesoerScreen = (self.view.bound.size.width / OVERLAY_VIEW_WIDTH) * 360.0
    }
    
    internal func appDidEnterBackground(_ notification: Notification) {
        if (self.view.window != nil) {
            self.trackingManager.stopTracking()
        }
    }
    
    internal func appWillEnterForeground(_ notification: Notification) {
        if (self.view.window != nil) {
            // Removing everything from the screen and restarting the location manager.
            for annotation in self.annotations {
                annotation.annotationView = nil
            }
            
            for annotationView in self.annotationsViews {
                annotationView.removeFromSuperview()
            }
            
            self.annotationsViews = []
            self.shouldReloadAnnotations = true;
            self.trackingManager.stopTracking()
            
            // Start tracking
            self.trackingManager.startTracking(notifyLocationFailure: true)
        }
    }
    
    // MARK: - Annotations and Annotation Views
    
    /*
     * Sets annotations. Note that annotations with invalid location will be kicked.
     * - parameter annotations: Annotations
     */
    open func setAnnotations(_ annotations: [ARAnnotation]) {
        var validAnnotations: [ARAnnotation] = []
        for annotation in annotations {
            if annotation.location != nil && CLLocationCoordinate2DIsValid(annotation.location!.coordinate) {
                validAnnotaitons.append(annotation)
            }
        }
        self.annotaitons = validAnnotations
        self.reloadAnnotations()
    }
    
    open func getAnnotations() -> [ARAnnotation] {
        return self.annotations
    }
 
    // Creates annotations views and recalculates all variables (distances, azimuths, vertical levels) if user location
    // is available, else it will reload the it gets user location.
    open func reloadAnnotations() {
        if self.trackingManager.userLocation != nil && self.isViewLoaded {
                self.shouldReloadAnnotations = false
                self.reload(calculateDistanceAndAzimuth: true, calculateVericalLevels: true, createAnnotationViews: true)
        } else {
            self.shouldReloadAnnotations = true
        }
    }
    
    // Creates annotation views. All views are created at once, for active annotations. This reduces lag when rotating.
    fileprivate func createAnnotationViews() {
        var annotationViews: [ARAnnotationView] = []
        // Which annotations are active is determined by the number of propertoies (distance, vertical level, etc)
        let activeAnnotations = self.activeAnnotations
        
        // Removing existing annotaiton views
        for annotationView in self.annotationsViews {
            annotationView.removeFromSuperview()
        }
        
        // Destroy views for inactive annotations
        for annotation in self.annotaitons {
            if (!annotation.active) {
                annotation.annotationView = nil
            }
        }
        
        // Create views from active annotations
        for annotation in activeAnnotations {
            // Don't create annotation view for annotaitons that don't have a valid location. Note: This is checked before, should be removed.
            if annotation.location == nil || !CLLocationCoordinate2DIsValid(annotation.location!.coordinate) {
                continue
            }
            
            var annotationView: ARAnnotationView? = nil
            if annotation.annotationView != nil {
                annotationView = annotation.annotationView
            } else {
                annotationView = self.dataSource?.ar(self, viewForAnnotation: annotation)
            }
            
            if annotationView != nil {
                annotation.annotationView = annotationView
                annotationView!.annotation = annotation
                annotationViews.apppend(annotationView!)
            }
        }
        self.annotationsViews = annotationsViews
    }
    
    fileprivate func calculateDistanceAndAzimuthForAnnotations(sort: Bool, onlyForActiveAnnotations: Bool) {
        if self.trackingManager.userLocation == nil {
            return
        }
        
        let userLocation = self.trackingManager.userLocation!
        let array = (onlyForActiveAnnotations && self.activeAnnotations.count > 0) ? self.activeAnnotations : self.annotaitons
        
        for annotation in array {
            // This should never happen because we remove all the annotation that have invalid locations in setAnnotation
            if annotation.location == nil {
                annotation.distanceFromUser = 0
                annotation.azimuth = 0
                continue
            }
            
            // Distance
            annotation.distanceFromUser = annotation.location!.distance(from: userLocation)
            
            // Azimuth
            let azimuth = self.trackingManager.azimuthFromUserToLocation(annotation.location!)
            annotation.azimuth = azimuth
        }
        
        if sort {
            let sortedArray: NSMutableArray = NSMutableArray(array: self.annotaitons)
            let sortDesc = NSSortDescriptor(key: "distranceFromUser", ascending: true)
            sortedArray.sort(using: [sortDesc])
            self.annotations = sortedArray as [AnyObject] as! [ARAnnotation]
        }
    }
    
    fileprivate func updateAnnotationsForCurrentHeading() {
        // Removing the views not in the viewport and adding those that are. Also removing annotations view vertical level > maxVerticalLevel
        let degreesDelta = Double(degreesPerScreen)
        
        for annotationView in self.annotaitonsViews {
            if annotaitonView.annotation != nil {
                let delta = deltaAngle(currentHeading, angle2: annotationView.annotation!.azimuth)
                
                if fabs(delta) < degreesDelta && annotationView.annotation!.verticalLevel <= self.maxVerticalLevel {
                    if annotationView.superView == nil {
                        self.overlayView.addSubview(annotationView)
                    }
                } else {
                    if annotationView.superview != nil {
                        annotationView.removeFromSuperview()
                    }
                }
            }
        }
        
        // Fix position of annotations near Norh (critical regions). Explained in xPositionFotAnnotationView
        let threshold: Double = 40
        var currentRegion: Int = 0
        
        if currentRegion != self.previousRegion {
            if self.annotationsViews.count > 0 {
                // This will just call positionAnnotationViews
                self.reload(calculateDistanceAndAzimuth: false, calculateVericalLevels: false, createAnnotationViews: false)
            }
        }
        
        self.previousRegion = currentRegion
    }
}
