//
//  PlanDetailViewController.swift
//  Travel Companion
//
//  Created by Stefan Jaindl on 27.08.18.
//  Copyright © 2018 Stefan Jaindl. All rights reserved.
//

import CodableFirebase
import Firebase
import UIKit

class PlanDetailViewController: UIViewController, UITableViewDelegate, UITableViewDataSource {
    
    @IBOutlet weak var image: UIImageView!
    @IBOutlet weak var tableView: UITableView!
    @IBOutlet weak var imageWidthConstraint: NSLayoutConstraint!
    @IBOutlet weak var imageHeightConstraint: NSLayoutConstraint!
    @IBOutlet weak var toolbar: UIToolbar!
    
    var plan: Plan!
    var pins: [Pin]!
    var dataController: DataController!
    
    var firestorePlanDbReference: CollectionReference!
    
    var storageRef: StorageReference!
    
    var supportedPlaceTypes: [GooglePlaceType] = [
        GooglePlaceType.point_of_interest,
        GooglePlaceType.amusement_park,
        GooglePlaceType.aquarium,
        GooglePlaceType.art_gallery,
        GooglePlaceType.atm,
        GooglePlaceType.bank,
        GooglePlaceType.bar,
        GooglePlaceType.beauty_salon,
        GooglePlaceType.bowling_alley,
        GooglePlaceType.cafe,
        GooglePlaceType.casino,
        GooglePlaceType.church,
        GooglePlaceType.city_hall,
        GooglePlaceType.embassy,
        GooglePlaceType.gym,
        GooglePlaceType.hindu_temple,
        GooglePlaceType.library,
        GooglePlaceType.mosque,
        GooglePlaceType.movie_theater,
        GooglePlaceType.museum,
        GooglePlaceType.night_club,
        GooglePlaceType.post_office,
        GooglePlaceType.rv_park,
        GooglePlaceType.shopping_mall,
        GooglePlaceType.spa,
        GooglePlaceType.stadium,
        GooglePlaceType.synagogue,
        GooglePlaceType.travel_agency,
        GooglePlaceType.zoo
    ]
    
    var selectedPlaceType = GooglePlaceType.point_of_interest
    
    var lastScrollPos: CGFloat = 0.0
    
    var imageCache = GlobalCache.imageCache
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        navigationItem.title = "\(plan.name), \(UiUtils.formatTimestampRangeForDisplay(begin: plan.startDate, end: plan.endDate))"
        
        tableView.delegate = self
        tableView.dataSource = self
        
        addSwipeGestureRecognizers()
        addGestureRecognizer(selector: #selector(chooseImage), view: image)
        
        configureDatabase()
        configureStorage()
    }
    
