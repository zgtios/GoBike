//
//  BikeStationInfo.swift
//  PBike
//
//  Created by 陳 冠禎 on 2016/10/16.
//  Copyright © 2016年 陳 冠禎. All rights reserved.
//

import Foundation
import Alamofire
import SWXMLHash
import SwiftyJSON
import CoreLocation
import Kanna


protocol BikeStationDelegate {
    var  stations: [Station] { get }
    var  numberOfAPIs:Int { get }
    var  citys: [String] { get }
    func downloadInfoOfBikeFromAPI(completed:@escaping DownloadComplete)
    func current(station:[Station], index:Int) -> Int
    func numberOfBikeIsUsing(station: [Station], count:Int) -> Int
    func bikesInStation(station: [Station], count:Int) -> Int
    func statusOfStationImage(station:[Station], index:Int) -> String
    func findLocateBikdAPI2Download(userLocation: CLLocationCoordinate2D)
    
}


class BikeStation:BikeStationDelegate {
    
    internal var stations: [Station] { return _stations }
    var numberOfAPIs = 0
    
    var _date: String!
    var bikeOnService: Int = 500
    var Bike_URL = "http://pbike.pthg.gov.tw/xml/stationlist.aspx"
    var citys: [String] = []
    var longitude = ""
    var lativtude = ""
    var _stations: [Station] = []
    var apis = Bike().apis
    
    internal func downloadInfoOfBikeFromAPI(completed:@escaping DownloadComplete) {
        //Alamofire download
        
        #if CityBike
            
            self.Bike_URL = "http://www.c-bike.com.tw/xml/stationlistopendata.aspx"
            
            self.bikeOnService = 2500
            print("*****************\n")
            print("CityBike Version")
            print("\n*****************")
            
        #elseif PBike
            
            self.Bike_URL = "http://pbike.pthg.gov.tw/xml/stationlist.aspx"
            self.bikeOnService = 500
            print("*****************\n")
            print("PBike Version")
            print("\n*****************")
            
        #elseif GoBike
            
            
            print("*****************\n")
            print("GoBike Version")
            print("\n*****************")
            
        #endif
        
        
        self._stations.removeAll()
        numberOfAPIs = 0
        citys.removeAll() //inital
        
        
        for api in apis {
            guard api.isHere else { continue }
            self.numberOfAPIs += 1
            citys.append(api.city)
            print("User in here: \(api.city)", self.numberOfAPIs)
            guard let currentBikeURL = URL(string: api.url) else {print("URL error"); return}
            
            switch api.dataType {
            case .XML:
                Alamofire.request(currentBikeURL).responseString { response in
                    print("資料來源: \(response.request!)\n 伺服器傳輸量: \(response.data!)\n")
                    
                    guard response.result.isSuccess else { print("response is failed") ; return }
                    guard let xmlToParse = response.result.value else { print("error, can't unwrap response data"); return }
                    let xml = SWXMLHash.parse(xmlToParse)
                    
                    
                    do {
                        guard let stationsXML:[StationXML] = try xml["BIKEStationData"]["BIKEStation"]["Station"].value() else { return }
                        let stations:[Station] = self.xmlToStation(key:api.city ,stations: stationsXML)
                        self._stations.append(contentsOf: stations)
                    } catch { print("error:", error) }
                    
                    completed() // main
                }
                
            case .JSON:
                Alamofire.request(currentBikeURL).validate().responseJSON { response in
                    print("資料來源: \(response.request!)\n 伺服器傳輸量: \(response.data!)\n")
                    print("success", api.city)
                   
                    switch response.result {
                    case .success(let value):
                        
                        let json = JSON(value)
                        guard let stations:[Station] = self.parseJSON2Object(api.city, json: json) else {print("station is nil plz check parseJson"); return}
                        self._stations.append(contentsOf: stations)
                        completed()
                        
                    case .failure(let error):
                        print("error", error)
                    }
                }
                
            case .html:
                Alamofire.request(currentBikeURL).responseString { response in
                    print("資料來源: \(response.request!)\n 伺服器傳輸量: \(response.data!)\n")
                    print("\(response.result.isSuccess)")
                    if let html = response.result.value {
                        self.parseHTML(city: api.city,html: html)
                    completed()
                    } else { print("Can not parseHTML, please check parseHTML func" )}
                }
            } // switch
        }//for lop
    }
    
