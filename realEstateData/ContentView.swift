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

//Structures for json data:

struct PriceTrendsPerRoom: Codable {
    var max: [PriceDataPoint]
    var oneRoom: [PriceDataPoint]
    var twoRooms: [PriceDataPoint]
    var threeRooms: [PriceDataPoint]
}

struct PriceDataPoint: Codable {
    var date: String
    var price: Double
}

struct ServerError : Codable {
    var errorMessage: String
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

struct PickerData {
    var title: String
    var options: [PickerOption]
}

struct PickerOption {
    var text: String
    var tag: Int
}

//Data model for picker options:
let numberOfRoomsOptions = [PickerOption(text: "All", tag: 0),
                            PickerOption(text: "1", tag: 1),
                            PickerOption(text: "2", tag: 2),
                            PickerOption(text: "3", tag: 3)]

let numberOfRoomsPickerData = PickerData(title: "Filter by number of rooms", options: numberOfRoomsOptions)

let intervalOptions = [PickerOption(text: "Max", tag: 0),
                       PickerOption(text: "1 year", tag: 1),
                       PickerOption(text: "2 years", tag: 2),
                       PickerOption(text: "3 years", tag: 3)]

let intervalsPickerData = PickerData(title: "Price trends per year", options: intervalOptions)

//Constants:
let defaultTrend = PriceTrendsPerRoom(max: [], oneRoom: [], twoRooms: [], threeRooms: [])
let minimumNumberOfDataPoints = 5

let localHost = "http://127.0.0.1:5000/"
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
    
    //Retrives average square meter price trend for area
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
    
    //Returns true if an error occur else returns false
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
                    //If an http error occurs the backend sends a json in the ServerError structure, thus it tries to decode the json data into the ServerError structure
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
    
    //Fetches both price data and current listings for an area
    func getAllData(area: String) {
        self.isLoading = true
        
        //Unwraps optional URLs
        if let listingsUrl = self.getUrl(endPoint: listingsEndpoint, area: area), let pricesUrl = self.getUrl(endPoint: pricesEndpoint, area: area) {
            
            self.getPriceData(area: area, url: pricesUrl)
            self.getListings(area: area, url: listingsUrl)
        }
        
    }
    
    //Checks and converts letters to correct url charecters
    func textToURL(text : String) -> String{
        var currentText : String = ""
        for letter in text {
            
            if letter == "ö" {
                currentText += "%C3%B6"
            }
            else if letter == "ä" {
                currentText += "%C3%A4"
            }
            else if letter == "å" {
                currentText += "%C3%A5"
            }
            else if letter == " " {
                currentText += "%20"
            }
            else {
                currentText += String(letter)
            }
        }
        return currentText
    }
    
    //Checks if conversion from string to url is correct, if not it returns nil
    func getUrl(endPoint: String, area: String) -> URL? {
        
        let area = self.textToURL(text: area.lowercased())
        
        guard let url = URL(string:localHost + "\(endPoint)/\(area)") else {
            print("invalid url")
            self.errorMessage = "Invalid area, please try again"
            self.isLoading = false
            return nil
        }
        
        return url
    }
    
    //Fetch listings from the Flask API, updates listings if data is decoded into Listings structure
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
    
    //returns the min date from current data
    func getMinDate(priceDateData: [PriceDataPoint], interval: Int = 0) -> String{
        if interval == 0 {
            //gets the latest possible date
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
            
            //Returns the min date, i.e the current year - the current interval, ex: 2019 - 10
            return "\(minYear) - \(currentMonth)"
        }
    }
    
    //Date input should follow the structure of "year - month". If year exists, returns the year as an int else returns 0
    func getYear(date: String) -> Int {
        if let year = date.components(separatedBy: " ").first {
            return Int(year)!
        }
        return 0
    }
    
    //Date input should follow the structure of "year - month". If month exists, returns the month as an int else returns 0
    func getMonth(date: String) -> Int {
        if let month = date.components(separatedBy: " ").last {
            return Int(month)!
        }
        return 0
    }
    