    func addSwipeGestureRecognizers() {
        let swipeUp = UISwipeGestureRecognizer(target: self, action: #selector(handleGesture))
        swipeUp.direction = .up
        self.view.addGestureRecognizer(swipeUp)
        
        let swipeDown = UISwipeGestureRecognizer(target: self, action: #selector(handleGesture))
        swipeDown.direction = .down
        self.view.addGestureRecognizer(swipeDown)
    }
    
    @objc
    func handleGesture(gesture: UISwipeGestureRecognizer) -> Void {
        if gesture.direction == UISwipeGestureRecognizer.Direction.up {
            self.toolbar.isHidden = true
        }
        else if gesture.direction == UISwipeGestureRecognizer.Direction.down {
            self.toolbar.isHidden = false
        }
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        loadImageIfAvailable()
        tableView.reloadData()
    }

    func setImageSize(_ size: CGFloat) {
        imageWidthConstraint.constant = size
        imageHeightConstraint.constant = size
    }
    
    func loadImageIfAvailable() {
        if let data = plan.imageData { //Has an image been chosen?
            image.image = UIImage(data: data)
            persistPhoto(photoData: data)
        } else if !plan.imageRef.isEmpty { //Is an image available in storage?
            
            if let cachedImage = imageCache.object(forKey: plan.imageRef as NSString) {
                self.image.image = cachedImage
            } else {
            
                let storageImageRef = Storage.storage().reference(forURL: plan.imageRef)
                storageImageRef.getData(maxSize: 2 * 1024 * 1024) { (data, error) in
                    if let error = error {
                        UiUtils.showToast(message: error.localizedDescription, view: self.view)
                        return
                    }
                    
                    guard let data = data, let image = UIImage(data: data) else {
                        UiUtils.showToast(message: "noImageData".localized(), view: self.view)
                        return
                    }
                    
                    self.imageCache.setObject(image, forKey: self.plan.imageRef as NSString)
                    self.image.image = image
                }
            }
        }
    }
    
    func configureStorage() { 
        storageRef = Storage.storage().reference()
    }
    
    func addGestureRecognizer(selector: Selector?, view: UIView) {
        let gestureRecognizer = UITapGestureRecognizer(target: self, action: selector)
        view.isUserInteractionEnabled = true
        view.addGestureRecognizer(gestureRecognizer)
    }
    
    deinit {
        plan.resetReferences()
        
        firestorePlanDbReference = nil
    }
    
    @IBAction func addHotel(_ sender: Any) {
        performSegue(withIdentifier: Constants.Segues.planAddPlace, sender: GooglePlaceType.lodging)
    }
    
    @IBAction func addRestaurant(_ sender: Any) {
        performSegue(withIdentifier: Constants.Segues.planAddPlace, sender: GooglePlaceType.restaurant)
    }
    
    @IBAction func addAttraction(_ sender: Any) {
        let viewController = UIViewController()
        viewController.preferredContentSize = CGSize(width: 250,height: 300)
        let pickerView = UIPickerView(frame: CGRect(x: 0, y: 0, width: 250, height: 300))
        pickerView.delegate = self
        pickerView.dataSource = self
        viewController.view.addSubview(pickerView)
        let editRadiusAlert = UIAlertController(title: "choosePlaceType".localized(), message: "", preferredStyle: UIAlertController.Style.alert)
        editRadiusAlert.setValue(viewController, forKey: "contentViewController")
        
        editRadiusAlert.addAction(UIAlertAction(title: "search".localized(), style: .default) { (action)  in
            self.performSegue(withIdentifier: Constants.Segues.planAddPlace, sender: self.selectedPlaceType)
        })
        
        editRadiusAlert.addAction(UIAlertAction(title: "cancel".localized(), style: .default) { (action)  in
            self.dismiss(animated: true, completion: nil)
        })
        
        self.present(editRadiusAlert, animated: true)

    }
    
    @objc
    func chooseImage() {
        performSegue(withIdentifier: Constants.Segues.planChoosePhoto, sender: nil)
    }
    
    func configureDatabase() {        
        plan.configureDatabase()
    }

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == Constants.Segues.planChoosePhoto {
            let controller = segue.destination as! ExplorePhotosViewController
            let pin = CoreDataClient.sharedInstance.findPinByName(plan.pinName, pins: pins)
            controller.pin = pin
            controller.dataController = dataController
            controller.choosePhoto = true
            controller.plan = plan
        } else if segue.identifier == Constants.Segues.planAddFlight {
            let controller = segue.destination as! AddTransportViewController
            controller.firestoreDbReference = plan.firestoreFligthDbReference
            controller.transportDelegate = AddFlightDelegate()
            controller.planDetailController = self
            controller.plan = plan
        } else if segue.identifier == Constants.Segues.planAddPublicTransport {
            let controller = segue.destination as! AddTransportViewController
            controller.firestoreDbReference = plan.firestorePublicTransportDbReference
            controller.transportDelegate = AddPublicTransportDelegate()
            controller.planDetailController = self
            controller.plan = plan
        } else if segue.identifier == Constants.Segues.planAddNotes {
            let indexPath = sender as! IndexPath
            let plannable = getSectionArray(for: indexPath.section)[indexPath.row]
            let collectionReference = getSectionReference(for: indexPath.section)
            
            let controller = segue.destination as! NotesViewController
            controller.plannable = plannable
            controller.plannableCollectionReference = collectionReference
        } else if segue.identifier == Constants.Segues.planAddPlace {
            let controller = segue.destination as! AddPlaceViewController
            
            let placetype = sender as! GooglePlaceType
            controller.placeType = placetype
            
            let collectionReference = getPlaceTypeReference(for: placetype)
            controller.firestoreDbReference = collectionReference
            
            let pin = CoreDataClient.sharedInstance.findPinByName(plan.pinName, pins: pins)
            controller.pin = pin
            
            controller.plan = plan
        }
    }
    
    func persistPhoto(photoData: Data) {
        let path = FirestoreClient.storageByPath(path: FirestoreConstants.Collections.plans, fileName: plan.pinName)
        FirestoreClient.storePhoto(storageRef: storageRef, path: path, photoData: photoData) { (metadata, error) in
            if let error = error {
                UiUtils.showToast(message: error.localizedDescription, view: self.view)
                return
            }
            
            guard let storagePath = metadata?.path else {
                UiUtils.showToast(message: "imageNotSaved".localized(), view: self.view)
                return
            }
            
            self.plan.imageRef = self.storageRef.child(storagePath).description
            self.updatePlan()
        }
    }
    
    func updatePlan() {
        FirestoreClient.addData(collectionReference: firestorePlanDbReference, documentName: plan.name, data: [
            FirestoreConstants.Ids.Plan.name: plan.name,
            FirestoreConstants.Ids.Plan.pinName: plan.pinName,
            FirestoreConstants.Ids.Plan.startDate: plan.startDate,
            FirestoreConstants.Ids.Plan.endDate: plan.endDate,
            FirestoreConstants.Ids.Plan.imageReference: plan.imageRef
        ]) { (error) in
            if let error = error {
                UiUtils.showToast(message: error.localizedDescription, view: self.view)
                return
            }
        }
    }
}

extension PlanDetailViewController {
    func numberOfSections(in tableView: UITableView) -> Int {
        return 5 //fligths, public transport, hotels, restaurants, attractions
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return getSectionArray(for: section).count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        var cell = tableView.dequeueReusableCell(withIdentifier: Constants.ReuseIds.planDetailCell)!
        let plannable = getSectionArray(for: indexPath.section)[indexPath.row]
        
        if let imageUrl = plannable.imageUrl(), let url = URL(string: imageUrl) {
            cell = tableView.dequeueReusableCell(withIdentifier: Constants.ReuseIds.planDetailWithImageCell)!
            try? cell.imageView?.image = UIImage(data: Data(contentsOf: url))
        }

        cell.textLabel?.text = plannable.description()
        cell.detailTextLabel?.attributedText = plannable.details()
        cell.detailTextLabel?.isUserInteractionEnabled = true
        cell.detailTextLabel?.addTapGestureRecognizer {
            if let link = plannable.getLink(), let url = URL(string: link) {
                UIApplication.shared.open(url, options: self.convertToUIApplicationOpenExternalURLOptionsKeyDictionary([:]), completionHandler: nil)
            }
        }
        
        return cell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let plannables = getSectionArray(for: indexPath.section)
        
        //only show notes, if load of plannables has finished
        if plannables.count - 1 >= indexPath.row {
            
            //choose single flight or whole leg?
            let alert = UIAlertController(title: "chooseAction".localized(), message: nil, preferredStyle: .alert)
            
            alert.addAction(UIAlertAction(title: "addNote".localized(), style: .default, handler: { _ in
                self.performSegue(withIdentifier: Constants.Segues.planAddNotes, sender: indexPath)
            }))
            
            alert.addAction(UIAlertAction(title: "delete".localized(), style: .default, handler: { _ in
                let plannable = self.getSectionArray(for: indexPath.section)[indexPath.row]
                let collectionReference = self.getSectionReference(for: indexPath.section)
                
                collectionReference.document(plannable.getId()).delete() { error in
                    if let error = error {
                        debugPrint(error.localizedDescription)
                    } else {
                        debugPrint("Document successfully removed!")
                        self.removeElement(at: indexPath)
                        self.tableView.reloadData()
                    }
                }
            }))
            
            alert.addAction(UIAlertAction(title: "cancel".localized(), style: .default, handler: { _ in
                self.dismiss(animated: true, completion: nil)
            }))
            
            self.present(alert, animated: true, completion: nil)
        }
    }
    
