//
//  ARConfiguration.swift
//  LocationBasedAR
//
//  Created by Carlos Arenas on 7/25/18.
//  Copyright © 2018 Carlos Arenas. All rights reserved.
//

import CoreLocation
import UIKit

let LAT_LON_FACTOR: CGFloat = 1.33975031663                     // Used in azimuth calculation. Shouldn't be changed.
let VERTICAL_SENS: CGFloat = 960
let H_PIXELS_PER_DEGREE: CGFloat = 14                           // How mnay pixels per degree
let OVERLAY_VIEW_WIDTH: CGFloat = 360 * H_PIXELS_PER_DEGREE     // 360 degrees x sensitivity

let MAX_VISIBLE_ANNOTATIONS: Int = 500                          // Changing this can affect the performance
let MAX_VERTICAL_LEVELS: Int = 10                               // Changing this can affect the performance

