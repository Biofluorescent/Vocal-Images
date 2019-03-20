//
//  MemoriesViewController.swift
//  VocalImages
//
//  Created by Tanner Quesenberry on 3/14/19.
//  Copyright © 2019 Tanner Quesenberry. All rights reserved.
//

import AVFoundation
import Photos
import Speech
import UIKit

class MemoriesViewController: UICollectionViewController, UIImagePickerControllerDelegate, UINavigationControllerDelegate, UICollectionViewDelegateFlowLayout {

    //Full path to root name of memories without extensions
    var memories = [URL]()
    
    override func viewDidLoad() {
        super.viewDidLoad()

        checkPermissions()
        
        //Button to trigger image picker
        navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .add, target: self, action: #selector(addTapped))
        
        loadMemories()
    }
    

    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destination.
        // Pass the selected object to the new view controller.
    }
    */

    //Function checks that all permissions granted. If false, show FirstRun view controller
    func checkPermissions(){
        //check status of 3 required permissions
        let photosAuthorized = PHPhotoLibrary.authorizationStatus() == .authorized
        let recordingAuthorized = AVAudioSession.sharedInstance().recordPermission == .granted
        let transcribeAuthorized = SFSpeechRecognizer.authorizationStatus() == .authorized
        
        //make single boolean of all 3
        let authorized = photosAuthorized && recordingAuthorized && transcribeAuthorized
        
        //if missing one, show first run view controller
        if authorized == false {
            if let vc = storyboard?.instantiateViewController(withIdentifier: "FirstRun") {
                navigationController?.present(vc, animated: true)
            }
        }
    }
    
    
    func loadMemories(){
        memories.removeAll()
        
        //attempt to load all memories in our docs directory. Try? used in case missing permissions
        guard  let files = try? FileManager.default.contentsOfDirectory(at: getDocumentsDirectory(), includingPropertiesForKeys: nil, options: []) else { return }
        
        //loop over found files
        for file in files {
            let filename = file.lastPathComponent
            
            //check it ends in .thumb so no duplicates
            if filename.hasSuffix(".thumb") {
                
                //get root name
                let noExtension = filename.replacingOccurrences(of: ".thumb", with: "")
                
                //create full path from memory
                let memoryPath = getDocumentsDirectory().appendingPathComponent(noExtension)
                
                //add to array
                memories.append(memoryPath)
            }
        }
        
        //reload list of memories in second section, first section is search bar
        collectionView?.reloadSections(IndexSet(integer: 1))
    }
    
    
    //Helper function to get app's document directory
    func getDocumentsDirectory() -> URL {
        let paths = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
        let documentsDirectory = paths[0]
        return documentsDirectory
    }
    
    //Creates instance of UIImagePickerController then shows it
    @objc func addTapped(){
        let vc = UIImagePickerController()
        vc.modalPresentationStyle = .formSheet
        vc.delegate = self
        navigationController?.present(vc, animated: true)
    }
    
    
    //Callback for when an image is selected. Create new memory
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
        dismiss(animated: true)
        
        if let possibleImage = info[.originalImage] as? UIImage {
            saveNewMemory(image: possibleImage)
            loadMemories()
        }
    }
    
    
    func saveNewMemory(image: UIImage){
        //create unique name ofr memory
        let memoryName = "memory-\(Date().timeIntervalSince1970)"
        
        //use name to create filenames for full-size image and thumbnail
        let imageName = memoryName + ".jpg"
        let thumbnailName = memoryName + ".thumb"
        
        do {
            //create URL to write jpg to
            let imagePath = getDocumentsDirectory().appendingPathComponent(imageName)
            
            //convert UIImage into a JPEG data object
            if let jpegData = image.jpegData(compressionQuality: 0.8) {
                //write data to URL we created
                try jpegData.write(to: imagePath, options: [.atomicWrite])
            }
            
            //create thumbnail here
            if let thumbnail = resize(image: image, to: 200) {
                let imagePath = getDocumentsDirectory().appendingPathComponent(thumbnailName)
                if let jpegData = thumbnail.jpegData(compressionQuality: 0.8) {
                    try jpegData.write(to: imagePath, options: [.atomicWrite])
                }
            }
            
        } catch {
            print("Failed to save to disk.")
        }
    }
    
    
    //Used to create a downsized version of an image
    func resize(image: UIImage, to width: CGFloat) -> UIImage? {
        //calculate how much we need to bring the width down to match target size
        let scale = width / image.size.width
        
        //bring height down by same size to conserve aspect ratio
        let height = image.size.height * scale
        
        //create new image context to draw into
        UIGraphicsBeginImageContextWithOptions(CGSize(width: width, height: height), false, 0)
        
        //draw original image into context
        image.draw(in: CGRect(x: 0, y: 0, width: width, height: height))
        
        //pull out resized version
        let newImage = UIGraphicsGetImageFromCurrentImageContext()
        
        //end the context so UIKit can clean up
        UIGraphicsEndImageContext()
        
        return newImage
    }
    
    //MARK: - Helper functions for use in cellForItemAt
    
    func imageURL(for memory: URL) -> URL {
        return memory.appendingPathExtension("jpg")
    }
    
    func thumbnailURL(for memory: URL) -> URL {
        return memory.appendingPathExtension("thumb")
    }
    
    func audioURL(for memory: URL) -> URL {
        return memory.appendingPathExtension("m4a")
    }
    
    func transcriptionURL(for memory: URL) -> URL {
        return memory.appendingPathExtension("txt")
    }
    
    
    //MARK: - Collection View Delegate Methods
    
    override func numberOfSections(in collectionView: UICollectionView) -> Int {
        return 2
    }
    
    override func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        if section == 0 {
            return 0
        } else {
            return memories.count
        }
    }
    
    override func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "Memory", for: indexPath) as! MemoryCell
        
        let memory = memories[indexPath.row]
        let imageName = thumbnailURL(for: memory).path
        let image = UIImage(contentsOfFile: imageName)
        
        cell.imageView.image = image
        
        return cell
    }
    
    override func collectionView(_ collectionView: UICollectionView, viewForSupplementaryElementOfKind kind: String, at indexPath: IndexPath) -> UICollectionReusableView {
        return collectionView.dequeueReusableSupplementaryView(ofKind: kind, withReuseIdentifier: "Header", for: indexPath)
    }
    
    
    //MARK: - FlowLayout Delegate Method
    
    //This handles which sections should have a header
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, referenceSizeForHeaderInSection section: Int) -> CGSize {
        if section == 1 {
            return CGSize.zero
        } else {
            return CGSize(width: 0, height: 50)
        }
    }
    
}
