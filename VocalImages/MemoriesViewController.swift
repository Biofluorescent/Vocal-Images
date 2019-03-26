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

class MemoriesViewController: UICollectionViewController, UIImagePickerControllerDelegate, UINavigationControllerDelegate, UICollectionViewDelegateFlowLayout, AVAudioRecorderDelegate {

    //Full path to root name of memories without extensions
    var memories = [URL]()
    //Store which memory activate the long press gesture recognizer
    var activeMemory: URL!
    
    var audioPlayer: AVAudioPlayer?
    var audioRecorder: AVAudioRecorder?
    var recordingURL: URL!
    
    override func viewDidLoad() {
        super.viewDidLoad()

        checkPermissions()
        
        //Button to trigger image picker
        navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .add, target: self, action: #selector(addTapped))
        
        recordingURL = getDocumentsDirectory().appendingPathComponent("recording.m4a")
        
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
        
        if cell.gestureRecognizers == nil {
            let recognizer = UILongPressGestureRecognizer(target: self, action: #selector(memoryLongPress))
            recognizer.minimumPressDuration = 0.25
            cell.addGestureRecognizer(recognizer)
            
            cell.layer.borderColor = UIColor.white.cgColor
            cell.layer.borderWidth = 3
            cell.layer.cornerRadius = 10
        }
        
        return cell
    }
    
    override func collectionView(_ collectionView: UICollectionView, viewForSupplementaryElementOfKind kind: String, at indexPath: IndexPath) -> UICollectionReusableView {
        return collectionView.dequeueReusableSupplementaryView(ofKind: kind, withReuseIdentifier: "Header", for: indexPath)
    }
    
    
    override func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        let memory = memories[indexPath.row]
        let fm = FileManager.default
        
        do {
            let audioName = audioURL(for: memory)
            let transcriptionName = transcriptionURL(for: memory)
            
            if fm.fileExists(atPath: audioName.path){
                audioPlayer = try AVAudioPlayer(contentsOf: audioName)
                audioPlayer?.play()
            }
            
            if fm.fileExists(atPath: transcriptionName.path){
                let contents = try String(contentsOf: transcriptionName)
                print(contents)
            }
        } catch {
            print("Error loading audio")
        }
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
    
    
    //MARK: - memoryLongPress Helper Functions
    
    //When long press has started or ended
    @objc func memoryLongPress(sender: UILongPressGestureRecognizer){
        if sender.state == .began {
            //Convert gesture's view to MemoryCell to attemp to get an index
            let cell = sender.view as! MemoryCell
            
            if let index = collectionView?.indexPath(for: cell) {
                activeMemory = memories[index.row]
                recordMemory()
            }
        }else if sender.state == .ended {
            finishRecording(success: true)
        }
    }
    
    //Microphone recording
    func recordMemory() {
        
        audioPlayer?.stop()
        collectionView?.backgroundColor = UIColor(red: 0.5, green: 0, blue: 0, alpha: 1)
        let recordingSession = AVAudioSession.sharedInstance()
        
        do {
            //Configure session for recording and playback through speaker
            try recordingSession.setCategory(.playAndRecord, mode: .default, options: .defaultToSpeaker)
            try recordingSession.setActive(true)
            
            //Set up high quality recording session
            let settings = [
                AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
                AVSampleRateKey: 44100,
                AVNumberOfChannelsKey: 2,
                AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
            ]
            
            //Create audio recording, and assign ourselves as the delegate
            audioRecorder = try AVAudioRecorder(url: recordingURL, settings: settings)
            audioRecorder?.delegate = self
            audioRecorder?.record()
            
        } catch let error {
            //failed to record
            print("Failed to record: \(error)")
            finishRecording(success: false)
        }
    }
    
    //When recording has finished, links recording to memory
    func finishRecording(success: Bool){
        //Set background to normal
        collectionView?.backgroundColor = UIColor.darkGray
        
        //Stop recording
        audioRecorder?.stop()
        
        if success {
            do {
                //Create a file URL out of active memory URL plus "m4a"
                let memoryAudioURL = activeMemory.appendingPathExtension("m4a")
                let fm = FileManager.default
                
                //If recording exists there, delete it because you can't move a file over one that exists
                if fm.fileExists(atPath: memoryAudioURL.path){
                    try fm.removeItem(at: memoryAudioURL)
                }
                
                //Move recorded file into memory's audio URL
                try fm.moveItem(at: recordingURL, to: memoryAudioURL)
                
                //Start transcription
                transcribeAudio(memory: activeMemory)
            } catch {
                print("Failure finishing recording: \(error)")
            }
        }
    }
    
    //Transcribes recording and links to memory
    func transcribeAudio(memory: URL){
        //get path where audio is and transcription should be
        let audio = audioURL(for: memory)
        let transcription = transcriptionURL(for: memory)
        
        //create new recognizer and point at audio
        let recognizer = SFSpeechRecognizer()
        let request = SFSpeechURLRecognitionRequest(url: audio)
        
        //start recognition
        recognizer?.recognitionTask(with: request) { [unowned self] (result, error) in
            
            //Abort if no transcription received
            guard let result = result else {
                print("There was an error: \(error!)")
                return
            }
            
            //Write to disk if got transcription
            if result.isFinal {
                let text = result.bestTranscription.formattedString
                
                do {
                    try text.write(to: transcription, atomically: true, encoding: String.Encoding.utf8)
                } catch {
                    print("Failed to save transcription.")
                }
            }
        }
    }
    
    //Catch when terminated by system, i.e. phone call
    func audioRecorderDidFinishRecording(_ recorder: AVAudioRecorder, successfully flag: Bool) {
        if !flag {
            finishRecording(success: false)
        }
    }
}