    fileprivate func convertToUIApplicationOpenExternalURLOptionsKeyDictionary(_ input: [String: Any]) -> [UIApplication.OpenExternalURLOptionsKey: Any] {
        return Dictionary(uniqueKeysWithValues: input.map { key, value in (UIApplication.OpenExternalURLOptionsKey(rawValue: key), value)})
    }
    
    func getSectionArray(for section: Int) -> [Plannable] {
        if section == 0 {
            return plan.fligths
        } else if section == 1 {
            return plan.publicTransport
        } else if section == 2 {
            return plan.hotels
        } else if section == 3 {
            return plan.restaurants
        } else {
            return plan.attractions
        } 
    }
    
    func removeElement(at indexPath: IndexPath) {
        let section = indexPath.section
        if section == 0 {
            plan.fligths.remove(at: indexPath.row)
        } else if section == 1 {
            plan.publicTransport.remove(at: indexPath.row)
        } else if section == 2 {
            plan.hotels.remove(at: indexPath.row)
        } else if section == 3 {
            plan.restaurants.remove(at: indexPath.row)
        } else {
            plan.attractions.remove(at: indexPath.row)
        }
    }
    
    func getSectionReference(for section: Int) -> CollectionReference {
        if section == 0 {
            return plan.firestoreFligthDbReference
        } else if section == 1 {
            return plan.firestorePublicTransportDbReference
        } else if section == 2 {
            return plan.firestoreHotelDbReference
        } else if section == 3 {
            return plan.firestoreRestaurantDbReference
        } else {
            return plan.firestoreAttractionDbReference
        }
    }
    
