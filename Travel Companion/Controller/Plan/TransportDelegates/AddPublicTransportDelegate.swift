//
//  AddPublicTransportDelegate.swift
//  Travel Companion
//
//  Created by Stefan Jaindl on 17.09.18.
//  Copyright © 2018 Stefan Jaindl. All rights reserved.
//

import CodableFirebase
import Firebase
import Foundation
import UIKit

class AddPublicTransportDelegate: NSObject, AddTransportDelegate {
    
    var weekDayToDayFlagMap: [Int: Int] =  [1: 0x01, /* Sunday */
        2: 0x02, /* Monday */
        3: 0x04, /* Tuesday */
        4: 0x08, /* Wednesday */
        5: 0x10, /* Thursday */
        6: 0x20, /* Friday */
        7: 0x40] /* Saturday */
    
    struct CellData {
        var opened = Bool()
        var route: Route?
        var segment: Segment?
        var agency: SurfaceAgency?
        var surfaceStops = [SurfaceStop]()
    }
    
    var cellData = [CellData]()
    
    func initCellData(searchResponse: SearchResponse, date: Date) {
        for route in searchResponse.routes {
            for segment in route.segments {
                if let stops = segment.stops, let agencies = segment.agencies {
                    for agency in agencies {
                        if dateIsRelevant(date, in: agency) {
                            cellData.append(CellData(opened: false, route: route, segment: segment, agency: agency, surfaceStops: stops))
                        }
                    }
                } else {
                    //there are no stops or agencies --> it's potentially a car drive
                    cellData.append(CellData(opened: false, route: route, segment: segment, agency: nil, surfaceStops: []))
                }
            }
        }
    }
    
    func numberOfSections(in tableView: UITableView) -> Int {
        return cellData.count
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return cellData[section].opened ? cellData[section].surfaceStops.count + 1 : 1
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath, searchResponse: SearchResponse) -> UITableViewCell {
        
        let agency = cellData[indexPath.section].agency
        let segment = cellData[indexPath.section].segment!
        var cellReuseId = Constants.REUSE_IDS.TRANSPORT_DETAIL_WITHOUT_IMAGE_CELL_REUSE_ID
        if let agency = agency, searchResponse.agencies[agency.agency].icon?.url != nil {
            cellReuseId = Constants.REUSE_IDS.TRANSPORT_DETAIL_WITH_IMAGE_CELL_REUSE_ID
        }
        
        if indexPath.row == 0 {
            guard let cell = tableView.dequeueReusableCell(withIdentifier: cellReuseId) else {
                return UITableViewCell()
            }
            
            let route = cellData[indexPath.section].route!
            let depPlace = searchResponse.places[route.depPlace]
            let arrPlace = searchResponse.places[route.arrPlace]
            
            cell.textLabel?.text = "\(route.name): \(depPlace.shortName) - \(arrPlace.shortName)"
            
            var detailText = "\(segment.distance) km"
            
            if let agency = agency {
                detailText = searchResponse.agencies[agency.agency].name + ", " + detailText
                
                if let agencyUrl = searchResponse.agencies[agency.agency].icon?.url, let url = URL(string: "\(Rome2RioConstants.UrlComponents.PROTOCOL)://\(Rome2RioConstants.UrlComponents.DOMAIN)\(agencyUrl)") {
                    try? cell.imageView?.image = UIImage(data: Data(contentsOf: url))
                }
            }
            
            cell.detailTextLabel?.text = detailText

            return cell
        } else {
            guard let cell = tableView.dequeueReusableCell(withIdentifier: cellReuseId) else {
                return UITableViewCell()
            }

            let stop = cellData[indexPath.section].surfaceStops[indexPath.row - 1]
            
            var duration = 0
            if let stopDuration = stop.stopDuration {
                duration += Int(stopDuration)
            }
            if let transitDuration = stop.transitDuration {
                duration += Int(transitDuration)
            }
            
            if duration == 0 {
                duration = segment.transitDuration + segment.transferDuration
            }

            let place = searchResponse.places[stop.place]
            cell.textLabel?.text = place.shortName
            
            var detailText = "\(duration / 60) hours, \(duration % 60) minutes"
            
            if let prices = segment.indicativePrices, prices.count > 0 {
                if let name = prices[0].name {
                    detailText += " (\(name): "
                } else {
                    detailText += " ("
                }
                
                if let minPrice = prices[0].nativePriceLow, let maxPrice = prices[0].nativePriceHigh {
                    detailText += "\(minPrice) - \(maxPrice) \(prices[0].currency))"
                } else {
                    detailText += "≈\(prices[0].price) \(prices[0].currency))"
                }
            }
            
            cell.detailTextLabel?.text = detailText
 
            return cell
        }
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath, searchResponse: SearchResponse, date: Date, firestoreDbReference: CollectionReference, controller: UIViewController, popToController: UIViewController) {
        
        let stops = cellData[indexPath.section].surfaceStops
        let route = self.cellData[indexPath.section].route!
        let segment = self.cellData[indexPath.section].segment!
        let agency = self.cellData[indexPath.section].agency
        
        if indexPath.row == 0 {
            let sections = IndexSet.init(integer: indexPath.section)
            
            if cellData[indexPath.section].surfaceStops.count > 0 { //only expand/collapse if there are stops
                cellData[indexPath.section].opened = !cellData[indexPath.section].opened
                tableView.reloadSections(sections, with: .fade)
            } else {
                let alert = UIAlertController(title: "Add Public Transport", message: "Do you want to add the tapped route?", preferredStyle: .alert)
                
                alert.addAction(UIAlertAction(title: NSLocalizedString("Add route", comment: "Add route"), style: .default, handler: { _ in
                    
                    self.persistPublicTransport(nil, segment: segment, agency: agency, route: route, searchResponse: searchResponse, date: date, firestoreDbReference: firestoreDbReference)
                    
                    controller.navigationController?.popToViewController(popToController, animated: true)
                }))
                
                alert.addAction(UIAlertAction(title: NSLocalizedString("Cancel", comment: "cancel"), style: .default, handler: { _ in
                    controller.dismiss(animated: true, completion: nil)
                }))
                
                controller.present(alert, animated: true, completion: nil)
            }
        } else {
            //choose single flight or whole leg?
            let alert = UIAlertController(title: "Add Public Transport", message: "Do you want to add the tapped stop or whole route?", preferredStyle: .alert)

            alert.addAction(UIAlertAction(title: NSLocalizedString("Single Stop", comment: "Add single stop"), style: .default, handler: { _ in
                
                let stop = self.cellData[indexPath.section].surfaceStops[indexPath.row - 1]

                self.persistPublicTransport(stop, segment: segment, agency: agency, route: route, searchResponse: searchResponse, date: date, firestoreDbReference: firestoreDbReference)
                
                controller.navigationController?.popToViewController(popToController, animated: true)
            }))

            alert.addAction(UIAlertAction(title: NSLocalizedString("Whole route", comment: "Add whole route"), style: .default, handler: { _ in

                for stop in stops {
                    self.persistPublicTransport(stop, segment: segment, agency: agency, route: route, searchResponse: searchResponse, date: date, firestoreDbReference: firestoreDbReference)
                }

                controller.navigationController?.popToViewController(popToController, animated: true)
            }))

            alert.addAction(UIAlertAction(title: NSLocalizedString("Cancel", comment: "cancel"), style: .default, handler: { _ in
                controller.dismiss(animated: true, completion: nil)
            }))

            controller.present(alert, animated: true, completion: nil)
        }
    }
    
