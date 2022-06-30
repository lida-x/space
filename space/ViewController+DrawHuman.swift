
import UIKit
import AVFoundation
import Vision

extension ViewController{
    
    
    func drawHuman(points: [VNHumanBodyPoseObservation.JointName : VNRecognizedPoint]){
        detectionOverlay.addSublayer(drawHead(points: points))
        detectionOverlay.addSublayer(drawNeck(points: points))
        drawBody(points: points)
    }
    
    func drawHead(points: [VNHumanBodyPoseObservation.JointName : VNRecognizedPoint]) -> CAShapeLayer{
        let drawingHead: [VNHumanBodyPoseObservation.JointName] = [
            .leftEar,
            .rightEar,
            .leftEye,
            .rightEye,
            .nose,
        ]
        
        let headPoints: [CGPoint] = drawingHead.compactMap {
            guard let point = points[$0], point.confidence > 0 else { return nil }
            return VNImagePointForNormalizedPoint(point.location, Int(self.bufferSize.width), Int(self.bufferSize.height))
        }
        for point in headPoints {
            let pointView = self.createPoint(point: point, color: CGColor(red: 0.7, green: 0, blue: 0.7, alpha: 0.75))
            detectionOverlay?.addSublayer(pointView)
        }
        
        let shape = CAShapeLayer()
        
        var coordX = headPoints.map{$0.x}
        var coordY = headPoints.map{$0.y}
        if(coordX.isEmpty || coordY.isEmpty){ return shape}
        let halfWidth = (coordY.max()! - coordY.min()!) / 2
        
        coordX.append(contentsOf: [coordX.min()! - halfWidth * 1.7, coordX.max()! + halfWidth * 1.2])
        coordY.append(contentsOf: [coordY.min()! - halfWidth * 0.2, coordY.max()! + halfWidth * 0.2])
        let begin = CGPoint(x: coordX.min()!, y: coordY.min()!)
        let end = CGPoint(x: coordX.max()!, y: coordY.max()!)
        
        let path = CGMutablePath()
        path.addEllipse(in: CGRect(origin: begin, size: CGSize(width: end.x - begin.x, height: end.y - begin.y)))
        path.closeSubpath()
        
        shape.path = path
        shape.lineWidth = 2.0
        shape.strokeColor = CGColor(red: 0.9, green: 0, blue: 0.9, alpha: 0.8)
        shape.fillColor = CGColor(red: 0.9, green: 0, blue: 0.9, alpha: 0.25)
        
        return shape
    }
    
    func drawNeck(points: [VNHumanBodyPoseObservation.JointName : VNRecognizedPoint]) -> CAShapeLayer{
        
        let drawingNeck: [VNHumanBodyPoseObservation.JointName] = [
            .leftEye,
            .rightEye,
            .neck,
        ]
        let neckPoints: [CGPoint] = drawingNeck.compactMap {
            guard let point = points[$0], point.confidence > 0 else { return nil }
            return VNImagePointForNormalizedPoint(point.location, Int(self.bufferSize.width), Int(self.bufferSize.height))
        }
        let shape = CAShapeLayer()
        
        let coordX = neckPoints.map{$0.x}
        let coordY = neckPoints.map{$0.y}
        if(coordX.isEmpty || coordY.isEmpty){ return shape}
        let begin = CGPoint(x: coordX.min()!, y: coordY.min()!)
        let end = CGPoint(x: coordX.max()!, y: coordY.max()!)
        
        let path = CGMutablePath()
        path.addRect(CGRect(origin: begin, size: CGSize(width: end.x - begin.x, height: end.y - begin.y)))
        path.closeSubpath()
        
        shape.path = path
        shape.fillColor = CGColor(red: 0.9, green: 0, blue: 0.9, alpha: 0.25)
        
        return shape
    }
    
    func drawBody(points: [VNHumanBodyPoseObservation.JointName : VNRecognizedPoint]){
        
        let jointNames: [VNHumanBodyPoseObservation.JointName] = [
            // Arms
            .leftShoulder,
            .rightShoulder,
            .leftElbow,
            .rightElbow,
            .leftWrist,
            .rightWrist,
            // Waist
            .root,
            // Legs
            .leftHip,
            .rightHip,
            .leftKnee,
            .rightKnee,
            .leftAnkle,
            .rightAnkle,
        ]
        
        
        //                     Retrieve the CGPoints containing the normalized X and Y coordinates.
        let imagePoints: [CGPoint] = jointNames.compactMap {
            guard let point = points[$0], point.confidence > 0 else { return nil }
            // Translate the point from normalized-coordinates to image coordinates.
            return VNImagePointForNormalizedPoint(point.location, Int(self.bufferSize.width), Int(self.bufferSize.height))
        }
        // Draw the points onscreen.
        for point in imagePoints {
            let pointView = self.createPoint(point: point, color: CGColor(red: 1, green: 0, blue: 0, alpha: 0.75))
            detectionOverlay?.addSublayer(pointView)
        }
        let rectView = self.createRectangle(points: imagePoints)
        detectionOverlay?.addSublayer(rectView)
    }
    
    func createPoint(point: CGPoint, color: CGColor) -> CALayer {
        let dimention = 8.0
        let bounds = CGRect(x: point.x, y: point.y, width: dimention, height: dimention)
        let pointLayer = CALayer()
        pointLayer.name = "Point"
        pointLayer.bounds = bounds
        pointLayer.position = CGPoint(x: bounds.midX, y: bounds.midY)
        pointLayer.backgroundColor = color
        pointLayer.cornerRadius = dimention / 2
        return pointLayer
    }
    
    func createRectangle(points: [CGPoint]) -> CALayer {
        let coordX = points.map{$0.x}
        let coordY = points.map{$0.y}
        let begin = CGPoint(x: coordX.min()!, y: coordY.min()!)
        let end = CGPoint(x: coordX.max()!, y: coordY.max()!)
        let bounds = CGRect(origin: begin, size: CGSize(width: end.x - begin.x, height: end.y - begin.y))
        let pointLayer = CALayer()
        pointLayer.name = "Shape"
        pointLayer.bounds = bounds
        pointLayer.position = CGPoint(x: bounds.midX, y: bounds.midY)
        pointLayer.backgroundColor = CGColor(red: 0, green: 1, blue: 1, alpha: 0.25)
        return pointLayer
    }
}