    func getPlaceTypeReference(for placeType: GooglePlaceType) -> CollectionReference {
        if placeType == GooglePlaceType.lodging {
            return plan.firestoreHotelDbReference
        } else if placeType == GooglePlaceType.restaurant {
            return plan.firestoreRestaurantDbReference
        } else {
            return plan.firestoreAttractionDbReference
        }
    }
    
    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        if section == 0 {
            return PlanConstants.TripDetails.TripTitles.flights.rawValue.localized()
        } else if section == 1 {
            return PlanConstants.TripDetails.TripTitles.publicTransport.rawValue.localized()
        } else if section == 2 {
            return PlanConstants.TripDetails.TripTitles.hotels.rawValue.localized()
        } else if section == 3 {
            return PlanConstants.TripDetails.TripTitles.restaurants.rawValue.localized()
        } else {
            return PlanConstants.TripDetails.TripTitles.attractions.rawValue.localized()
        }
    }
    
    func tableView(_ tableView: UITableView, willDisplayHeaderView view: UIView, forSection section: Int) {
        let header = view as! UITableViewHeaderFooterView
        header.textLabel?.textColor = CustomColors.appTextColorDefault()
        header.textLabel?.font = header.textLabel?.font.withSize(20)
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 70
    }
    
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        let isBouncing = scrollView.contentOffset.y > (scrollView.contentSize.height - scrollView.frame.size.height) //bottom bounce
            || scrollView.contentOffset.y < 0 //top bounce
        
        if isBouncing {
            return
        }
        
        let scrollPos = scrollView.contentOffset.y
        
        var hidden = false
        if scrollPos > lastScrollPos {
            hidden = true
        }
        
        self.toolbar.isHidden = hidden
        
        lastScrollPos = scrollPos
    }
}

extension PlanDetailViewController: UIPickerViewDelegate, UIPickerViewDataSource {

    func numberOfComponents(in pickerView: UIPickerView) -> Int {
        return 1
    }
    
    func pickerView(_ pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int {
        return supportedPlaceTypes.count
    }
    
    func pickerView(_ pickerView: UIPickerView, titleForRow row: Int, forComponent component: Int) -> String? {
        return supportedPlaceTypes[row].rawValue
    }
    
    func pickerView(_ pickerView: UIPickerView, didSelectRow row: Int, inComponent component: Int) {
        selectedPlaceType = supportedPlaceTypes[row]
    }
}
