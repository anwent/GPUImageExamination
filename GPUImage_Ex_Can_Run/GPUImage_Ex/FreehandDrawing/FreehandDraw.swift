//
//  FreehandDraw.swift
//  Doodling
//
//  Created by wow250250 on 2017/8/2.
//  Copyright © 2017年 ZZH. All rights reserved.
//

import UIKit

class FreehandDraw: NSObject {
    
    public var setDrawColor: UIColor {
        get { return drawColor }
        set { drawColor = newValue }
    }
    
    public var setDrawLineWidth: CGFloat {
        get { return drawLineWidth }
        set { drawLineWidth = newValue }
    }
    
    private var drawColor: UIColor = .yellow
    private var drawLineWidth: CGFloat = 12.0
    private var canvas: (Canvas & DrawCommandReceiver)?
    private var lineStrokeCommand: ComposedCommand?
    private var commandQueue: [DrawCommand] = []
    private var lastPoint: CGPoint = CGPoint.zero
    private var lastSegment: Segment?
    private var lastVelocity: CGPoint = CGPoint.zero
    private var lastWidth: CGFloat?
    
    public var lineCommands: [LineDrawCommand] = [] 
    
    var points = [CGPoint?](repeating: nil, count: 5)
    var counter:Int?
    
    init(canvas: (Canvas & DrawCommandReceiver)?, to view: UIView) {
        self.canvas = canvas
        super.init()
        setupGesturesRecognizers(in: view)
    }
    
    deinit {
        print("Release --- FreehandDraw ----")
    }
    
    public func revoked() {
        if self.commandQueue.count > 0 {
            self.commandQueue.removeLast()
            self.canvas?.reset()
            self.canvas?.executeCommands(self.commandQueue)
        }
    }

    // MARK: gestures
    private func setupGesturesRecognizers(in view: UIView) {
        let panRecognizer = UIPanGestureRecognizer(target: self, action: #selector(self.panGesture(sender:)))
        panRecognizer.delaysTouchesBegan = false
        panRecognizer.delaysTouchesEnded = false
        view.addGestureRecognizer(panRecognizer)
        
        let tapRecognizer = UITapGestureRecognizer(target: self, action: #selector(self.tapGesture(sender:)))
        view.addGestureRecognizer(tapRecognizer)
    }

    func findAllPointsBetweenTwoPoints(startPoint : CGPoint, endPoint : CGPoint) -> [CGPoint] {
        var allPoints :[CGPoint] = [CGPoint]()
        
        let deltaX = fabs(endPoint.x - startPoint.x)
        let deltaY = fabs(endPoint.y - startPoint.y)
        
        var x = startPoint.x
        var y = startPoint.y
        var err = deltaX-deltaY
        
        var sx = -0.5
        var sy = -0.5
        if(startPoint.x<endPoint.x){
            sx = 0.5
        }
        if(startPoint.y<endPoint.y){
            sy = 0.5;
        }
        
        repeat {
            let pointObj = CGPoint(x: x, y: y)
            allPoints.append(pointObj)
            
            let e = 2*err
            if(e > -deltaY)
            {
                err -= deltaY
                x += CGFloat(sx)
            }
            if(e < deltaX)
            {
                err += deltaX
                y += CGFloat(sy)
            }
        } while (round(x)  != round(endPoint.x) && round(y) != round(endPoint.y));
        
        allPoints.append(endPoint)
        
        return allPoints
    }
    
    @objc private func panGesture(sender: UIPanGestureRecognizer) {
        let point = sender.location(in: sender.view)
        switch sender.state {
        case .began:
            counter = 0
            points[0] = point
            startAtPoint(start: point)
        case .changed:
            counter = counter! + 1
            points[counter!] = point
            if counter == 4 {
                points[3] = CGPoint(x: (points[2]!.x + points[4]!.x)/2.0, y: (points[2]!.y + points[4]!.y)/2.0)
                continueAtPoint(continueat: point, velocity: sender.velocity(in: sender.view))
                points[0]! = points[3]!
                points[1]! = points[4]!
                counter = 1
            }
        case .ended:
            endAtPoint(end: point)
            counter = 0
        case .failed:
            endAtPoint(end: point)
        default:
            assert(false, "UIPanGestureRecognizer status not handled")
        }
    }

    @objc private func tapGesture(sender: UITapGestureRecognizer) {
        let point = sender.location(in: sender.view)
        if sender.state == .ended {
            tapAtPoint(tap: point)
        }
    }
    
    // MARK: Draw Commands
    private func startAtPoint(start point: CGPoint) {
        lastPoint = point
        lineStrokeCommand = ComposedCommand(commadns: [])
    }

    /// - velocity: 绘制中的速度,控制线条粗细
    private func continueAtPoint(continueat point: CGPoint, velocity: CGPoint) {
        let segmentWith: CGFloat = Modulation.modulationWidth(width: drawLineWidth,
                                                              velocity: velocity,
                                                              previousVelocity: lastVelocity,
                                                              previousWidth: lastWidth ?? drawLineWidth)
        let segment = Segment(a: lastPoint, b: point, width: segmentWith)
        let lineCommand = LineDrawCommand(current: segment,
                                          previous: lastSegment,
                                          lineWidth: segmentWith,
                                          lineColor: drawColor,
                                          points: points)
        lineCommands.append(lineCommand)
        canvas?.executeCommands([lineCommand])
        lineStrokeCommand?.addCommand(lineCommand)
        lastPoint = point
        lastSegment = segment
        lastVelocity = velocity
        lastWidth = segmentWith
    }
    
    private func endAtPoint(end point: CGPoint) {
        if let lineStrokeCommand = lineStrokeCommand {
            commandQueue.append(lineStrokeCommand)
        }
        lastPoint = .zero
        lastSegment = nil
        lastVelocity = .zero
        lastWidth = nil
        lineStrokeCommand = nil
    }
    
    private func tapAtPoint(tap point: CGPoint) {
        let circleCommand = CircleDrawCommand(circelCenter: point,
                                              circelRadius: drawLineWidth * 0.5,
                                              circelColor: drawColor)
        canvas?.executeCommands([circleCommand])
        commandQueue.append(circleCommand)
    }
}
