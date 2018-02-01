//
//  smooth.swift
//  Doodling
//
//  Created by sin on 3/8/2017.
//  Copyright © 2017年 ZZH. All rights reserved.
//

import Foundation
import UIKit

class SmoothCurvedLinesView: UIView {
    var strokeColor = UIColor.blue
    var lineWidth: CGFloat = 20
    var snapshotImage: UIImage?
    
    private var path: UIBezierPath?
    private var temporaryPath: UIBezierPath?
    private var points = [CGPoint]()
    
    override func draw(_ rect: CGRect) {
        snapshotImage?.draw(in: rect)
        
        strokeColor.setStroke()
        
        path?.stroke()
        temporaryPath?.stroke()
    }
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        let touch: AnyObject? = touches.first
        points = [touch!.location(in: self)]
    }
    
    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        let touch: AnyObject? = touches.first
        let point = touch!.location(in: self)
        
        points.append(point)
        
        updatePaths()
        
        self.setNeedsDisplay()
    }
    
    private func updatePaths() {
        let pointCount = points.count
        
        // update main path
        
        while points.count > 4 {
            points[3] = CGPoint(x: (points[2].x + points[4].x)/2.0, y: (points[2].y + points[4].y)/2.0)
            
            if path == nil {
                path = createPathStartingAtPoint(point: points[0])
            }
            
            path?.addCurve(to: points[3], controlPoint1: points[1], controlPoint2: points[2])
            
            points.removeFirst(3)
        }
        
        // build temporary path up to last touch point
        
        if pointCount == 2 {
            temporaryPath = createPathStartingAtPoint(point: points[0])
            temporaryPath?.addLine(to: points[1])
        } else if pointCount == 3 {
            temporaryPath = createPathStartingAtPoint(point: points[0])
            temporaryPath?.addQuadCurve(to: points[2], controlPoint: points[1])
        } else if pointCount == 4 {
            temporaryPath = createPathStartingAtPoint(point: points[0])
            temporaryPath?.addCurve(to: points[3], controlPoint1: points[1], controlPoint2: points[2])
        }
    }
    
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        self.constructIncrementalImage()
        path = nil
        self.setNeedsDisplay()
    }
    
    override func touchesCancelled(_ touches: Set<UITouch>?, with event: UIEvent?) {
        self.touchesEnded(touches!, with: event)
    }
    
    private func createPathStartingAtPoint(point: CGPoint) -> UIBezierPath {
        let localPath = UIBezierPath()
        
        localPath.move(to: point)
        
        localPath.lineWidth = lineWidth
        localPath.lineCapStyle = .round
        localPath.lineJoinStyle = .round
        
        return localPath
    }
    
    private func constructIncrementalImage() {
        UIGraphicsBeginImageContextWithOptions(self.bounds.size, false, 0.0)
        strokeColor.setStroke()
        snapshotImage?.draw(at: CGPoint.zero)
        path?.stroke()
        temporaryPath?.stroke()
        snapshotImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
    }
}
