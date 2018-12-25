//
//  ViewController.swift
//  ARCompass
//
//  Created by Geng Wang on 12/23/18.
//  Copyright © 2018 Geng Wang. All rights reserved.
//

import UIKit
import SceneKit
import ARKit

class ViewController: UIViewController, ARSCNViewDelegate, SCNPhysicsContactDelegate {
    
//    typedef NS_OPTIONS(NSUInteger, CollisionCategory) {
//    CollisionCategoryBottom  = 1 << 0,
//    CollisionCategoryCube    = 1 << 1,
//    };
    
    enum CollisionTypes: Int {
        case bottom  = 1
        case cube    = 2
    }
    
    @IBOutlet var sceneView: ARSCNView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        setupScene()
        setupGestureRecognizers()
        
        // Create a new scene
        //        let scene = SCNScene(named: "art.scnassets/dice/box6.obj")!
        
        // Set the scene to the view
        //        sceneView.scene = scene
    }
    fileprivate func setupScene() {
        // Set the view's delegate
        sceneView.delegate = self
        
        // Show statistics such as fps and timing information
        sceneView.showsStatistics = true
        sceneView.autoenablesDefaultLighting = true
        sceneView.automaticallyUpdatesLighting = true
        
        // Enable debugging
        sceneView.debugOptions = [
              .showWorldOrigin
            , .showFeaturePoints
            , .showBoundingBoxes
            , .showPhysicsShapes
        ]
        
        // Add bottom plane for physics. All boxes fall to this plane will be removed.
        
        // For our physics interactions, we place a large node a couple of meters below the world
        // origin, after an explosion, if the geometry we added has fallen onto this surface which
        // is place way below all of the surfaces we would have detected via ARKit then we consider
        // this geometry to have fallen out of the world and remove it
        
        let bottomPlane = SCNBox(width: 1000.0, height: 0.5, length: 1000.0, chamferRadius: 0.0)
        let bottomPlaneMaterial = SCNMaterial.init()
        bottomPlaneMaterial.diffuse.contents = UIColor.init(red: 0.0, green: 1.0, blue: 0.0, alpha: 0.0)
        bottomPlane.materials = [bottomPlaneMaterial]
        let bottomNode = SCNNode.init(geometry: bottomPlane)
        bottomNode.position = SCNVector3(0.0, -10.0, 0.0)
        bottomNode.physicsBody = SCNPhysicsBody.init(type: SCNPhysicsBodyType.kinematic, shape: nil)
        bottomNode.physicsBody?.categoryBitMask = CollisionTypes.bottom.rawValue
        bottomNode.physicsBody?.contactTestBitMask = CollisionTypes.cube.rawValue
        sceneView.scene.rootNode.addChildNode(bottomNode)
        sceneView.scene.physicsWorld.contactDelegate = self
        
    }
    
    fileprivate func setupSession() {
        // Create a session configuration
        let configuration = ARWorldTrackingConfiguration()
        configuration.planeDetection = .horizontal
        
        // Run the view's session
        sceneView.session.run(configuration)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        setupSession()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        // Pause the view's session
        sceneView.session.pause()
    }
    
    // MARK: - ARSCNViewDelegate
    // - Visualize plane
    func renderer(_ renderer: SCNSceneRenderer, didAdd node: SCNNode, for anchor: ARAnchor) {
   
        guard let planeAnchor = anchor as? ARPlaneAnchor else { return }
        
        let width = CGFloat(planeAnchor.extent.x)
        let height = CGFloat(planeAnchor.extent.z)
        let plane = SCNPlane(width: width, height: height)
        // w: 0.23744837939739227; h: 0.519160270690918
        
        plane.materials.first?.diffuse.contents = UIColor.init(red: 40/255, green: 160/255, blue: 240/255, alpha: 0.2)
        
        let planeNode = SCNNode(geometry: plane)
        let planeShape = SCNPhysicsShape.init(geometry: SCNPlane.init(width: 1000, height: 1000), options: nil)
        planeNode.physicsBody = SCNPhysicsBody.init(type: SCNPhysicsBodyType.kinematic, shape: planeShape)
        planeNode.physicsBody?.categoryBitMask = CollisionTypes.cube.rawValue
        planeNode.physicsBody?.contactTestBitMask = CollisionTypes.cube.rawValue
        
        let x = CGFloat(planeAnchor.center.x)
        let y = CGFloat(planeAnchor.center.y)
        let z = CGFloat(planeAnchor.center.z)
        planeNode.position = SCNVector3(x,y,z)
        planeNode.eulerAngles.x = -.pi / 2
        
        node.addChildNode(planeNode)
    }
    func renderer(_ renderer: SCNSceneRenderer, didUpdate node: SCNNode, for anchor: ARAnchor) {
        
        guard let planeAnchor = anchor as?  ARPlaneAnchor,
            let planeNode = node.childNodes.first,
            let plane = planeNode.geometry as? SCNPlane
            else { return }
        
        let width = CGFloat(planeAnchor.extent.x)
        let height = CGFloat(planeAnchor.extent.z)
        plane.width = width
        plane.height = height
        
 
        let x = CGFloat(planeAnchor.center.x)
        let y = CGFloat(planeAnchor.center.y)
        let z = CGFloat(planeAnchor.center.z)
        planeNode.position = SCNVector3(x, y, z)
    }
    // Override to create and configure nodes for anchors added to the view's session.
    //    func renderer(_ renderer: SCNSceneRenderer, nodeFor anchor: ARAnchor) -> SCNNode? {
    //
    //    }
    //
    @objc func addDiceToSceneView(withGestureRecognizer recognizer: UIGestureRecognizer) {
        let tapLocation = recognizer.location(in: sceneView)
        let hitTestResults = sceneView.hitTest(tapLocation, types: .existingPlaneUsingExtent)
        
        guard let hitTestResult = hitTestResults.first else { return }
        let translation = hitTestResult.worldTransform.position()
        let insertionYOffset: Float = 0.3
        let x = translation.x
        let y = translation.y + insertionYOffset
        let z = translation.z
        
        guard let diceScene = SCNScene(named: "art.scnassets/dice/dice.scn"),
            let diceNode = diceScene.rootNode.childNode(withName: "Dice", recursively: false),
            let keyLightNode = diceScene.rootNode.childNode(withName: "Sun", recursively: false),
            let fillLightNode = diceScene.rootNode.childNode(withName: "Point", recursively: false)
            else { return }

        // Note: Physics body is configured in the scn file.
        // Set the physics shape scale to match that of the transform scale of the geometry
        // mass: 2.0
        // angular damping: 0.8
        //diceCubeNode.physicsBody?.categoryBitMask = CollisionTypes.cube.rawValue;
        
        diceNode.position = SCNVector3(x,y,z)
        sceneView.scene.rootNode.addChildNode(diceNode)
        sceneView.scene.rootNode.addChildNode(keyLightNode)
        sceneView.scene.rootNode.addChildNode(fillLightNode)
    }
    
    @objc func handleLongPress(withGestureRecognizer recognizer: UILongPressGestureRecognizer) {
        let viewTouchLocation:CGPoint = recognizer.location(in: sceneView)
        guard let result = sceneView.hitTest(viewTouchLocation, options: nil).first else {
            return
        }
        if result.node.name == "Dice" {
            
//            CASpringAnimation.init(keyPath: <#T##String?#>)
            // Test quick animation
            SCNTransaction.begin()
            SCNTransaction.animationDuration = 0.333
            SCNTransaction.animationTimingFunction = CAMediaTimingFunction(name: CAMediaTimingFunctionName.easeInEaseOut)
            result.node.position.y = 2
            SCNTransaction.commit()
            // test
//            let diceGeometryNode = result.node.childNode(withName: "Dice", recursively: false)
//            print("--dice?? \(diceGeometryNode)")
            for node in result.node.childNodes {
                print("--node: \(node)")
            }
        }
    }
    
    func setupGestureRecognizers() {
        let tapGestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(ViewController.addDiceToSceneView(withGestureRecognizer:)))
        sceneView.addGestureRecognizer(tapGestureRecognizer)
        
        let longPressRecognizer = UILongPressGestureRecognizer(target: self, action: #selector(ViewController.handleLongPress(withGestureRecognizer:)))
        longPressRecognizer.minimumPressDuration = 0.5
        sceneView.addGestureRecognizer(longPressRecognizer)
    }
    
    func session(_ session: ARSession, didFailWithError error: Error) {
        // Present an error message to the user
        
    }
    
    func sessionWasInterrupted(_ session: ARSession) {
        // Inform the user that the session has been interrupted, for example, by presenting an overlay
        
    }
    
    func sessionInterruptionEnded(_ session: ARSession) {
        // Reset tracking and/or remove existing anchors if consistent tracking is required
        
    }
    
    // MARK - SCNPhysicsContactDelegate
    func physicsWorld(_ world: SCNPhysicsWorld, didBegin contact: SCNPhysicsContact) {
        
//        print("-- did contact!")
        // Here we detect a collision between pieces of geometry in the world, if one of the pieces
        // of geometry is the bottom plane it means the geometry has fallen out of the world. just remove it
//        let contactMask = contact.nodeA.physicsBody?.categoryBitMask | contact.nodeB.physicsBody?.categoryBitMask
        
//        if contactMask == CollisionTypes.bottom.rawValue {
//
//        }
        
//        if (contact.nodeA.physicsBody?.categoryBitMask == CollisionTypes.bottom.rawValue) {
//            contact.nodeB.removeFromParentNode()
//        } else {
//            contact.nodeA.removeFromParentNode()
//        }
    }
}

extension matrix_float4x4 {
    func position() -> SCNVector3 {
        return SCNVector3(columns.3.x, columns.3.y, columns.3.z)
    }
}
