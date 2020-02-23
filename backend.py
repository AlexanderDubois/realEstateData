from flask import Flask
from flask import Response
from flask import jsonify

#Imports for handling requests
import requests
import json

#Imports for creating the Booli hash
import time
import hashlib
import random
import string
import datetime

#The Booli_API class handles all of the functionality regarding interactings with the Booli API
class Booli_API:

	#Constants for Booli API structure:
	CALLER_ID = ''
	KEY = ''
	URL = "https://api.booli.se/"
	LISTINGS_ENDPOINT = "listings"
	PRICES_ENDPOINT = "sold"

	def __init__(self):
		self.limit = 1000 
		self.status_code = 200
		self.rooms_to_filer_by = [
									{"title": "max", "tag": 0},
									{"title": "oneRoom", "tag": 1},
									{"title": "twoRooms", "tag": 2},
									{"title": "threeRooms", "tag": 3}
								]

	#Returns hash for the booli api, se https://www.booli.se/p/api/
	def hash(self, time, unique):
		
		string_to_hash = '{}{}{}{}'.format(self.CALLER_ID, time, self.KEY, unique).encode()
		hash_object = hashlib.sha1(string_to_hash)
		hash_object = hash_object.hexdigest()

		return hash_object

	#Returns unique url, containg all the relevant information for the Booli API
	def get_url(self, url, area, offset=0):
		current_time = int(time.time())
		unique = ''.join(random.choices(string.ascii_uppercase + string.digits, k=16))

		booli_url = '{}?q={}&limit={}&offset={}&callerId={}&time={}&unique={}&hash={}'.format(url,area,self.limit,offset,self.CALLER_ID,current_time,unique, self.hash(current_time, unique))
		
		return booli_url

	#Returns url string with specified endpoint
	def get_url_string(self, end_point):
		return self.URL + end_point

	#Makes a url request to the specified url. If OK status code, returns json data
	def fetch_from_url(self, url, area, offset=0):
		
		booli_url = self.get_url(url, area, offset)
		req = requests.get(booli_url)

		if req.status_code == 200:
			return req.json()
		else:
			print("Error fetching from url", url)
			return {"totalCount": 0, errorMessage: "Could not fetch any data"}

	#Makes a single request to fetch current listings on Booli, returns dictionary with relevant data
	def fetch_current_listings(self,area):

		url = self.get_url_string(self.LISTINGS_ENDPOINT)
		data = self.fetch_from_url(url, area)

		if data["totalCount"] > 0:
			return self.remove_noise_from_current_listings(data)
		else:
			print("Error fetching current listings")
			return {"errorMessage": 'Could not fetch any listings for {}'.format(area)}

	#Removes unnecessary values from the json data, to make our frontend leaner. Retruns a list of listings dictionaries
	def remove_noise_from_current_listings(self, data):
		listings = []
		
		for listing in data["listings"]:

			if listing.get("listPrice") and listing.get("rooms"):

				new_json_listing = {
					"id": listing["booliId"],
					"price": listing["listPrice"],
					"address": listing["location"]["address"]["streetAddress"],
					"published": listing["published"],
					"rooms": listing["rooms"],
					"livingArea": listing["livingArea"],
					"url": listing["url"]
				}

				listings.append(new_json_listing)

		return listings

	#Since the Booli API has a maximum limit of retrieving 1000 listings/request, the function below keeps on making requests until all sold listings have been collected 
	def fetch_all(self,area, url, number_of_listings, json):
		all_listings = [json]

		if number_of_listings >= self.limit:
			current_offset = self.limit
			while (len(all_listings) * self.limit) <= number_of_listings:
				all_listings.append(self.fetch_from_url(url, area, current_offset))
				current_offset += self.limit

		return all_listings

	#Returns a dictionary containing square meter prices for each room group
	def dictionary_with_all_rooms(self, all_sold_listings):
		prices_per_room = {}
		for room in self.rooms_to_filer_by:
			prices_per_room[room["title"]] = self.from_json_to_price_per_square_meter_date(all_sold_listings, room["tag"])
		return prices_per_room

	#Returns all sold listings filtered by number of rooms
	def fetch_sold_listings(self, area):

		url = self.get_url_string(self.PRICES_ENDPOINT)
		json = self.fetch_from_url(url, area)
		
		number_of_listings = int(json["totalCount"])
		
		if number_of_listings > 0:
			all_sold_listings = self.fetch_all(area, url, number_of_listings, json)
			return self.dictionary_with_all_rooms(all_sold_listings)

		else:
			self.status_code = 400
			print("Error fetching all sold listings")
			return {"errorMessage": 'Could not fetch any data for {}'.format(area)}

	#Converst data from json to a dictionary with the keys prices/m2 and date. Returns
	def from_json_to_price_per_square_meter_date(self, json, number_of_rooms=0):
		prices = []
		for part in json:
			for listing in part["sold"]:
				#Checks that relevant variables aren't null
				if listing.get("soldDate") and listing.get("soldPrice") and listing.get("livingArea") and listing.get("rooms"):

					if number_of_rooms == 0 or listing["rooms"] == number_of_rooms:
						price_date = {}
						price_date["date"] = datetime.datetime.strptime(listing["soldDate"], "%Y-%m-%d")
						price_date["price"] = float(listing["soldPrice"]) / float(listing["livingArea"])
						prices.append(price_date)

		#Sorts prices by date, with the current date first
		sorted_prices = sorted(prices, key=lambda x:x['date'], reverse=True)

		print('Number of objects per room {}: {}'.format(number_of_rooms, len(sorted_prices)))

		if len(sorted_prices) > 0:
			return self.average_square_meter_price_per_month(sorted_prices) 
		else: 
			return [{"date": "", "price": 0}]
	
	#Returns a dictionary with the current date and the average price/m2	
	def average_price_dictionary_per_month(self, year, month, monthly_total, number_of_listings_per_month):
		month_price = {}
		month_price["date"] = self.date_format(year, month)

		if number_of_listings_per_month != 0:
			month_price["price"] = monthly_total / number_of_listings_per_month 
		else:
			month_price["price"] = monthly_total
		return month_price

	#Formats the year and month into desired format, ex: '2019 - 10'
	def date_format(self, year, month):
		return str(year) + " - " + str(month)

	#Formats price and date into desired format. Returns dictonairy in this format.
	def price_date_format(self, year, month, price):
		return {"date": self.date_format(year, month), "price": price}

	#Returns a dictionary containing all average prices/m2 divided per month
	def average_square_meter_price_per_month(self, sorted_prices):
		
		#Initial values:
		current_month = sorted_prices[0]["date"].month
		current_year = sorted_prices[0]["date"].year
		monthly_total = 0
		number_of_listings_per_month = 0

		monthly_price_data = []

		#If single listing, adds it to monthly_price_data
		if len(sorted_prices) == 1:
			monthly_price_data.append(self.price_date_format(current_year, current_month, sorted_prices[0]["price"]))

		else: 
			for listing in sorted_prices:

				if listing["date"].month == current_month:
					monthly_total += listing["price"]
					number_of_listings_per_month += 1
				else:
					monthly_price_data.append(self.average_price_dictionary_per_month(current_year, current_month, monthly_total, number_of_listings_per_month))

					#resets values:
					number_of_listings_per_month = 1
					monthly_total = listing["price"]
					current_month = listing["date"].month
					current_year = listing["date"].year

					#If last listing, the for loop wont run again, thus we add to monthly_price_data immediately
					if listing == sorted_prices[-1]:
						monthly_price_data.append(self.price_date_format(current_year, current_month, monthly_total))

		return monthly_price_data


app = Flask(__name__)

#Endpoint for retrieving prices for an area 
@app.route('/prices/<area>')
def median_price_for_area(area):
	api = Booli_API()
	response = app.response_class(response=json.dumps(api.fetch_sold_listings(area)),
                                  status=api.status_code,
                                  mimetype='application/json')
	return response

#Endpoint for retrieving listings for an area
@app.route('/listings/<area>')
def listings(area):
	api = Booli_API()
	response = app.response_class(response=json.dumps(api.fetch_current_listings(area)),
                                  status=api.status_code,
                                 mimetype='application/json')
	return response













