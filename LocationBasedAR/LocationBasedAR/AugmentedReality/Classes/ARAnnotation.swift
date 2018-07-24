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
    
}
