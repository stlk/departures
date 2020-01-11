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


struct Section {
    let stop_name: String
    let departures: [Departure]
    var collapsed: Bool
}

class TodayViewController: UIViewController, UITableViewDelegate, UITableViewDataSource {
    @IBOutlet weak var table: UITableView!
    
    // This is used to indicate whether an update of the today widget is required or not
    private var updateResult = NCUpdateResult.noData
    
    fileprivate let kCellHeight : CGFloat = 30
    lazy private var locManager = CLLocationManager()
    private var departuresSections : [Section] = []
    @IBOutlet weak var spinner: UIActivityIndicatorView!
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        locManager.delegate = self
        
        if #available(iOSApplicationExtension 10.0, *)
        {
            self.extensionContext?.widgetLargestAvailableDisplayMode = .compact
        }
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        locManager.desiredAccuracy = kCLLocationAccuracyHundredMeters
        locManager.requestWhenInUseAuthorization()
        locManager.requestLocation()
    }
    
    
    func getDepartures(latitude: String, longitude: String) {
        spinner.startAnimating()
        if let url = URL(string: "https://departures.now.sh/api/departures?latitude=" + latitude + "&longitude=" + longitude) {
        let request = NSMutableURLRequest(url: url)
        let task = URLSession.shared.dataTask(with: request as URLRequest) {
            data, response, error in
            if error != nil {
                print(error!)
            } else {
                if let urlContent = data {
                    do {
                        let json = try JSONDecoder().decode([Departure].self, from: urlContent)
                        self.departuresSections = Dictionary(grouping: json, by: { $0.stop_name }).compactMap({ (arg0
                            ) -> Section in
                            let (key, value) = arg0
                            return Section(stop_name: key, departures: value, collapsed: true)
                        })
                        print(self.departuresSections)
                        DispatchQueue.main.sync(execute: {
                            self.spinner.stopAnimating()
                            self.table.reloadData()
                            self.extensionContext?.widgetLargestAvailableDisplayMode = NCWidgetDisplayMode.expanded
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
        return self.departuresSections[section].collapsed ? 0: self.departuresSections[section].departures.count
    }
    
    func numberOfSections(in tableView: UITableView) -> Int {
        return self.departuresSections.count
    }
    
//  Not needed for collapsible section header
//    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
//        return self.departuresSections[section].stop_name
//    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "Cell", for: indexPath)
        let departure = self.departuresSections[indexPath.section].departures[indexPath.row]
        
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

    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        let header = tableView.dequeueReusableHeaderFooterView(withIdentifier: "header") as? CollapsibleTableViewHeader ?? CollapsibleTableViewHeader(reuseIdentifier: "header")
        
        header.titleLabel.text = self.departuresSections[section].stop_name
        header.arrowLabel.text = "›"
        header.setCollapsed(self.departuresSections[section].collapsed)
        
        header.section = section
        header.delegate = self
        
        return header
    }
    
//    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
//        return 44.0
//    }
}


//
// MARK: - Section Header Delegate
//
extension TodayViewController: CollapsibleTableViewHeaderDelegate {
    
    func toggleSection(_ header: CollapsibleTableViewHeader, section: Int) {
        let collapsed = !self.departuresSections[section].collapsed
        
        // Toggle collapse
        self.departuresSections[section].collapsed = collapsed
        header.setCollapsed(collapsed)
        
        table.reloadSections(NSIndexSet(index: section) as IndexSet, with: .automatic)
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
            let total_count = self.departuresSections.reduce(0, { sum, section in
                sum + (section.collapsed ? 0 : section.departures.count) + 1
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