    func parseHTML(city:String, html: String) -> Void {

        guard let doc = Kanna.HTML(html: html, encoding: String.Encoding.utf8) else {print("doc can't be assigned by  html"); return }
        let node = doc.css("script")[21]
        let uriDecoded = node.text?.between("arealist='", "';arealist=JSON")?.urlDecode
        guard let dataFromString = uriDecoded?.data(using: String.Encoding.utf8, allowLossyConversion: false) else { print("dataFromString can't be assigned Changhau & Hsinchu"); return }
        let json = JSON(data: dataFromString)
        guard let stations:[Station] = self.parseJSON2Object(city, json: json) else {print("station is nil plz check parseJson"); return}
        self._stations.append(contentsOf: stations)
        
    }
    
    func findLocateBikdAPI2Download(userLocation: CLLocationCoordinate2D) {
        let latitude = userLocation.latitude.format //(%.2 double)
        let longitude = userLocation.longitude.format
        for index in 0..<apis.count {
            switch (apis[index].city, latitude, longitude){
                
            case ("taipei", 24.96...25.14 , 121.44...121.65):
                apis[index].isHere = true
                self.bikeOnService = 7500
                
            case ("newTaipei", 25.09...25.10 , 121.51...121.60):
                apis[index].isHere = true
                self.bikeOnService = 15000
                
            case ("taoyuan", 24.81...25.11 , 120.9...121.4):
                apis[index].isHere = true
                self.bikeOnService = 2800
                
            case ("Hsinchu", 24.67...24.96 , 120.81...121.16):
                apis[index].isHere = true
                self.bikeOnService = 1350
                
            case ("taichung", 24.03...24.35 , 120.40...121.00):
                apis[index].isHere = true
                self.bikeOnService = 7000
                
            case ("Changhua", 23.76...24.23 , 120.06...120.77):
                apis[index].isHere = true
                self.bikeOnService = 7000
                
            case ("tainan", 22.72...23.47 , 119.94...120.58):
                apis[index].isHere = true
                self.bikeOnService = 300
                
            case ("kaohsiung", 22.46...22.73 , 120.17...120.44):
                apis[index].isHere = true
                self.bikeOnService = 2500
                
            case ("pingtung", 22.62...22.71 , 120.430...120.53):
                apis[index].isHere = true
                self.bikeOnService = 500
                
            default:  //show alart
                apis[index].isHere = false
            }
            print("set",apis[index].city,"to" ,apis[index].isHere)
        }
    }
    
    func parseJSON2Object(_ callIdentifier: String, json: JSON)  ->  [Station]? {
        var jsonStation: [Station] = []
//        print("callIdentifier:",callIdentifier, "\n json:", json)
        guard !(json.isEmpty) else { print("json is empty"); return nil }
        
        func deserializableJSON(json: JSON) -> [Station] {
            var deserializableJSONStation:[Station] = []
            print("call deserializableJSON")
            
            for (_, dict) in json {
                
                let obj = Station(
                    name: dict["sna"].string,
                    location: dict["ar"].stringValue,
                    parkNumber: dict["bemp"].intValue,
                    currentBikeNumber: dict["sbi"].intValue,
                    longitude: dict["lng"].doubleValue,
                    latitude: dict["lat"].doubleValue)
            
                deserializableJSONStation.append(obj)
            }
            return deserializableJSONStation
        }
        
        func deserializableJSONOfTainan(json: JSON) -> [Station] {
            var deserializableJSONStation:[Station] = []
            for (_, dict) in json {
                
                let obj = Station(
                    name: dict["StationName"].string,
                    location: dict["Address"].stringValue,
                    parkNumber: dict["AvaliableSpaceCount"].intValue,
                    currentBikeNumber: dict["AvaliableBikeCount"].intValue,
                    longitude: dict["Longitude"].doubleValue,
                    latitude: dict["Latitude"].doubleValue)
                
                deserializableJSONStation.append(obj)
            }
            return deserializableJSONStation
        }
        var jsonArray = json[]
        switch callIdentifier {
        case "taipei","taichung":
            jsonArray = json["retVal"]
            jsonStation = deserializableJSON(json: jsonArray)
            
        case "newTaipei", "taoyuan":
            jsonArray = json["result"]["records"]
            jsonStation = deserializableJSON(json: jsonArray)
            
        case "Changhua", "Hsinchu":
            jsonArray = json
            jsonStation = deserializableJSON(json: jsonArray)
            
        case "tainan":
            jsonArray = json
            jsonStation = deserializableJSONOfTainan(json: jsonArray)
        
        default:
            print("callIdentifier error")
        }
        return jsonStation
    }
    
