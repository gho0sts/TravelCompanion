//
//  AddPlanViewController.swift
//  Travel Companion
//
//  Created by Stefan Jaindl on 26.08.18.
//  Copyright © 2018 Stefan Jaindl. All rights reserved.
//

import Firebase
import UIKit

class AddPlanViewController: UIViewController, UIPickerViewDelegate, UIPickerViewDataSource, UITextFieldDelegate {
    
    @IBOutlet weak var destinationPicker: UIPickerView!
    @IBOutlet weak var destinationText: UITextField!
    @IBOutlet weak var addTripButton: UIButton!
    @IBOutlet weak var startDate: UIDatePicker!
    @IBOutlet weak var endDate: UIDatePicker!
    @IBOutlet weak var addTrip: UIButton!
    
    var pins: [Pin] = []
    var selectedOriginalPinName: String?
    var firestoreDbReference: CollectionReference!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        destinationPicker.delegate = self
        destinationPicker.dataSource = self
        destinationText.delegate = self
        
        if pins.count > 0 {
            destinationText.text = pins[0].name
            selectedOriginalPinName = pins[0].name
        }
        
        setButtonEnabledState()
        
        firestoreDbReference = FirestoreClient.userReference().collection(FirestoreConstants.Collections.PLANS)
    }
    
    func setButtonEnabledState() {
        if let text = destinationText.text, !text.isEmpty {
            addTrip.isEnabled = true
        } else {
            addTrip.isEnabled = false
        }
    }
     
    @IBAction func addPlan(_ sender: Any) {
        let originalName = selectedOriginalPinName ?? destinationText.text!
        
        let plan = Plan(name: destinationText.text!, originalName: originalName, startDate: Timestamp(date: startDate.date), endDate: Timestamp(date: endDate.date))
        
        //TODO: check whether plan already exists and ask if user wants to override
        persistPlan(of: plan)
        
        dismiss(animated: true, completion: nil)
    }
    
    @IBAction func cancel(_ sender: Any) {
        dismiss(animated: true, completion: nil)
    }
    
    func persistPlan(of plan: Plan) {
        FirestoreClient.addData(collectionReference: firestoreDbReference, documentName: plan.name, data: [
            FirestoreConstants.Ids.Plan.NAME: plan.name,
            FirestoreConstants.Ids.Plan.PIN_NAME: plan.pinName,
            FirestoreConstants.Ids.Plan.START_DATE: plan.startDate,
            FirestoreConstants.Ids.Plan.END_DATE: plan.endDate
        ]) { (error) in
            if let error = error {
                print("Error adding document: \(error)")
            } else {
                print("Document added")
            }
        }
    }
}

extension AddPlanViewController {
    
    public func numberOfComponents(in pickerView: UIPickerView) -> Int{
        return 1
    }
    
    public func pickerView(_ pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int{
        return pins.count
    }
    
    func pickerView(_ pickerView: UIPickerView, titleForRow row: Int, forComponent component: Int) -> String? {
        
        view.endEditing(true)
        return pins[row].name
    }
    
    func pickerView(_ pickerView: UIPickerView, didSelectRow row: Int, inComponent component: Int) {
        destinationText.text = self.pins[row].name
        selectedOriginalPinName = self.pins[row].name
        setButtonEnabledState()
    }
    
    func textFieldDidBeginEditing(_ textField: UITextField) {
        
        if textField == self.destinationText {
            destinationPicker.isHidden = false
            //if you don't want the users to see the keyboard type:
            
            textField.endEditing(true)
        }
    }
    
    func textFieldDidEndEditing(_ textField: UITextField) {
        //TODO: check whether pin with name exists -> if so, grey out add button + toast
        setButtonEnabledState()
        UiUtils.showToast(message: "Please enter a destination name", view: self.view)
    }
}