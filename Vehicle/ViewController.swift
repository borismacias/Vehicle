//
//  ViewController.swift
//  Floor is Lava
//
//  Created by Boris Alexis Gonzalez Macias on 11/19/17.
//  Copyright © 2017 PantlessDev. All rights reserved.
//

import UIKit
import ARKit
import CoreMotion

class ViewController: UIViewController, ARSCNViewDelegate {

    @IBOutlet weak var sceneView: ARSCNView!
    
    let configuration = ARWorldTrackingConfiguration()
    let motionManager = CMMotionManager()
    var vehicle = SCNPhysicsVehicle()
    var orientation = CGFloat()
    var touched:Bool = false
    var accelerationValues = [UIAccelerationValue(0), UIAccelerationValue(0)]
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.sceneView.debugOptions = [ARSCNDebugOptions.showFeaturePoints, ARSCNDebugOptions.showWorldOrigin]
        self.sceneView.session.run(configuration)
        self.configuration.planeDetection = .horizontal
        setUpAccelerometer()
        self.sceneView.delegate = self
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    func createConcrete(planeAnchor: ARPlaneAnchor) -> SCNNode {
        let concreteNode = SCNNode(geometry: SCNPlane(width: CGFloat(planeAnchor.extent.x), height: CGFloat(planeAnchor.extent.z)))
        concreteNode.geometry?.firstMaterial?.diffuse.contents = #imageLiteral(resourceName: "concrete")
        concreteNode.geometry?.firstMaterial?.isDoubleSided = true
        concreteNode.position = SCNVector3( planeAnchor.center.x, planeAnchor.center.y, planeAnchor.center.z )
        concreteNode.eulerAngles = SCNVector3(90.degreesToRadians, 0, 0)
        let staticBody = SCNPhysicsBody.static()
        concreteNode.physicsBody = staticBody
        return concreteNode
    }
    
    func renderer(_ renderer: SCNSceneRenderer, didAdd node: SCNNode, for anchor: ARAnchor) {
        guard let planeAnchor = anchor as? ARPlaneAnchor else { return }
        let concreteNode = createConcrete(planeAnchor: planeAnchor)
        node.addChildNode(concreteNode)
    }

    func renderer(_ renderer: SCNSceneRenderer, didUpdate node: SCNNode, for anchor: ARAnchor) {
        guard let planeAnchor = anchor as? ARPlaneAnchor else { return }
        node.enumerateChildNodes { (node, _) in
            node.removeFromParentNode()
        }
        
        let concreteNode = createConcrete(planeAnchor: planeAnchor)
        node.addChildNode(concreteNode)
    }
    
    func renderer(_ renderer: SCNSceneRenderer, didRemove node: SCNNode, for anchor: ARAnchor) {
        guard let _ = anchor as? ARPlaneAnchor else { return }
        node.enumerateChildNodes { (node, _) in
            node.removeFromParentNode()
        }
    }
    
    func renderer(_ renderer: SCNSceneRenderer, didSimulatePhysicsAtTime time: TimeInterval) {
        var engineForce:CGFloat = 0
        self.vehicle.setSteeringAngle(self.orientation, forWheelAt: 0)
        self.vehicle.setSteeringAngle(self.orientation, forWheelAt: 1)
        if self.touched {
            engineForce = -50
        } else {
            engineForce = 0
        }
        
        self.vehicle.applyEngineForce(engineForce, forWheelAt: 2)
        self.vehicle.applyEngineForce(engineForce, forWheelAt: 3)
    }
    
    @IBAction func addCar(_ sender: Any) {
        guard let pointOfView = sceneView.pointOfView else { return }
        let transform = pointOfView.transform
        let orientation = SCNVector3(-transform.m31, -transform.m32, -transform.m33)
        let location = SCNVector3(transform.m41, transform.m42, transform.m43)
        let currentPositionOfCamera = orientation + location
        let scene = SCNScene(named: "car.scn")
        let chassis = (scene?.rootNode.childNode(withName: "chassis", recursively: false))!
        let frontLeftWheel = (chassis.childNode(withName: "frontLeftParent", recursively: false))!
        let rearLeftWheel = (chassis.childNode(withName: "rearLeftParent", recursively: false))!
        let frontRightWheel = (chassis.childNode(withName: "frontRightParent", recursively: false))!
        let rearRightWheel = (chassis.childNode(withName: "rearRightParent", recursively: false))!
        
        let v_frontLeftWheel = SCNPhysicsVehicleWheel(node: frontLeftWheel)
        let v_frontRightWheel = SCNPhysicsVehicleWheel(node: frontRightWheel)
        let v_rearLeftWheel = SCNPhysicsVehicleWheel(node: rearLeftWheel)
        let v_rearRightWheel = SCNPhysicsVehicleWheel(node: rearRightWheel)
        
        let body = SCNPhysicsBody(type: .dynamic, shape: SCNPhysicsShape(node: chassis, options: [ SCNPhysicsShape.Option.keepAsCompound: true]))
        body.mass = 5
        chassis.physicsBody = body
        chassis.position = currentPositionOfCamera
        self.vehicle = SCNPhysicsVehicle(chassisBody: chassis.physicsBody!, wheels: [v_frontLeftWheel, v_frontRightWheel, v_rearLeftWheel, v_rearRightWheel])
        self.sceneView.scene.physicsWorld.addBehavior(self.vehicle)
        self.sceneView.scene.rootNode.addChildNode(chassis)
    }
    
    func setUpAccelerometer(){
        if motionManager.isAccelerometerAvailable {
            motionManager.accelerometerUpdateInterval = 1/60
            motionManager.startAccelerometerUpdates(to: .main, withHandler: { (accelerometerData, error) in
                if let error = error {
                    print(error.localizedDescription)
                    return
                }
                self.accelerometerDidChange(acceleration: (accelerometerData?.acceleration)!)
            })
        }
    }
    
    func accelerometerDidChange(acceleration: CMAcceleration) -> Void {
        accelerationValues[1] = filtered(previousAcceleration: accelerationValues[1], UpdatedAcceleration: acceleration.y)
        accelerationValues[0] = filtered(previousAcceleration: accelerationValues[0], UpdatedAcceleration: acceleration.x)
        orientation = CGFloat(accelerationValues[1])
        if accelerationValues[0] < 0 {
            self.orientation = -orientation
        }
    }
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        self.touched = true
    }
    
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        self.touched = false
    }
    
    func filtered(previousAcceleration: Double, UpdatedAcceleration: Double) -> Double {
        let kfilteringFactor = 0.5
        return UpdatedAcceleration * kfilteringFactor + previousAcceleration * (1-kfilteringFactor)
    }
    
}

extension Int {
    var degreesToRadians: Double { return Double(self) * .pi/180 }
}

func + (left: SCNVector3, right: SCNVector3) -> SCNVector3 {
    return SCNVector3Make(left.x + right.x, left.y + right.y, left.z + right.z )
}