    func dateIsRelevant(_ date: Date, in agency: SurfaceAgency) -> Bool {
        let weekdayToTravel = Calendar.current.component(.weekday, from: date)
        
        guard let operatingDays = agency.operatingDays else {
            return true //this is potentially a rideshare or similar, where no fixed operating days are available
        }
        
        guard let weekdayBitMask = weekDayToDayFlagMap[weekdayToTravel] else {
            return false
        }
        
        return weekdayBitMask & operatingDays > 0
    }
    
    func persistPublicTransport(_ stop: SurfaceStop?, segment: Segment, agency: SurfaceAgency?, route: Route, searchResponse: SearchResponse, date: Date, firestoreDbReference: CollectionReference) {
        
        let depPlace = searchResponse.places[route.depPlace].shortName
        let arrPlace = searchResponse.places[route.arrPlace].shortName
        var agencyName: String?
        var agencyUrl: String?
        var stopDuration: Double?
        var transitDuration: Double?
        var stopPlace: String?
        
        if let agency = agency {
            agencyName = searchResponse.agencies[agency.agency].name
            if let url = searchResponse.agencies[agency.agency].icon?.url {
                agencyUrl = url
            }
        }
        
        if let stop = stop {
            stopPlace = searchResponse.places[stop.place].shortName
            stopDuration = stop.stopDuration
            transitDuration = stop.transitDuration
        }
        
        let vehicle = searchResponse.vehicles[segment.vehicle].name
        
        let publicTransport = PublicTransport(date: Timestamp(date: date), vehicle: vehicle, depPlace: depPlace, arrPlace: arrPlace, agencyName: agencyName, agencyUrl: agencyUrl, stopDuration: stopDuration, transitDuration: transitDuration, stopPlace: stopPlace)
        
        let docData = try! FirestoreEncoder().encode(publicTransport)
        FirestoreClient.addData(collectionReference: firestoreDbReference, documentName: publicTransport.id, data: docData) { (error) in
            if let error = error {
                print("Error adding document: \(error)")
            } else {
                print("Document added")
            }
        }
    }
    
    func buildSearchQueryItems(origin: String, destination: String) -> [String: String] {
        return [
            Rome2RioConstants.ParameterKeys.Key: SecretConstants.ROME2RIO_API_KEY,
            Rome2RioConstants.ParameterKeys.OriginName: origin,
            Rome2RioConstants.ParameterKeys.DestinationName: destination,
            Rome2RioConstants.ParameterKeys.noAir: "true",
            Rome2RioConstants.ParameterKeys.noAirLeg: "true"
        ]
    }
    
    func description() -> String {
        return "Public Transport"
    }
}
