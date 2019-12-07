//
//  ContentView.swift
//  realEstateData
//
//  Created by Alexander Dubois on 2019-11-23.
//  Copyright © 2019 Youth Group. All rights reserved.
//

import SwiftUI
import Cocoa
import SwiftUICharts
/*

 Eventuella funktioner:
 -Se gatan, området, kommunen, staden med högst prisutveckling de sensatse x åren
 -Prisutveckling för dem med låg avgift (rent i apiet)
 
 -Booli innehåller om det är nyproduktion, jämför prisutveckling av dessa.
 -Jämföra med inflyttnings statistik ifrån SCB
 -Jämför ekonomi rating ifrån allabrf mot prisutveckling

 -Mäklare som ger högst slutpris (frågan är dock hur man skall beräkna detta?)
 -Hitta objekt med ordet 'juridisk person' i texten.
 -Prisutveckling för en förening, den med bäst i ett område
 
*/

let localHost = "http://127.0.0.1:5000/"

//Structures for our json data

struct PriceTrendsPerRoom: Codable {
    var max: [PriceDataPoint]
    var oneRoom: [PriceDataPoint]
    var twoRooms: [PriceDataPoint]
    var threeRooms: [PriceDataPoint]
}

struct ServerError : Codable {
    var errorMessage: String
}

struct PriceDataPoint: Codable {
    var date: String
    var price: Double
}

struct Listing: Codable {
    var id: Int
    var price: Double
    var address: String
    var published: String
    var rooms: Double
    var livingArea: Double
    var url: String
}

/*class API {
    let listingsEndpoint = "listings"
    let pricesEndpoint = "prices"
    let localHost = "http://127.0.0.1:5000/"
    
    func getPriceData(area: String, url: URL) {
      
        //Configures the URLSession to wait longer for response
        let sessionConfig = URLSessionConfiguration.default
        sessionConfig.timeoutIntervalForRequest = 150.0
        sessionConfig.timeoutIntervalForResource = 250.0
        
        //Request to server
        let task = URLSession(configuration: sessionConfig).dataTask(with: url) { (data, response, error) in
            
            if self.responseError(response: response, data: data, error: error) { return }
            
            if let data = data {
                
                //Tries to decode data into proper structure
                if let decodedData = try? JSONDecoder().decode(PriceTrendsPerRoom.self, from: data) {
                    
                    //Change to main thread to update the UI
                    DispatchQueue.main.async {
                        if decodedData.max.count >= minimumNumberOfDataPoints {
                            self.prices = decodedData
                        }
                        else {
                            self.errorMessage = "Couldn't fetch enough data for analysis"
                        }
                        
                        self.isLoading = false
                        
                    }
                }
            }
            
        }
        task.resume()
    }
    
    func responseError(response : URLResponse?, data: Data?, error: Error?) -> Bool {
        
        if let error = error {
            print("error: \(error)")
            self.isLoading = false
            return true
        }
        
        if let response = response as? HTTPURLResponse {
            
            //Handles all statuscodes, except 200, as errors
            if response.statusCode != 200 {
                if let data = data {
                    if let decodedData = try? JSONDecoder().decode(ServerError.self, from: data) {
                        
                        self.isLoading = false
                        self.errorMessage = decodedData.errorMessage
                    }
                    
                }
                return true
            }
            print("statusCode: \(response.statusCode)")
        }
        
        return false
    }
    
    func getAllData(area: String) {
        self.isLoading = true
        
        if let listingsUrl = self.getUrl(endPoint: listingsEndpoint, area: area), let pricesUrl = self.getUrl(endPoint: pricesEndpoint, area: area) {
            
            self.getPriceData(area: area, url: pricesUrl)
            self.getListings(area: area, url: listingsUrl)
        }
        
    }
    
    func getUrl(endPoint: String, area: String) -> URL? {
        
        let area = swedishWordToURL(word: area.lowercased())
        
        guard let url = URL(string:localHost + "\(endPoint)/\(area)") else {
            print("invalid url")
            self.errorMessage = "Invalid area, please try again"
            self.isLoading = false
            return nil
        }
        
        return url
    }
    
    func getListings(area: String, url: URL) {
        
        let task = URLSession.shared.dataTask(with: url) { (data, response, error) in
            
            if self.responseError(response: response, data: data, error: error) { return }
            
            if let data = data {
                
                //Tries to decode data into proper structure
                if let decodedData = try? JSONDecoder().decode([Listing].self, from: data) {
                    
                    //Change to main thread to update the UI
                    DispatchQueue.main.async {
                        
                        self.listings = decodedData
                        
                    }
                }
            }
            
        }
        task.resume()
    }
    
    func swedishWordToURL(word : String) -> String{
        var swedishWord : String = ""
        for letter in word {
            
            if letter == "ö" {
                swedishWord += "%C3%B6"
            }
            else if letter == "ä" {
                swedishWord += "%C3%A4"
            }
            else if letter == "å" {
                swedishWord += "%C3%A5"
            }
            else {
                swedishWord += String(letter)
            }
        }
        return swedishWord
    }

    
}*/

