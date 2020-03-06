//
//  GeofenseController.swift
//  RN59
//
//  Created by Edward on 3/5/20.
//  Copyright © 2020 Facebook. All rights reserved.
//

import Foundation
import CoreLocation
import UserNotifications

@objcMembers class GeofenseController: NSObject {
    let locationManager = CLLocationManager()
  
    func getInstance()
    {
      print("Hello .swift")
    }

    // MARK:
    // MARK: Fire Local Notifications
    func fireNotification(obj:TblGeofence , isEnter:Bool)
    {
        print("notification will be triggered in five seconds..Hold on tight")
        let content = UNMutableNotificationContent()
        content.title = obj.title ?? "TitleMissing"
        content.subtitle = obj.msg! + "at lat = \(obj.latitude) long = \(obj.longitude)"
        content.body = "You have \(isEnter ? "entered in" : "exited from") \(obj.title ?? "TitleMissing")"
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
  
    func initGeofences() {
        let lati = [37.621313, 37.422611]
        let longg = [-122.378955, -122.0840577]
        
        let Titlls = ["San Francisco", "Google"]
        
        let radius = [1609.00, 1609.00]
        
        for i in 0..<lati.count
            {
                let geoFance  = (TblGeofence.findOrCreate(dictionary: ["identifier":"\(Date.timeIntervalSinceReferenceDate)"]) as? TblGeofence)!
                geoFance.latitude = lati[i]
                geoFance.longitude = longg[i]
                geoFance.range = radius[i]
                geoFance.title = Titlls[i]
                geoFance.msg = "\(radius[i])"
                
                self.registerGeoFense(obj: geoFance)
        }
        
        CoreData.sharedInstance.saveContext()
    }
    
    // MARK:
    // MARK: GeoFance Management
    func registerGeoFense(obj : TblGeofence) {
        let centerCoordinate: CLLocationCoordinate2D = CLLocationCoordinate2DMake(obj.latitude, obj.longitude)
        let region = CLCircularRegion(center: centerCoordinate, radius: obj.range, identifier: obj.identifier!)
        
        region.notifyOnEntry = true
        region.notifyOnExit = true
        
        locationManager.stopMonitoring(for: region)
        
        locationManager.startMonitoring(for: region)
        
        locationManager.requestState(for: region)
    }
}

extension GeofenseController: CLLocationManagerDelegate {
    
  public func locationManager(_ manager: CLLocationManager, didEnterRegion region: CLRegion) {
        if region is CLCircularRegion {
            let geoFance  = (TblGeofence.findOrCreate(dictionary: ["identifier":region.identifier]) as? TblGeofence)!
            if (!(geoFance.title?.isEmpty)!)
            {
                // Reset registered region here...
                DispatchQueue.main.asyncDeduped(target: self, after: 2) { [weak self] in
                    self?.fireNotification(obj: geoFance, isEnter: false)
                }
            }
        }
    }
    
  public func locationManager(_ manager: CLLocationManager, didExitRegion region: CLRegion) {
        if region is CLCircularRegion {
            let geoFance  = (TblGeofence.findOrCreate(dictionary: ["identifier":region.identifier]) as? TblGeofence)!
            if (!(geoFance.title?.isEmpty)!)
            {
                DispatchQueue.main.asyncDeduped(target: self, after: 2) { [weak self] in
                    self?.fireNotification(obj: geoFance, isEnter: false)
                }
            }
        }
    }
}

extension GeofenseController:UNUserNotificationCenterDelegate{
    
  public func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        print("Tapped in notification")
    }
    
    //This is key callback to present notification while the app is in foreground
  public func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        
        print("Notification being triggered")
        let strDevides = notification.request.identifier.components(separatedBy: "++ ")
        
        let geoFance  = (TblGeofence.findOrCreate(dictionary: ["identifier":strDevides[0]]) as? TblGeofence)!
        
        DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + DispatchTimeInterval.milliseconds(Int(0))) {
            print(geoFance);
        }
        completionHandler( [.alert,.sound,.badge])
    }
}
