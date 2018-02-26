//
//  NWJCGameLoaderView.swift
//  IOSCasino
//
//  Created by Duncan Scholtz on 2015/06/04.
//  Copyright (c) 2015 Microgaming. All rights reserved.
//

import UIKit

class NWJCGameLoaderView: UIView {
  
  fileprivate var splash: UIImage?
  
  convenience init (splash : UIImage?, heightOffset:CGFloat){
    self.init()
    self.splash = splash
    self.setup(heightOffset)
  }
  
  fileprivate func setup(_ heightOffset:CGFloat){
    if let splash = self.splash {
      let mainView = UIImageView(image: splash)
      mainView.translatesAutoresizingMaskIntoConstraints = false
      self.addSubview(mainView);
      
      //YAY magic numbers, thanks HTML5...
      
      var width: CGFloat = 0
//      var height: CGFloat = -23.0
      
      if UIDevice.current.userInterfaceIdiom == .phone {
        if UIScreen.main.bounds.size.height == 736.0 {
          width = -24.0
//          height = -38.0
        }else if UIScreen.main.bounds.size.height == 480.0 {
//          height = -20.0
        }
      }else if UIDevice.current.userInterfaceIdiom == .pad {
        if UIScreen.main.scale == 2 {
          width = -28.0
//          height = -40.0
        }else{
//          height = -20.0
        }
      }
      
      mainView.contentMode = .scaleAspectFit
      
      self.addConstraint(NSLayoutConstraint(item: mainView, attribute: .width, relatedBy: .equal, toItem: self, attribute: .width, multiplier: 1, constant: width))
      
      self.addConstraint(NSLayoutConstraint(item: mainView, attribute: .centerX, relatedBy: .equal, toItem: self, attribute: .centerX, multiplier: 1, constant: 0))
      self.addConstraint(NSLayoutConstraint(item: mainView, attribute: .centerY, relatedBy: .equal, toItem: self, attribute: .centerY, multiplier: 1, constant: heightOffset))
      
    } else {
      let animationSize = CGFloat(4.5) //TODO: use me !!
      
      let mainView = UIView()
      mainView.translatesAutoresizingMaskIntoConstraints = false
      mainView.clipsToBounds = false
      self.addSubview(mainView);
			
			for i in 0...2 {
        let animation = UIView();
        animation.backgroundColor = UIColor(red: 170/255, green: 170/255, blue: 170/255, alpha: 1)
        //        animation.backgroundColor = UIColor.redColor()
        animation.translatesAutoresizingMaskIntoConstraints = false
        animation.clipsToBounds = false
        animation.layer.cornerRadius = animationSize
        
        mainView.addSubview(animation)
        
        //Create animation
        let keyAnimation = CAKeyframeAnimation()
        keyAnimation.keyPath = "transform"
        keyAnimation.values = [
          NSValue(caTransform3D:CATransform3DScale(CATransform3DIdentity, 0, 0, 0)),
          NSValue(caTransform3D:CATransform3DScale(CATransform3DIdentity, 1, 1, 0)),
          NSValue(caTransform3D:CATransform3DScale(CATransform3DIdentity, 0, 0, 0)),
          NSValue(caTransform3D:CATransform3DScale(CATransform3DIdentity, 0, 0, 0))
        ]
        
        keyAnimation.beginTime = CACurrentMediaTime() + (0.16 * Double(i));
        keyAnimation.keyTimes = [0, 0.4, 0.8, 1] //0%, 40%, 80%, 100% (Same as HTML5)
        keyAnimation.duration = 1.4
        keyAnimation.repeatCount = Float(Int.max)
        keyAnimation.timingFunctions = [CAMediaTimingFunction(name: kCAMediaTimingFunctionEaseInEaseOut)]
        keyAnimation.isRemovedOnCompletion = false;
        
        animation.layer.transform = CATransform3DScale(CATransform3DIdentity, 0, 0, 0)
        animation.layer.add(keyAnimation, forKey: "animation.scale")
      }
      
      let views = ["animation1" : mainView.subviews[0], "animation2" : mainView.subviews[1], "animation3" : mainView.subviews[2], ]
      
      mainView.addConstraints(NSLayoutConstraint.constraints(withVisualFormat: "H:|[animation1(9)]-2-[animation2(9)]-2-[animation3(9)]|", options: [], metrics: nil, views: views))
      mainView.addConstraints(NSLayoutConstraint.constraints(withVisualFormat: "V:|-30-[animation1(9)]|", options: [], metrics: nil, views: views))
      mainView.addConstraints(NSLayoutConstraint.constraints(withVisualFormat: "V:|-30-[animation2(9)]|", options: [], metrics: nil, views: views))
      mainView.addConstraints(NSLayoutConstraint.constraints(withVisualFormat: "V:|-30-[animation3(9)]|", options: [], metrics: nil, views: views))
      
      
      self.addConstraint(NSLayoutConstraint(item: mainView, attribute: .centerX, relatedBy: .equal, toItem: self, attribute: .centerX, multiplier: 1, constant: 0))
      self.addConstraint(NSLayoutConstraint(item: mainView, attribute: .centerY, relatedBy: .equal, toItem: self, attribute: .centerY, multiplier: 1, constant: 0))
    }
  }
}
