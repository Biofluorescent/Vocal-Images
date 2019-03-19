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

class MemoriesViewController: UICollectionViewController {

    
    override func viewDidLoad() {
        super.viewDidLoad()

        checkPermissions()
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
    
    
}
