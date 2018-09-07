//
//  AnnotationView.swift
//  Places
//
//  Created by Carlos Arenas on 9/7/18.
//  Copyright © 2018 Razeware LLC. All rights reserved.
//

import UIKit

protocol AnnotationViewDelegate {
  func didTouch(annotationView: AnnotationView)
}

class AnnotationView: ARAnnotationView {
  var titleLabel: UILabel?
  var distanceLabel: UILabel?
  var delegate: AnnotationViewDelegate?
  
  override func didMoveToSuperview() {
    super.didMoveToSuperview()
    loadUI()
  }
  
  func loadUI() {
    titleLabel?.removeFromSuperview()
    distanceLabel?.removeFromSuperview()
    
    let label = UILabel(frame: CGRect(x: 10, y: 0, width: self.frame.size.width, height: 30))
    label.font = UIFont.systemFont(ofSize: 16.0)
    label.numberOfLines = 0
    label.backgroundColor = UIColor(white: 0.4, alpha: 0.7)
    label.textColor = UIColor.white
    self.addSubview(label)
    self.titleLabel = label
    
    distanceLabel = UILabel(frame: CGRect(x: 10, y: 30, width: self.frame.size.width, height: 20))
    distanceLabel?.backgroundColor = UIColor(white: 0.3, alpha: 0.7)
    distanceLabel?.textColor = UIColor.green
    distanceLabel?.font = UIFont.systemFont(ofSize: 12)
    self.addSubview(distanceLabel!)
    
    if let annotation = annotation as? Place {
      titleLabel?.text = annotation.placeName
      distanceLabel?.text = String(format: "%.2f km", annotation.distanceFromUser / 1000)
    }
  }
}
