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

// Subclass of ARAnnotationView which is used to show a view for a POI
class AnnotationView: ARAnnotationView {
  
  // The view in this app simply shows a label with the name of the POI and a second label with the
  // distance. These lines declare the needed properties and a third one you again need later
  
  var titleLabel: UILabel?
  var distanceLabel: UILabel?
  var delegate: AnnotationViewDelegate?
  
  override func didMoveToSuperview() {
    super.didMoveToSuperview()
    loadUI()
  }
  
  // Adds and configures the label
  func loadUI() {
    titleLabel?.removeFromSuperview()
    distanceLabel?.removeFromSuperview()
    
    let label = UILabel(frame: CGRect(x: 10, y: 0, width: self.frame.size.width, height: 30))
    label.font = UIFont.systemFont(ofSize: 16.0)
    label.numberOfLines = 0
    label.backgroundColor = UIColor(white: 0.4, alpha: 0.7)
    label.textColor = UIColor.yellow
    self.addSubview(label)
    self.titleLabel = label
    
    distanceLabel = UILabel(frame: CGRect(x: 10, y: 30, width: self.frame.size.width, height: 20))
    distanceLabel?.backgroundColor = UIColor(white: 0.3, alpha: 0.7)
    distanceLabel?.textColor = UIColor.blue
    distanceLabel?.font = UIFont.systemFont(ofSize: 12)
    self.addSubview(distanceLabel!)
    
    if let annotation = annotation as? Place {
      titleLabel?.text = annotation.placeName
      distanceLabel?.text = String(format: "%.2f km", annotation.distanceFromUser / 1000)
    }
  }
  
  // This method is called everytime the view needs to be redrawn and you simply make sure the frames of the
  // label have the correct values resetting them.
  override func layoutSubviews() {
    super.layoutSubviews()
    titleLabel?.frame = CGRect(x: 10, y: 0, width: self.frame.size.width, height: 30)
    distanceLabel?.frame = CGRect(x: 10, y: 30, width: self.frame.size.width, height: 20)
  }
  
  // Here you tell the delegate that a view was touched, so the delegate can decide if and which actions
  // is needed.
  override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
    delegate?.didTouch(annotationView: self)
  }
}