    //Since the data retrived from the server is catogarized by number of rooms (see data models above), this function returns prices for the currently selected number of rooms.
    func dataForRoom(prices: PriceTrendsPerRoom, numberOfRooms: Int) -> [PriceDataPoint]{
        
        switch numberOfRooms {
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
    
    //Converts the data, following the PriceTrendsPerRoom structure, into an array of Doubles
    func pricesToDoubles(prices: PriceTrendsPerRoom, interval: Int = 0, numberOdRomms: Int = 0) -> [Double]{
        
        let priceDateData = self.dataForRoom(prices: prices, numberOfRooms: numberOdRomms)
        var prices : [Double] = []
        
        for dataPoint in priceDateData {
            
            prices.append(dataPoint.price)
            
            let minDate = getMinDate(priceDateData: priceDateData, interval: interval)
            let currentDate = dataPoint.date
            
            //breaks out of loop if the date is euquall to or exceeds the minimum date
            if interval != 0 {
                if currentDate == minDate || (self.getYear(date: currentDate) <= self.getYear(date: minDate) && (self.getMonth(date: currentDate) <= self.getMonth(date: minDate))){
                    break
                }
            }
            
        }
        return prices.reversed()
    }
    
    //Body of the content view, this is the parent view. The view contains conditional rendering, depending on the states variables
    var body: some View {
        
        VStack {
            
            InfoView()
            SearchView(areaName: $areaName, parentView: self)
            
            
            VStack(alignment: .leading) {
                
                //If loading, displays the loading indicator
                if self.isLoading {
                    LoadingIndicator()
                }
                else {
                    
                    //If error exits, displays a view showing the error message
                    if !errorMessage.isEmpty {
                        ErrorView(errorMessage: $errorMessage)
                    }
                    
                    //Checks that prices exists
                    if self.dataForRoom(prices: self.prices, numberOfRooms: self.numberOfRooms).count != 0 {
                        
                        VStack(alignment: .leading) {
                            Text("Price trends for \(self.areaTitel) (SEK/m2)").fontWeight(.heavy).font(.title)
                            
                            PercentageChangeView(prices: self.pricesToDoubles(prices: self.prices, interval: self.timeInterval, numberOdRomms: self.numberOfRooms))
                            
                            PickerView(bindingValue: $numberOfRooms, data: numberOfRoomsPickerData)
                            
                            PickerView(bindingValue: $timeInterval, data: intervalsPickerData)
                            
                        }.padding(.horizontal, 8)
                        
                        //The LineView displays the price trend graph. Accepts an array of doubles as data input. Startdate and endDate should follow the date convention of "year - month"
                        LineView(
                                data: self.pricesToDoubles(prices:self.prices, interval: self.timeInterval, numberOdRomms: self.numberOfRooms),
                                
                                startDate: self.getMinDate(priceDateData: self.dataForRoom(prices: self.prices, numberOfRooms: self.numberOfRooms),
                                                           
                                interval: self.timeInterval),
                                
                                endDate: self.dataForRoom(prices: self.prices, numberOfRooms: self.numberOfRooms)[0].date
                        )
                        
                        ListingsView(area: self.areaTitel, listings: self.listings)
                        
                    }

                }
            }.padding(.top, 24)
            
        }.frame(maxWidth: .infinity, maxHeight: .infinity)

        
    }
}

//VIEWS:

//Picker that creates options from picker data. On user interaction, updates the binding value
struct PickerView : View {
    
    @Binding var bindingValue : Int
    var data : PickerData
    
    var body: some View {
        Picker(selection: $bindingValue, label: Text(data.title)) {
            ForEach(self.data.options, id: \.tag) { option in
                Text("\(option.text)").tag(option.tag)
            }
        }.pickerStyle(SegmentedPickerStyle()).frame(width: 400)
    }
}

//Parent view for all listings. Creates a ListingsView for every listing.
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

//View for a single listing
struct ListingView : View {
    
    var listing: Listing
    
    //Opens the url in default browser
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

//View for the search bar
struct SearchView : View {
    
    @Binding var areaName : String
    var parentView : ContentView
    
    var body: some View {
        HStack {
            TextField("Enter area", text: $areaName)
                .frame(width: 150, height: 50)
                .textFieldStyle(SquareBorderTextFieldStyle())
            
            Button(action: {
                //Resets values after last search results
                self.parentView.prices = defaultTrend
                self.parentView.listings = []
                self.parentView.errorMessage = ""
                
                //Updates the areaTitel, which will update the state of the parent view
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

//View to display positive or negative trend in price data
struct PercentageChangeView : View {

    var prices : [Double]
    
    //Returns true if positive trend, else returns false
    func isPositiveTrend(percentage: Int) -> Bool {
        return (percentage >= 0) ? true : false
    }
    
    //Returns the percentage change in price trend
    func pricePercentageChange(prices: [Double]) -> Int {
        if let currentPrice = prices.last {
            let percentage = Int((currentPrice / prices[0])*100)
            return percentage - 100
        }
        return 0
    }
    
    //Returns "+" if positive trend, else returns "-"
    func plusOrMinus() -> String {
        return (self.isPositiveTrend(percentage: self.pricePercentageChange(prices: self.prices))) ? "+" : ""
    }
    
    var body: some View {
        
        HStack {
            Text("Percentage change: ").font(.subheadline).fontWeight(.heavy)
            
            Text("\(self.plusOrMinus()) \(self.pricePercentageChange(prices: self.prices))%")
                .font(.subheadline)
                .fontWeight(.heavy)
                .foregroundColor(self.isPositiveTrend(percentage: self.pricePercentageChange(prices: self.prices)) ? Color.green : Color.red)
            
        }
    }
}

//View that displays an error message
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

//View that displays an Loading indicator, consisting of a rotating image
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

//STYLES:

//Style for a blue button
struct BlueButtonStyle: ButtonStyle {
    func makeBody(configuration: Self.Configuration) -> some View {
        configuration.label
            .foregroundColor(configuration.isPressed ? Color.blue : Color.white)
            .background(configuration.isPressed ? Color.white : Color.blue)
            .cornerRadius(2.0)
            .padding()
    }
}