func swedishWordToURL(word : String) -> String{
    var swedishWord : String = ""
    for letter in word {
        
        if letter == "ö" {
            swedishWord += "%C3%B6"
        }
        else if letter == "ä" {
            swedishWord += "%C3%A4"
        }
        else if letter == "å" {
            swedishWord += "%C3%A5"
        }
        else {
            swedishWord += String(letter)
        }
    }
    return swedishWord
}

//TODO Structure functions better, maybe an API class


let defaultTrend = PriceTrendsPerRoom(max: [], oneRoom: [], twoRooms: [], threeRooms: [])
let minimumNumberOfDataPoints = 5

let listingsEndpoint = "listings"
let pricesEndpoint = "prices"

struct ContentView: View {
    
    @State private var areaName: String = ""
    @State var areaTitel : String = ""
    @State var errorMessage: String = ""
    
    @State var prices: PriceTrendsPerRoom = defaultTrend
    @State var listings: [Listing] = []
    
    @State private var timeInterval : Int = 0
    @State private var numberOfRooms : Int = 0
    
    @State private var isLoading : Bool = false
    
    func getPriceData(area: String, url: URL) {
      
        //Configures the URLSession to wait longer for response
        let sessionConfig = URLSessionConfiguration.default
        sessionConfig.timeoutIntervalForRequest = 150.0
        sessionConfig.timeoutIntervalForResource = 250.0
        
        //Request to server
        let task = URLSession(configuration: sessionConfig).dataTask(with: url) { (data, response, error) in
            
            if self.responseError(response: response, data: data, error: error) { return }
            
            if let data = data {
                
                //Tries to decode data into proper structure
                if let decodedData = try? JSONDecoder().decode(PriceTrendsPerRoom.self, from: data) {
                    
                    //Change to main thread to update the UI
                    DispatchQueue.main.async {
                        if decodedData.max.count >= minimumNumberOfDataPoints {
                            self.prices = decodedData
                        }
                        else {
                            self.errorMessage = "Couldn't fetch enough data for analysis"
                        }
                        
                        self.isLoading = false
                        
                    }
                }
            }
            
        }
        task.resume()
    }
    
    func responseError(response : URLResponse?, data: Data?, error: Error?) -> Bool {
        
        if let error = error {
            print("error: \(error)")
            self.isLoading = false
            return true
        }
        
        if let response = response as? HTTPURLResponse {
            
            //Handles all statuscodes, except 200, as errors
            if response.statusCode != 200 {
                if let data = data {
                    if let decodedData = try? JSONDecoder().decode(ServerError.self, from: data) {
                        
                        self.isLoading = false
                        self.errorMessage = decodedData.errorMessage
                    }
                    
                }
                return true
            }
            print("statusCode: \(response.statusCode)")
        }
        
        return false
    }
    
    func getAllData(area: String) {
        self.isLoading = true
        
        if let listingsUrl = self.getUrl(endPoint: listingsEndpoint, area: area), let pricesUrl = self.getUrl(endPoint: pricesEndpoint, area: area) {
            
            self.getPriceData(area: area, url: pricesUrl)
            self.getListings(area: area, url: listingsUrl)
        }
        
    }
    
    func getUrl(endPoint: String, area: String) -> URL? {
        
        let area = swedishWordToURL(word: area.lowercased())
        
        guard let url = URL(string:localHost + "\(endPoint)/\(area)") else {
            print("invalid url")
            self.errorMessage = "Invalid area, please try again"
            self.isLoading = false
            return nil
        }
        
        return url
    }
    
