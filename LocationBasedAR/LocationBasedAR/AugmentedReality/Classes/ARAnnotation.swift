//
//  ARAnnotation.swift
//  LocationBasedAR
//
//  Created by Carlos Arenas on 7/24/18.
//  Copyright © 2018 Carlos Arenas. All rights reserved.
//

import Foundation
import CoreLocation

// Defintes POI with title and location
open class ARAnnotation: NSObject {
    // Properties
    open var title: String?
    open var location: CLLocation?
    // The view for the annotation. It is set inside ARViewController after feteching the view from the dataSource
    internal(set) open var annotationView: ARAnnotationView?
    
    // For internal use only. These properties should no be set.
    internal(set) open var distanceFromUser: Double = 0
    internal(set) open var azimuth: Double = 0
    internal(set) open var verticalLevel: Int = 0
    internal(set) open var active: Bool = false
}
