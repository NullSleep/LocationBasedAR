//
//  ARAnnotationView.swift
//  LocationBasedAR
//
//  Created by Carlos Arenas on 7/24/18.
//  Copyright © 2018 Carlos Arenas. All rights reserved.
//

import UIKit

// The view of the annotation. Annotation views should be lightweight and try to avoid xibs and autolayout.

open class ARAnnotationView: UIView {
    open weak var annotation: ARAnnotation?
    fileprivate var initialized: Bool = false
    
    public init() {
        super.init(frame: CGRect.zero)
        self.initializeInternal()
    }
    
    public required init?(coder aDecoder: NSCoder) {
        super .init(coder: aDecoder)
        self.initializeInternal()
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        self.initializeInternal()
    }
    
    fileprivate func initializeInternal() {
        if self.initialized {
            return
        }
        
        self.initialized = true
        self.initialize()
    }
    
    open override func awakeFromNib() {
        self.bindUI()
    }
    
    // Will always be called once, no need to call super
    open func initialize() {
    
    }
    
    // Called when distance/azimuth changes, intended to be used in subclasses
    open func bindUI() {
        
    }
}
