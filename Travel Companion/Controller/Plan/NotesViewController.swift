//
//  NotesViewController.swift
//  Travel Companion
//
//  Created by Stefan Jaindl on 13.09.18.
//  Copyright © 2018 Stefan Jaindl. All rights reserved.
//

import CodableFirebase
import Firebase
import UIKit

class NotesViewController: UIViewController {
    
    var plannable: Plannable!
    var plannableCollectionReference: CollectionReference!
    
    @IBOutlet weak var notes: UITextField!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.navigationItem.title = "Add Note"
        
        notes.text = plannable.getNotes()
    }

    @IBAction func addNote(_ sender: Any) {
        persistNotes()
        
        dismiss(animated: true, completion: nil)
    }
    
    @IBAction func cancel(_ sender: Any) {
        dismiss(animated: true, completion: nil)
    }
    
    func persistNotes() {
        guard let text = notes.text, text != plannable.getNotes() else {
            return
        }
        
        plannable.setNotes(notes: text)
        
        let docData = plannable.encode()
        
        FirestoreClient.addData(collectionReference: plannableCollectionReference, documentName: plannable.getId(), data: docData) { (error) in
            if let error = error {
                UiUtils.showError("Error adding document: \(error)", controller: self)
            } else {
                debugPrint("Notes document added")
            }
        }
    }
}
