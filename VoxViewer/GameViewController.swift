//	GameViewController.swift
//	VoxViewer
//
//	Created by Cap'n Slipp on 5/20/16.
//	Copyright (c) 2016 Cap'n Slipp. All rights reserved.

import UIKit
import QuartzCore
import SceneKit
import simd
import MDLVoxelAsset



class GameViewController: UIViewController
{
	override func viewDidLoad()
	{
		super.viewDidLoad()
		
		// create a new scene
		let scene = SCNScene()
		
		
		// create and add a camera to the scene
		
		let cameraNode = SCNNode()
		cameraNode.camera = {
			let c = SCNCamera()
			c.automaticallyAdjustsZRange = true
			return c
		}()
		scene.rootNode.addChildNode(cameraNode)
		
		
		// floor
		
		let floorNode = SCNNode(geometry: {
			let f = SCNFloor()
			f.reflectivity = 0
			return f
		}())
		scene.rootNode.addChildNode(floorNode)
		
		
		// create and add the .vox node
		
		let (ship, shipBounds) = createVoxelModel(named: "monu7")
		let shipCenterpoint = SCNVector3(shipBounds.minBounds + (shipBounds.maxBounds - shipBounds.minBounds) * 0.5)
		scene.rootNode.addChildNode(ship)
		
		
		// place the camera
		
		cameraNode.eulerAngles = SCNVector3(0, 0, 0)
		cameraNode.position = SCNVector3(
			x: 0,
			y: shipCenterpoint.y,
			z: shipBounds.maxBounds.z + (shipBounds.maxBounds.z - shipBounds.minBounds.z) * 0.5 + 15
		)
		
		
		// create and add a light to the scene
		
		let lightNode = SCNNode()
		lightNode.light = {
			let l = SCNLight()
			l.type = SCNLightTypeSpot
			l.color = UIColor(hue: 60.0 / 360.0, saturation: 0.2, brightness: 1.0, alpha: 1.0)
			l.spotOuterAngle = 135
			l.spotInnerAngle = l.spotOuterAngle * 0.9
			l.castsShadow = true
			l.zNear = 1
			l.zFar = {
				let extents = (shipBounds.maxBounds - shipBounds.minBounds)
				return sqrt(
					pow(CGFloat(extents.x), 2) +
					pow(CGFloat(extents.y), 2) +
					pow(CGFloat(extents.z), 2)
				)
			}() * 2
			return l
		}()
		lightNode.position = SCNVector3(x: shipBounds.maxBounds.x, y: shipBounds.maxBounds.y, z: shipBounds.maxBounds.z)
		scene.rootNode.addChildNode(lightNode)
		
		if lightNode.constraints == nil {
			lightNode.constraints = [SCNConstraint]()
		}
		lightNode.constraints!.append(SCNLookAtConstraint(target: ship))
		
		
		// create and add an ambient light to the scene
		
		let ambientLightNode = SCNNode()
		ambientLightNode.light = {
			let l = SCNLight()
			l.type = SCNLightTypeAmbient
			l.color = UIColor(hue: 240.0 / 360.0, saturation: 1.0, brightness: 0.1, alpha: 1.0)
			return l
		}()
		scene.rootNode.addChildNode(ambientLightNode)
		
		
		// axis widget
		
		let axisSphere = SCNSphere(radius: 0.25)
		let coloredSphereNode = {(position:SCNVector3, color:UIColor) -> SCNNode in
			let s = (axisSphere.copy() as! SCNSphere)
			s.firstMaterial = {
				let material = SCNMaterial()
				material.diffuse.contents = color
				return material
			}()
			let n = SCNNode(geometry: s)
			n.position = position
			return n
		}
		let axisSphereNodes = [
			coloredSphereNode(SCNVector3(0.0, 0.0, 0.0), UIColor.whiteColor()),
			coloredSphereNode(SCNVector3(+1.0, 0.0, 0.0), UIColor.redColor()),
			coloredSphereNode(SCNVector3(0.0, +1.0, 0.0), UIColor.greenColor()),
			coloredSphereNode(SCNVector3(0.0, 0.0, +1.0), UIColor.blueColor()),
		]
		for node in axisSphereNodes {
			scene.rootNode.addChildNode(node)
		}
		
		//// animate the 3d object
		//ship.runAction(SCNAction.repeatActionForever(SCNAction.rotateByX(0, y: 2, z: 0, duration: 1)))
		
		// retrieve the SCNView
		let scnView = self.view as! SCNView
		
		// set the scene to the view
		scnView.scene = scene
		
		// allows the user to manipulate the camera
		scnView.allowsCameraControl = true
		
		// show statistics such as fps and timing information
		scnView.showsStatistics = true
		
		// configure the view
		scnView.backgroundColor = UIColor.blackColor()
		
		// add a tap gesture recognizer
		let tapGesture = UITapGestureRecognizer(target: self, action: #selector(handleTap(_:)))
		scnView.addGestureRecognizer(tapGesture)
	}
	
	func createVoxelModel(named name:String) -> (SCNNode, MDLAxisAlignedBoundingBox)
	{
		var path = NSBundle.mainBundle().pathForResource(name, ofType:"")
		if (path == nil) {
			path = NSBundle.mainBundle().pathForResource(name, ofType:"vox")
		}
		
		let asset = MDLVoxelAsset(URL: NSURL(fileURLWithPath: path!))
		let voxelPaletteIndices = asset.voxelPaletteIndices as Array<Array<Array<NSNumber>>>
		let paletteColors = asset.paletteColors as [UIColor]
		
		var coloredBoxes = Dictionary<UIColor, SCNBox>()
		
		// Create voxel grid from MDLAsset
		let grid:MDLVoxelArray = asset.voxelArray
		let voxelData = grid.voxelIndices()!;   // retrieve voxel data
		
		// Create voxel parent node
		let baseNode = SCNNode();
		baseNode.eulerAngles = SCNVector3(GLKMathDegreesToRadians(-90), 0, 0) // Z+ is up in .vox; rotate to Y+:up
		
		// Create the voxel node geometry
		let box = SCNBox(width: 1, height: 1, length: 1, chamferRadius: 0.0);
		
		// Traverse the NSData voxel array and for each ijk index, create a voxel node positioned at its spatial location
		let voxelsIndices = UnsafeBufferPointer<MDLVoxelIndex>(start: UnsafePointer<MDLVoxelIndex>(voxelData.bytes), count: grid.count)
		for voxelIndex in voxelsIndices {
			let position:vector_float3 = grid.spatialLocationOfIndex(voxelIndex);
			
			let colorIndex = voxelPaletteIndices[Int(voxelIndex.x)][Int(voxelIndex.y)][Int(voxelIndex.z)].integerValue
			let color = paletteColors[colorIndex]
			
			// Create the voxel node and set its properties, reusing same-colored particle geometry
			
			var coloredBox:SCNBox? = coloredBoxes[color]
			if (coloredBox == nil) {
				coloredBox = (box.copy() as! SCNBox)
				
				let material = SCNMaterial()
				material.diffuse.contents = color
				coloredBox!.firstMaterial = material
				
				coloredBoxes[color] = coloredBox
			}
			
			let voxelNode = SCNNode(geometry: coloredBox)
			voxelNode.position = SCNVector3(position)
			
			// Add voxel node to the scene
			baseNode.addChildNode(voxelNode);
		}
		
		let boundingBox = grid.boundingBox
		let centerpoint = SCNVector3(boundingBox.minBounds + (boundingBox.maxBounds - boundingBox.minBounds) * 0.5)
		baseNode.pivot = SCNMatrix4MakeTranslation(centerpoint.x, centerpoint.y, 0.0)
		
		return (baseNode.flattenedClone(), boundingBox)
	}
	
	func handleTap(gestureRecognize: UIGestureRecognizer) {
		// retrieve the SCNView
		let scnView = self.view as! SCNView
		
		// check what nodes are tapped
		let p = gestureRecognize.locationInView(scnView)
		let hitResults = scnView.hitTest(p, options: nil)
		// check that we clicked on at least one object
		if hitResults.count > 0 {
			// retrieved the first clicked object
			let result: AnyObject! = hitResults[0]
			
			// get its material
			let material = result.node!.geometry!.firstMaterial!
			
			// highlight it
			SCNTransaction.begin()
			SCNTransaction.setAnimationDuration(0.5)
			
			// on completion - unhighlight
			SCNTransaction.setCompletionBlock {
				SCNTransaction.begin()
				SCNTransaction.setAnimationDuration(0.5)
				
				material.emission.contents = UIColor.blackColor()
				
				SCNTransaction.commit()
			}
			
			material.emission.contents = UIColor.redColor()
			
			SCNTransaction.commit()
		}
	}
	
	override func shouldAutorotate() -> Bool {
		return true
	}
	
	override func prefersStatusBarHidden() -> Bool {
		return true
	}
	
	override func supportedInterfaceOrientations() -> UIInterfaceOrientationMask {
		if UIDevice.currentDevice().userInterfaceIdiom == .Phone {
			return .AllButUpsideDown
		} else {
			return .All
		}
	}
	
	override func didReceiveMemoryWarning() {
		super.didReceiveMemoryWarning()
		// Release any cached data, images, etc that aren't in use.
	}
	
}