    func getListings(area: String, url: URL) {
        
        let task = URLSession.shared.dataTask(with: url) { (data, response, error) in
            
            if self.responseError(response: response, data: data, error: error) { return }
            
            if let data = data {
                
                //Tries to decode data into proper structure
                if let decodedData = try? JSONDecoder().decode([Listing].self, from: data) {
                    
                    //Change to main thread to update the UI
                    DispatchQueue.main.async {
                        
                        self.listings = decodedData
                        
                    }
                }
            }
            
        }
        task.resume()
    }
    
    
    func getMinDate(priceDateData: [PriceDataPoint], interval: Int = 0) -> String{
        if interval == 0 {
            if let lastDataPoint = priceDateData.last {
                return lastDataPoint.date
            }
            return ""
        }
        else {
            let currentDate = priceDateData[0].date
            let currentYear = self.getYear(date: currentDate)
            let currentMonth = self.getMonth(date: currentDate)
            
            let minYear = currentYear - interval
            
            return "\(minYear) - \(currentMonth)"
        }
    }
    
    func getYear(date: String) -> Int {
        if let year = date.components(separatedBy: " ").first {
            return Int(year)!
        }
        return 0
    }
    
    func getMonth(date: String) -> Int {
        if let month = date.components(separatedBy: " ").last {
            return Int(month)!
        }
        return 0
    }
    
    func dataForRoom(prices: PriceTrendsPerRoom, numberOdRomms: Int) -> [PriceDataPoint]{
        
        switch numberOdRomms {
        case 0:
             return prices.max
        case 1:
            return (prices.oneRoom.count >= minimumNumberOfDataPoints) ? prices.oneRoom : prices.max
        case 2:
            return (prices.twoRooms.count >= minimumNumberOfDataPoints) ? prices.twoRooms : prices.max
        case 3:
           return (prices.threeRooms.count >= minimumNumberOfDataPoints) ? prices.threeRooms : prices.max
        default:
             return prices.max
            
        }
    }
    
    func pricesToDoubles(prices: PriceTrendsPerRoom, interval: Int = 0, numberOdRomms: Int = 0) -> [Double]{
        
        let priceDateData = self.dataForRoom(prices: prices, numberOdRomms: numberOdRomms)
        
        let minDate = getMinDate(priceDateData: priceDateData, interval: interval)
        
        var prices : [Double] = []
        for dataPoint in priceDateData {
            
            prices.append(dataPoint.price)
            
            let currentDate = dataPoint.date
            if interval != 0 {
                if currentDate == minDate || (self.getYear(date: currentDate) <= self.getYear(date: minDate) && (self.getMonth(date: currentDate) <= self.getMonth(date: minDate))){
                    break
                }
            }
            
        }
        return prices.reversed()
    }
    
    var body: some View {
        
        VStack {
            
            InfoView()
            SearchView(areaName: $areaName, parentView: self)
            
            
            VStack(alignment: .leading) {
                
                if self.isLoading {
                    LoadingIndicator()
                }
                else {
                    
                    if !errorMessage.isEmpty {
                        ErrorView(errorMessage: $errorMessage)
                    }
                    
                    if self.dataForRoom(prices: self.prices, numberOdRomms: self.numberOfRooms).count != 0 {
                        
                        VStack(alignment: .leading) {
                            Text("Price trends for \(self.areaTitel) (SEK/m2)").fontWeight(.heavy).font(.title)
                            
                            PercentageChangeView(prices: self.pricesToDoubles(prices: self.prices, interval: self.timeInterval, numberOdRomms: self.numberOfRooms))
                            
                            Picker("Filter by number of rooms", selection: $numberOfRooms) {
                                Text("All").tag(0)
                                Text("1").tag(1)
                                Text("2").tag(2)
                                Text("3").tag(3)
                                }.pickerStyle(SegmentedPickerStyle()).frame(width: 400)
                            
                            Picker("Price trends per year", selection: $timeInterval) {
                                Text("Max").tag(0)
                                Text("1 year").tag(1)
                                Text("2 years").tag(2)
                                Text("3 years").tag(3)
                                }.pickerStyle(SegmentedPickerStyle()).frame(width: 400)
                            
                        }.padding(.horizontal, 8)
                        
                        LineView(
                                data: self.pricesToDoubles(prices:self.prices, interval: self.timeInterval, numberOdRomms: self.numberOfRooms),
                                
                                startDate: self.getMinDate(priceDateData: self.dataForRoom(prices: self.prices, numberOdRomms: self.numberOfRooms),
                                                           
                                interval: self.timeInterval),
                                
                                endDate: self.dataForRoom(prices: self.prices, numberOdRomms: self.numberOfRooms)[0].date
                        )
                        
                        ListingsView(area: self.areaTitel, listings: self.listings)
                        
                    }

                }
            }.padding(.top, 24)
            
        }.frame(maxWidth: .infinity, maxHeight: .infinity)

        
    }
}

