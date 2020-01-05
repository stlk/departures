//
//  TodayViewController.swift
//  TodayWidgetDepartures
//
//  Created by Josef Rousek on 04/01/2020.
//  Copyright © 2020 Josef Rousek. All rights reserved.
//

import UIKit
import CoreLocation
import NotificationCenter

struct Departure : Decodable {
    let departure_time: String
    let route_short_name: String
    let stop_name: String
    let trip_headsign: String
}

class TodayViewController: UIViewController, UITableViewDelegate, UITableViewDataSource {
    @IBOutlet weak var table: UITableView!
    
    // This is used to indicate whether an update of the today widget is required or not
    private var updateResult = NCUpdateResult.noData
    
    fileprivate let kCellHeight : CGFloat = 120.0
    lazy private var locManager = CLLocationManager()
    private var departuresSections : [String : [Departure]] = [:]
    
    override func viewDidLoad() {
        super.viewDidLoad()
        locManager.delegate = self
        
        if #available(iOSApplicationExtension 10.0, *)
        {
            self.extensionContext?.widgetLargestAvailableDisplayMode = .expanded
        }
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        locManager.desiredAccuracy = kCLLocationAccuracyBest
        locManager.requestWhenInUseAuthorization()
        locManager.requestLocation()
    }
    
    
    func getDepartures(latitude: String, longitude: String) {
        if let url = URL(string: "https://departures.stlk.now.sh/api/departures?latitude=" + latitude + "&longitude=" + longitude) {

        let request = NSMutableURLRequest(url: url)
        let task = URLSession.shared.dataTask(with: request as URLRequest) {
            data, response, error in
            if error != nil {
                print(error!)
            } else {
                if let urlContent = data {
                    do {
                        let json = try JSONDecoder().decode([Departure].self, from: urlContent)
                        self.departuresSections = Dictionary(grouping: json, by: { $0.stop_name })
                        print(self.departuresSections)
                        DispatchQueue.main.sync(execute: {
                            self.table.reloadData()
                        })
                    } catch {
                        print("JSON Processing Failed")
                    }
                }
            }
        }
        task.resume()
        }
    }
    
    func updateData(latitude: String, longitude: String) {
        getDepartures(latitude: latitude, longitude: longitude)
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if self.departuresSections.count == 0
        {
            return 1
        }
        let valueArray = [[Departure]](self.departuresSections.values)
        return valueArray[section].count
    }
    
    func numberOfSections(in tableView: UITableView) -> Int {
        self.departuresSections.count
    }
    
    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        let keyArray = [String](self.departuresSections.keys)
        return keyArray[section]
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "Cell", for: indexPath)
        if self.departuresSections.count == 0
        {
            cell.textLabel?.text = "loading..."
            return cell
        }

        let valueArray = [[Departure]](self.departuresSections.values)
        let departure = valueArray[indexPath.section][indexPath.row]
        
        cell.textLabel?.text = departure.route_short_name + " - " + departure.trip_headsign
        cell.detailTextLabel?.text = departure.departure_time
        return cell
    }
    
    func tableView(_ tableView: UITableView, willDisplayHeaderView view: UIView, forSection section: Int) {
        // Make section header background transparent
        if view is UITableViewHeaderFooterView {
            let headerView = view as! UITableViewHeaderFooterView
            headerView.backgroundView = UIView(frame: headerView.bounds)
            headerView.backgroundView?.backgroundColor = UIColor.clear
        }
    }

}



typealias WidgetProvider = TodayViewController
extension WidgetProvider: NCWidgetProviding {
    
    func widgetPerformUpdate(completionHandler: ((NCUpdateResult) -> Void)) {
        // Perform any setup necessary in order to update the view.
        
        // If an error is encountered, use NCUpdateResult.Failed
        // If there's no update required, use NCUpdateResult.NoData
        // If there's an update, use NCUpdateResult.NewData
        
        completionHandler(updateResult)
    }
    
    @available(iOSApplicationExtension 10.0, *)
    //Minimum height of widget in iOS-10 is 110 i.e, for compact display mode
    func widgetActiveDisplayModeDidChange(_ activeDisplayMode: NCWidgetDisplayMode, withMaximumSize maxSize: CGSize)
    {
        if activeDisplayMode == .expanded
        {
            let total_count = [[Departure]](self.departuresSections.values).reduce(0, { sum, departures in
                sum + departures.count + 1
            })
            preferredContentSize = CGSize(width: 0.0, height: kCellHeight * CGFloat(total_count))
        }
        else
        {
            preferredContentSize = maxSize
        }
    }
}

typealias LocationDelegate = TodayViewController
extension LocationDelegate: CLLocationManagerDelegate {
    
    func locationManager(_ manager: CLLocationManager, didFailWithError: Error) {
        print(didFailWithError.localizedDescription)
    }
    
    func locationManager(_ manager: CLLocationManager, didFinishDeferredUpdatesWithError error: Error?) {
        // If we could not retrive location data, set our update result to Failed
        updateResult = .failed
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        // Do stuff with the retrieved location, update our display and then set our update result to NewData
        
        let userLocation: CLLocation = locations[0]
        let latitude = userLocation.coordinate.latitude
        let longitude = userLocation.coordinate.longitude
        updateResult = .newData
        updateData(latitude: String(latitude), longitude: String(longitude))
    }
}
