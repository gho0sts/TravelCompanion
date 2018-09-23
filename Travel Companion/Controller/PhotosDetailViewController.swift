//
//  ExplorePhotosDetailViewController.swift
//  Travel Companion
//
//  Created by Stefan Jaindl on 18.08.18.
//  Copyright © 2018 Stefan Jaindl. All rights reserved.
//

import UIKit

class PhotosDetailViewController: UIViewController {

    @IBOutlet weak var photoImage: UIImageView!
    @IBOutlet weak var photoTitle: UILabel!
    
    var data: Data!
    var text: String?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        photoImage.image = UIImage(data: data)
        photoTitle.text = text
    }
}