struct ListingsView : View {
    var area: String
    var listings : [Listing]
    
    var body: some View {
        VStack(alignment: .leading) {
            Text("Current listings in \(self.area): ")
                .font(.title).fontWeight(.heavy).padding(.leading, 8)
            
            List(self.listings, id: \.id) { listing in
                ListingView(listing: listing)
            }
        }.padding(.top, 54)
    }
}

struct SearchView : View {
    
    @Binding var areaName : String
    var parentView : ContentView
    
    var body: some View {
        HStack {
            TextField("Enter area", text: $areaName)
                .frame(width: 150, height: 50)
                .textFieldStyle(SquareBorderTextFieldStyle())
            
            Button(action: {
                self.parentView.prices = defaultTrend
                self.parentView.listings = []
                self.parentView.errorMessage = ""
                
                self.parentView.areaTitel = self.areaName
                
                self.parentView.getAllData(area: self.areaName)
            }) {
                Text("Search")
            }
        }
    }
}

struct InfoView : View {
    var body: some View  {
        VStack {
            Text("Real estate data analysis 🏡")
                .font(.largeTitle).fontWeight(.heavy)
                   
            Text("Please search for an area of interest below to recive market data")
                .font(.subheadline).fontWeight(.heavy)
        }
    }
}

struct PercentageChangeView : View {

    var prices : [Double]
    
    func isPositiveTrend(percentage: Int) -> Bool {
        return (percentage >= 0) ? true : false
    }
    
    func priceIncrease(prices: [Double]) -> Int {
        if let currentPrice = prices.last {
            let percentage = Int((currentPrice / prices[0])*100)
            return percentage - 100
        }
        return 0
    }
    
    func plusOrMinus() -> String {
        return (self.isPositiveTrend(percentage: self.priceIncrease(prices: self.prices))) ? "+ " : " "
    }
    
    var body: some View {
        
        HStack {
            Text("Percentage change: ").font(.subheadline).fontWeight(.heavy)
            
            Text("\(self.plusOrMinus()) \(self.priceIncrease(prices: self.prices))%")
                .font(.subheadline)
                .fontWeight(.heavy)
                .foregroundColor(self.isPositiveTrend(percentage: self.priceIncrease(prices: self.prices)) ? Color.green : Color.red)
            
        }
    }
}

struct ErrorView : View {
    
    @Binding var errorMessage : String
    
    var body: some View {
        VStack {
            Text("❌😩").font(.largeTitle)
            Text(self.errorMessage).font(.subheadline).fontWeight(.heavy)
            Button(action: {
                self.errorMessage = ""
            }) {
                Text("Got it")
            }
        }.frame(width: 350, height: 200, alignment: .center).border(Color.white, width: 4)
    }
}

struct ListingView : View {
    
    var listing: Listing
    
    func openUrlInBrowser(url: String) {
        if let url = URL(string: url) {
            if !NSWorkspace.shared.open(url) {
                print("error opening browser")
            }
        }
    }
    var body: some View {
        VStack(alignment: .leading) {
            Text(self.listing.address).font(.headline).fontWeight(.heavy)
            HStack{
                Text("\(Int(self.listing.price)) SEK").fontWeight(.heavy)
                Text("\(Int(self.listing.livingArea)) m2")
                Text("\(Int(self.listing.rooms)) rooms")
                Spacer()
                
                Button(action: {
                    self.openUrlInBrowser(url: self.listing.url)
                }) {
                    Text("Open broker ad in browser").padding(10)
                }.buttonStyle(BlueButtonStyle())
            }
            Text("\(self.listing.published)")
            
        }.padding(.bottom, 16)
    }
}

struct BlueButtonStyle: ButtonStyle {
    func makeBody(configuration: Self.Configuration) -> some View {
        configuration.label
            .foregroundColor(configuration.isPressed ? Color.blue : Color.white)
            .background(configuration.isPressed ? Color.white : Color.blue)
            .cornerRadius(2.0)
            .padding()
    }
}

struct LoadingIndicator: View {
    
    @State var spin = false
    
    var body: some View {
        Image("loading")
            .resizable()
            .frame(width: 80, height: 80)
            .rotationEffect(.degrees(spin ? 360 : 0))
            .animation(Animation.linear(duration: 1.3).repeatForever(autoreverses: false))
            .onAppear {
                self.spin.toggle()
            }
    }
}


struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView().padding(18)
    }
}
