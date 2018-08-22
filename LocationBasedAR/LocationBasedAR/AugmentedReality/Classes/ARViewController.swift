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
        
        // Fix position of annotations near North (critical regions). Explained in xPositionFotAnnotationView
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
    
    fileprivate func positionAnnotationViews() {
        for annotationView in self.annotationsViews {
            let x = self.xPositionForAnnotationView(annotationView, heading: self.trackingManager.heading)
            let y = self.yPositionForAnnotationView(annotationView)
            annotationView.frame = CGRect(x: x, y: y, width: annotationView.bounds.size.width, height: annotationView.bounds.size.height)
        }
    }
    
    fileprivate func xPositionForAnnotationView(_ annotationView: ARAnnotationView, heading: Double) -> CGFloat {
        if annotationView.annotation == nil {
            return 0
        }
        let annotation = annotationView.annotation!
        
        // Azimuth
        let azimuth = annotation.azimuth
        
        // Calculating x position
        var xPos: CGFloat = CGFloat(azimuth) * H_PIXELS_PER_DEGREE - annotationView.bounds.size.width / 2.0
        
        // Fixing position in critical areas (near north).
        // If current heading is right of norht (< 40), annotations that are between 320 - 360 won't be visible so we change their position so they are visible. Also if
        // current heading is left of north (320 - 360), annotations that are between 0 - 40 won't be visible so we change their position so they are visible.
        // This is needed because all annotation views are on the same overaly view so that views at the start and the end of the overlay view can't be visible at the same time.
        let threshold: Double = 40
        if heading < threshold {
            if annotation.azimuth > (360 - threshold) {
                xPos = -(OVERLAY_VIEW_WIDTH - xPos);
            }
        } else if heading > (360 - threshold) {
            if annotation.azimuth < threshold {
                xPos = OVERLAY_VIEW_WIDTH + xPos;
            }
        }
        return xPos
    }
    
    fileprivate func yPositionForAnnotationView(_ annotationView: ARAnnotationView) -> CGFloat {
        if annotationView.annotation == nil {
            return 0
        }
        let annotation = annotationView.annotation!
        
        let annotationViewHeight: CGFloat = annotationView.bounds.size.height
        var yPos: CGFloat = (self.view.bounds.size.height * 0.65) - (annotationViewHeight * CGFloat(annotation.verticalLevel))
        yPos -= CGFloat(powf(Float(annotation.verticalLevel), 2) * 4)
        return yPos
    }
    
    fileprivate func calculateVericalLevels() {
        // It's faster with the NS libraries than the swift collection calsses
        let dictionary: NSMutableDictionary = NSMutableDictionary()
        
        // Creating a dictionary for each vertical level
        for level in stride(from: 0, to: self.maxVerticalLevel + 1, by: 1) {
            let array = NSMutableArray()
            dictionary[Int(level)] = array
        }
        
        // Putting each annotation in its dictionary (each level has its own dictionary)
        for i in stride(from: 0, to: self.activeAnnotations.count, by: 1) {
            let annotation = self.activeAnnotations[i] as ARAnnotation
            if annotation.verticalLevel <= self.maxVerticalLevel {
                let array = dictionary[annotation.verticalLevel] as? NSMutableArray
                array?.add(annotation)
            }
        }
        
        // Calculating the annotation view's width in degrees. Asuming all annotation views have the same width.
        var annotationWidthInDegrees: Double = 0
        if let annotationWidth = self.getAnyAnnotationView()?.bounds.size.width {
            annotationWidthInDegrees = Double(annotationWidth / H_PIXELS_PER_DEGREE)
        }
        if annotationWidthInDegrees < 5 {
            annotationWidthInDegrees = 5
        }
        
        // Calculating the vertical levels
        var minVerticalLevel: Int = Int.max
        for level in stride(from: 0, to: self.maxVerticalLevel + 1, by: 1) {
            let annotationsForCurrentLevel = dictionary[(level as Int)] as! NSMutableArray
            let annotationsForNextLevel = dictionary[((level + 1) as Int)] as? NSMutableArray
            
            for i in stride(from: 0, to: self.annotationsForCurrentLevel.count, by: 1) {
                let annotation1 = annotationsForCurrentLevel[i] as! ARAnnotation
                
                // Can happen if it was moved to the next level by previous annotation, it will be handled in the next loop
                if annotation1.verticalLevel != level {
                    continue
                }
                
                for j in stride(from: (i+1), to: annotationsForCurrentLevel.count, by: 1) {
                    let annotation2 = annotationsForCurrentLevel[j] as! ARAnnotation
                    if annotation1 == annotation2 || annotation2.verticallevel != level {
                        continue
                    }

                    // Check if views are coilliing horizontally. Using azimuth instead of view position in pixel to improve performance.
                    var deltaAzimuth = deltaAngle(annotaiton1.azimuth, angle2: annotation2.azimuth)
                    deltaAzimuth = fabs(deltaAzimuth)
                    
                    // No Collision
                    if deltaAzimuth > annotationWidthInDegrees {
                        continue
                    }
                    
                    // Current annotation is farther away from user than comparing an annotaiton, the current annotation will be pushed to the next level
                    if annotation1.distanceFromUser > annotation2.distanceFormUser {
                        annotation1.verticalLevel += 1
                        if annotationForNextlevel != nil {
                            annotationsForNextLevel?.add(annotation1)
                        }
                        // The current annotation was moved to the next level so there is no need to continue with this level
                        break
                    }
                    // The compared annotation will be pushed to the next level because it is further away
                    else {
                        annotation2.verticalLevel += 1
                        if annotationsForNextLevel != nil {
                            annotationsForNextLevel?.add(annotation2)
                        }
                    }
                }
                
                if annotation1.verticalLevel == level {
                    minVerticalLevel = Int(fmin(Float(minVerticalLevel), Float(annotation1.verticalLevel)))
                }
            }
        }
        
        // Lower all annotations if there are no lower level annotations
        for annotation in self.activeAnnotations {
            if annotation.verticalLevel <= self.maxVerticalLevel {
                annotation.verticalLevel -= minVerticalLevel
            }
        }
    }
    
    // It is expected that annotations are sorted by distance before this method is called
    fileprivate func setInitialVerticalLevels() {
        if self.activeAnnotations.count == 0 {
            return
        }
        
        // Fetch annotations filtered by maximumDistance and maximumAnnodationsOnScreen
        let activeAnnotations = self.activeAnnotations
        var minDistance = activeAnnotations.first!.distanceFromUser
        var maxDistance = activeAnnotations.last!.distanceFromUser
        
        if self.maxDistance > 0 {
            minDistance = 0;
            maxDistance = self.maxDistance
        }
        
        var deltaDistance = maxDistance - minDistance
        let maxLevel: Double = Double(self.maxVerticalLevel)
        
        // First reset vertical levels for all annotations
        for annotation in self.annotaitons {
            annotation.verticalLevel = self.maxVerticalLevel + 1
        }
        
        if deltaDistance <= 0 {
            deltaDistance = 1
        }
        
        // Calculate vertical levels for active annotations
        for annotation in activeAnnotations {
            let verticalLevel = Int(((annotation.distanceFromUser - minDistance) / deltaDistance) * maxLevel)
            annotation.verticalLevel = verticalLevel
        }
    }
    
    fileprivate func getAnnotationView() -> ARAnnotationView? {
        var anyAnnotaitonView: ARAnnotationView? = nil
        
        if let annotationView = self.annotationsViews.first {
            anyAnnotaitonView = annotationView
        }  else if let annotation = self.activeAnnotations.first {
            anyAnnotaitonView = self.dataSource?.ar(self, viewForAnnotation: annotation)
        }
        
        return anyAnnotaitonView
    }
    
    // MARK: - Main Logic
    
    fileprivate func reload(calculateDistanceAndAzimuth: Bool, calculateVerticalLevels: Bool, createAnnotationViews: Bool) {
        if calculateDistanceAndAzimuth {
            // Sort by distance is needed only if creating new views
            let sort = createAnnotationViews
            // Calculations for all annotations should be donde only when creating annotations views
            let onlyForActiveAnnotaitons = !createAnnotationViews
            self.calculateDistanceAndAzimuthForAnnotations(sort: sort, onlyForActiveAnnotations: onlyForActiveAnnotaitons)
        }
        
        if createAnnotationViews {
            self.activeAnnotations = filteredAnnotations(nil, maxVisibleAnnotations: self.maxVisibleAnnotations, maxDistance: self.maxDistance)
            self.setInitialVerticalLevels()
        }
        
        if calculateVerticalLevels {
            self.calculateVericalLevels()
        }
        
        if createAnnotationViews {
            self.createAnnotationViews()
        }
        
        self.positionAnnotationViews()
        
        // Calling bindUI on every annotation view so it can referesh its content, doing this every time distance chages, in case distance is needed for display
        if calculateDistanceAndAzimuth {
            for annotationView in self.annotationsViews {
                annotationView.bindUI()
            }
        }
    }
    
    // Determines which annotations are active and which are inactive. If some of the input parameters are nil, then it won't filter by that parameter
    fileprivate func filteredAnnotations(_ maxVerticalLevels: Int?, maxVisibleAnnotations: Int?, maxDistance: Double?) -> [ARAnnotation] {
        let nsAnnotaitons: NSMutableArray = NSMutableArray(array: self.annotaitons)
        var filteredAnnotations: [ARAnnotation] = []
        var count = 0
        let checkMaxVisibleAnnotations = maxVisibleAnnotations != nil
        let checkMaxVerticalLevel = maxVerticalLevel != nil
        let checkMaxDistance = maxDistance != nil
        
        for nsAnnotation in nsAnnotaitons {
            let annotation = nsAnnotation as! ARAnnotation
            
            // Filter by maxVisibleAnnotaitons
            if checkMaxVisibleAnnotations && count >= maxVisibleAnnotations! {
                annotation.active = false
                continue
            }
            
            // Filter by maxVerticalLevel and maxDistance
            if (!checkMaxVerticalLevel || annotation.verticalLevel <= maxVerticalLevel!) &&
                (checkMaxDistance || self.maxDistance == 0 || annotation.distanceFromUser <= maxDistance!) {
                filteredAnnotations.append(annotation)
                annotation.active = true
                count += 1;
            } else {
                annotation.active = false
            }
        }
        
        return filteredAnnotations
    }
    
}
