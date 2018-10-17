//
//  ViewController.swift
//  DepthReader
//
//  Created by Or Fleisher on 10/12/18.
//  Copyright © 2018 Or Fleisher. All rights reserved.
//  https://orfleisher.com
//

import Cocoa
import CoreImage
import AVFoundation

class ViewController: NSViewController {

    @IBOutlet weak var SaveButton: NSButton!

    @IBOutlet weak var RGBImageView: NSImageView!
    @IBOutlet weak var DeptImageView: NSImageView!

    var rgbImage: NSImage? = nil
    var depthImage: NSImage? = nil
 
    @IBAction func OnLinkPressed(_ sender: Any) {
        if let url = URL(string: "https://orfleisher.com"),
            NSWorkspace.shared.open(url) {
            
        }
    }
    @IBAction func OnButtonPressed(_ sender: NSButton) {
        
        if sender.title == "Browse" {
            
            let openPanel = NSOpenPanel()
            openPanel.allowedFileTypes = ["jpg"]
            openPanel.allowsMultipleSelection = false
            openPanel.canChooseDirectories = false
            
            openPanel.begin { (result) in
                if result == NSApplication.ModalResponse.OK {
                    
                    guard openPanel.url != nil else {
                        return
                    }
                    
                    let filePath: String = openPanel.url!.relativePath
 
                    // Read the regular image for rendering it to NSImageView
                    if let rgbImage = NSImage(contentsOfFile: filePath) {
                        
                        // Try and read the disparity pixel buffer out of the file
                        if let depthPixelBuffer = self.readDepthDataMap(path: openPanel.url!) {
                            
                            let depthCIImage = CIImage(cvPixelBuffer: depthPixelBuffer)
                            
                            self.depthImage = depthCIImage.convertToNSImage()
                            
                            // Draw the regular (RGB) image to the NSImageView
                            self.RGBImageView.image = rgbImage
                            
                            // Draw the depth image to the NSImageView
                            self.DeptImageView.image = self.depthImage
                            
                            self.SaveButton.isEnabled = true
                            
                        } else {
                            let error = NSError(domain: "Could not find depth data in the image, please make sure you select an image taken with a supported iPhone in portrait mode", code: 0)
                            NSAlert(error: error).runModal()
                        }
                        
                    } else {
                        let error = NSError(domain: "Could not read image, try a different image", code: 0)
                        NSAlert(error: error).runModal()
                    }
                }
            }
        } else if sender.title == "Save" {
            SaveDepthImage()
        }
    }
    
    func readDepthDataMap(path: URL) -> CVPixelBuffer? {
        
        let fileURL: CFURL = path as CFURL
        
        guard let source = CGImageSourceCreateWithURL(fileURL, nil) else {
            return nil
        }
        
        guard let auxDataInfo = CGImageSourceCopyAuxiliaryDataInfoAtIndex(source, 0,
                                                                          kCGImageAuxiliaryDataTypeDisparity) as? [AnyHashable : Any] else {
                                                                            return nil
        }

        var depthData: AVDepthData
        
        do {
            depthData = try AVDepthData(fromDictionaryRepresentation: auxDataInfo)
        } catch {
            return nil
        }
        
        if depthData.depthDataType != kCVPixelFormatType_DepthFloat16 {
            depthData = depthData.converting(toDepthDataType: kCVPixelFormatType_DepthFloat16)
        }
        
        return depthData.depthDataMap
    }
    func SaveDepthImage() -> Void {
        if depthImage != nil {
            
            let savePanel = NSSavePanel()
            savePanel.canCreateDirectories = true
            savePanel.showsTagField = false
            savePanel.nameFieldStringValue = "depth-map.png"
            savePanel.level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.modalPanelWindow)))
            savePanel.begin { (result) in
                if result == NSApplication.ModalResponse.OK {
                    
                    guard let url = savePanel.url else {
                        return
                    }
                    
                    var imageRect:CGRect = CGRect(x: 0,
                                                  y: 0,
                                                  width: self.depthImage!.size.width,
                                                  height: self.depthImage!.size.height)
                    let imageRef = self.depthImage!.cgImage(forProposedRect: &imageRect, context: nil, hints: nil)
                    
                    let bitmapRep = NSBitmapImageRep(cgImage: imageRef!)
                    let data = bitmapRep.representation(using: .png, properties: [:])
                    do {
                        try data?.write(to: url, options: .atomicWrite)
                    } catch {
                        print(error.localizedDescription)
                    }
                }
            }
            
        } else {
            // Depth image hasn't been read yet
        }
    }
}
/*
 * Extensions - TODO Cleanup
 */
extension CIImage {
    
    func convertToNSImage() -> NSImage {
        let rep : NSCIImageRep = NSCIImageRep(ciImage: self)
        let nsImage = NSImage(size: self.extent.size)
        nsImage.addRepresentation(rep)
        return nsImage
    }
    
}

extension String {
    
    func fileExtension() -> String {
        return NSURL(fileURLWithPath: self).pathExtension ?? ""
    }
    
}
