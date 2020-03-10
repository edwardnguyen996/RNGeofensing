//
//  AppDelegate.swift
//  Geofence

//
//  Created by Mind on 03/02/18.
//  Copyright © 2018 Mindinventory. All rights reserved.
//

import UIKit
import CoreLocation
import UserNotifications
import React

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?
    let locationManager = CLLocationManager()

    internal func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        self.window = UIWindow(frame: UIScreen.main.bounds)
        self.window?.rootViewController = UINavigationController(rootViewController: ViewController())
        self.window?.makeKeyAndVisible()
        self.enableLocationServices()
        return true
    }
    
    func enableLocationServices()
    {
        locationManager.delegate = self
    }
    
    func countryCodeToFlag(countryCode:String) -> String {
        let base = 127397
        var usv = String.UnicodeScalarView()
        for i in countryCode.utf16 {
            usv.append(UnicodeScalar(base + Int(i))!)
        }
        return String(usv)
    }

    // MARK:
    // MARK: Fire Local Notifications
    func fireNotification(obj: TblGeofence, countryCode: String, isEnter: Bool)
    {
        print("notification will be triggered in five seconds..Hold on tight")
        let flag = countryCodeToFlag(countryCode: countryCode);
        let content = UNMutableNotificationContent()
        content.title = obj.title!
        content.body = "You entered " + countryCode + " " + flag;
        content.sound = UNNotificationSound.default
        
        let trigger = UNTimeIntervalNotificationTrigger.init(timeInterval: 0.1, repeats: false)
        let request = UNNotificationRequest(identifier:obj.identifier! + "++ \(isEnter ? "1" : "0") \(NSDate.timeIntervalSinceReferenceDate)", content: content, trigger: trigger)
        
        UNUserNotificationCenter.current().delegate = self
        UNUserNotificationCenter.current().add(request){(error) in
            if (error != nil){
                print(error?.localizedDescription ?? "error in notifications")
            }
        }
    }
    
    func startTracking() {
        let lat = locationManager.location?.coordinate.latitude;
        let lng = locationManager.location?.coordinate.longitude;

        if (lat == nil || lng == nil) {
            return print("Please select a location first!");
        }

        let geoFense = (TblGeofence.findOrCreate(dictionary: ["identifier":"\(Date.timeIntervalSinceReferenceDate)"]) as? TblGeofence)!

        geoFense.latitude = lat!;
        geoFense.longitude = lng!;
        geoFense.range = 20000;
        geoFense.title = "Geofensing";

        registerGeoFance(obj: geoFense)

        CoreData.sharedInstance.saveContext()
    }
    
    // MARK:
    // MARK: GeoFance Management
    func registerGeoFance(obj: TblGeofence) {
        locationManager.monitoredRegions.forEach { region in
            locationManager.stopMonitoring(for: region)
        }
        
        let centerCoordinate: CLLocationCoordinate2D = CLLocationCoordinate2DMake(obj.latitude, obj.longitude)
        let region = CLCircularRegion(center: centerCoordinate, radius: obj.range, identifier: obj.identifier!)
        
        region.notifyOnEntry = true
        region.notifyOnExit = true
        
        locationManager.stopMonitoring(for: region)

        locationManager.startMonitoring(for: region)
        
        locationManager.requestState(for: region);
        
        print(region);
        
        print("Started to tracking...")
    }
    
    func getCurrentCountryCode(lat: Double, lng: Double) -> String {
        var countryCode = "";
        let url = URL(string: "http://api.geonames.org/countryCodeJSON?lat=" + String(lat) + "&lng=" + String(lng) + "&username=relocare2")!;
        let sem = DispatchSemaphore(value: 0);
        
        let task = URLSession.shared.dataTask(with: url) {(data, response, error) in
            defer { sem.signal() }
            guard let data = data else { return }
            do {
                let json = try JSONSerialization.jsonObject(with: data, options: .allowFragments) as? [String:Any]
                countryCode = json?["countryCode"] as? String ?? "US"
            } catch let error as NSError {
                print(error)
            }
        }
        task.resume();
        _ = sem.wait(timeout: DispatchTime.distantFuture);
        return countryCode;
    }
}

extension AppDelegate: CLLocationManagerDelegate {
    
    func locationManager(_ manager: CLLocationManager, didEnterRegion region: CLRegion) {
        if region is CLCircularRegion {
            let geoFance = (TblGeofence.findOrCreate(dictionary: ["identifier":region.identifier]) as? TblGeofence)!
            print("Entered: " + String(geoFance.latitude));
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didExitRegion region: CLRegion) {
        print(region);
        if region is CLCircularRegion {
            let geoFance = (TblGeofence.findOrCreate(dictionary: ["identifier":region.identifier]) as? TblGeofence)!
            DispatchQueue.main.asyncDeduped(target: self, after: 2) { [weak self] in
                let lat = manager.location?.coordinate.latitude;
                let lng = manager.location?.coordinate.longitude;
                let countryCode = self?.getCurrentCountryCode(lat: lat!, lng: lng!);
                self?.fireNotification(obj: geoFance, countryCode: countryCode!, isEnter: false)
                
                let geoFense = (TblGeofence.findOrCreate(dictionary: ["identifier":"\(Date.timeIntervalSinceReferenceDate)"]) as? TblGeofence)!
                geoFense.latitude = lat!;
                geoFense.longitude = lng!;
                geoFense.range = 20000;
                
                self?.registerGeoFance(obj: geoFense)
            }
        }
    }
}

extension AppDelegate:UNUserNotificationCenterDelegate{
    
    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        print("Tapped in notification")
    }
    
    //This is key callback to present notification while the app is in foreground
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        
        print("Notification being triggered")
        let strDevides = notification.request.identifier.components(separatedBy: "++ ")
        
        let geoFance  = (TblGeofence.findOrCreate(dictionary: ["identifier":strDevides[0]]) as? TblGeofence)!
        
        DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + DispatchTimeInterval.milliseconds(Int(0))) {
            print(geoFance);
        }
        completionHandler( [.alert,.sound,.badge])
    }
}

extension UIApplication {
    class func topViewController(base: UIViewController? = (UIApplication.shared.delegate as! AppDelegate).window?.rootViewController) -> UIViewController? {
        if let nav = base as? UINavigationController {
            return topViewController(base: nav.visibleViewController)
        }
        if let tab = base as? UITabBarController {
            if let selected = tab.selectedViewController {
                return topViewController(base: selected)
            }
        }
        if let presented = base?.presentedViewController {
            return topViewController(base: presented)
        }
        return base
    }
}
