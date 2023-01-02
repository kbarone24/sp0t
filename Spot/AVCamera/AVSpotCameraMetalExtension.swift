//
//  AVSpotCameraMetalExtension.swift
//  Spot
//
//  Created by Oforkanji Odekpe on 1/2/23.
//  Copyright © 2023 sp0t, LLC. All rights reserved.
//

import UIKit
import MetalKit

// MARK: - MTKViewDelegate

extension AVSpotCamera: MTKViewDelegate {
    // Tells us the drawable's size has changed
    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
        
    }
    
    // This is where we render to the screen
    func draw(in view: MTKView) {
        // Create command buffer for ciContext to use to encode it's rendering instructions to our GPU
        guard let commandBuffer = metalCommandQueue?.makeCommandBuffer() else {
            return
        }
        
        // Make sure we actually have a ciImage to work with
        guard let ciImage = currentCIImage else {
            return
        }
        
        // Make sure the current drawable object for this metal view is available
        // (it's not in use by the previous draw cycle)
        guard let currentDrawable = view.currentDrawable else {
            return
        }
        
        // scale to fit into view
        let scaleX = view.drawableSize.width / ciImage.extent.width
        let scaleY = view.drawableSize.height / ciImage.extent.height
        let scale = min(scaleX, scaleY)
        let scaledImage = ciImage.transformed(by: CGAffineTransform(scaleX: scale, y: scale))
        
        // center in the view
        let originX = max(view.drawableSize.width - scaledImage.extent.size.width, 0) / 2
        let originY = max(view.drawableSize.height - scaledImage.extent.size.height, 0) / 2
        let centeredImage = scaledImage.transformed(by: CGAffineTransform(translationX: originX, y: originY))
        
        // Render into the metal texture
        
        ciContext?.render(
            centeredImage,
            to: currentDrawable.texture,
            commandBuffer: commandBuffer,
            bounds: CGRect(origin: CGPoint(x: originX, y: originY), size: view.drawableSize),
            colorSpace: CGColorSpaceCreateDeviceRGB()
        )
        
        // Register where to draw the instructions in the command buffer once it executes
        commandBuffer.present(currentDrawable)
        // Commit the command to the queue so it executes
        commandBuffer.commit()
        commandBuffer.waitUntilScheduled()
        currentDrawable.present()
    }
}