    func enumerate(indexer: XMLIndexer, level: Int) {
        for child in indexer.children {
            let name = child.element!.name
            print("\(level) \(name)")
            enumerate(indexer: child, level: level + 1)
        }
    }
    
    internal func current(station:[Station], index:Int) -> Int {
        return { station[index].currentBikeNumber! + station[index].parkNumber! }()
    }
    
    internal func numberOfBikeIsUsing(station: [Station], count:Int) -> Int {
        var bikesInStation = 0
        var bikesInUsing = 0
        for index in 0..<count {
            bikesInStation += station[index].currentBikeNumber!
        }
        
        bikesInUsing = bikeOnService - bikesInStation
        if bikesInStation <= 0 { bikesInStation = 0 }
        return bikesInUsing
    }
    
    internal func bikesInStation(station: [Station], count:Int) -> Int {
        var currentBikeNumber = 0
        for index in 0..<count {
            currentBikeNumber += station[index].currentBikeNumber!
        }
        return currentBikeNumber
    }
    
    internal func statusOfStationImage(station:[Station], index:Int) -> String {
        var pinImage = ""
        
        if let numberOfBike = station[index].currentBikeNumber {
            
            switch numberOfBike {
            
            case 1...5:
                pinImage = "pinLess"
                
            case 5...200:
                if station[index].parkNumber == 0 {
                    pinImage = "pinFull"
                 } else {pinImage = "pinMed"}
                
            case 0: pinImage = "pinEmpty"
                
            default: pinImage  = "pinUnknow"
                
            }
        }
        return pinImage
    }
    
    func xmlToStation(key:String, stations:[StationXML]) -> [Station] {
        var _station:[Station]  = []
        let count = stations.count
        switch key {

        case "pingtung":
            
            for index in 0..<count  {
                
                let obj = Station(
                    name: stations[index].name,
                    location: stations[index].location,
                    parkNumber: stations[index].parkNumber,
                    currentBikeNumber: stations[index].currentBikeNumber,
                    longitude: stations[index].latitude,
                    latitude: stations[index].longitude
                )
                
                _station.append(obj)
            }
            
        default:
            for index in 0..<count  {
                let obj = Station(
                    name: stations[index].name,
                    location: stations[index].location,
                    parkNumber: stations[index].parkNumber,
                    currentBikeNumber: stations[index].currentBikeNumber,
                    longitude: stations[index].longitude,
                    latitude: stations[index].latitude
                )
                _station.append(obj)
            }
        }
        return _station
    }
}

extension Double {
    var format:Double {
        return Double(String(format:"%.2f", self))!
    }
}

public extension String {
    
    //right is the first encountered string after left
    func between(_ left: String, _ right: String) -> String? {
        guard
            let leftRange = range(of: left), let rightRange = range(of: right, options: .backwards)
            , left != right && leftRange.upperBound < rightRange.lowerBound
            else { return nil }
        
        let sub = self.substring(from: leftRange.upperBound)
        let closestToLeftRange = sub.range(of: right)!
        return sub.substring(to: closestToLeftRange.lowerBound)
    }
    
    var length: Int {
        get {
            return self.characters.count
        }
    }
    
    func substring(to : Int) -> String? {
        if (to >= length) {
            return nil
        }
        let toIndex = self.index(self.startIndex, offsetBy: to)
        return self.substring(to: toIndex)
    }
    
    func substring(from : Int) -> String? {
        if (from >= length) {
            return nil
        }
        let fromIndex = self.index(self.startIndex, offsetBy: from)
        return self.substring(from: fromIndex)
    }
    
    func substring(_ r: Range<Int>) -> String {
        let fromIndex = self.index(self.startIndex, offsetBy: r.lowerBound)
        let toIndex = self.index(self.startIndex, offsetBy: r.upperBound)
        return self.substring(with: Range<String.Index>(uncheckedBounds: (lower: fromIndex, upper: toIndex)))
    }
    
    func character(_ at: Int) -> Character {
        return self[self.index(self.startIndex, offsetBy: at)]
    }
    
}

extension String {
    // url encode
    var urlEncode:String? {
        return self.addingPercentEncoding(withAllowedCharacters: NSCharacterSet(charactersIn: "!*'\\\\\"();:@&=+$,/?%#[]% ").inverted)
    }
    // url decode
    var urlDecode: String? {
        return self.removingPercentEncoding
    }
}

