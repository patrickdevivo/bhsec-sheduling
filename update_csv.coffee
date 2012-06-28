fs = require 'fs'
request = require 'request'

urls = {
	9: 'https://docs.google.com/spreadsheet/pub?key=0Aqmu56ahZ_JbdHpQYkpUamkyOEFvZWZiNGdWYWNnbUE&output=csv'
	10: 'https://docs.google.com/spreadsheet/pub?key=0Aqmu56ahZ_JbdDNKMkxKTDh4a3kzbE5iQmh0bXZRWUE&output=csv'
	COL: 'https://docs.google.com/spreadsheet/pub?key=0Aqmu56ahZ_JbdDFoOWRqRE9oejdGT3doRW81Q2JsMVE&output=csv'
}

for grade, url of urls
	request(url, (error, response, body)->
		if error
			throw error
		else
			fs.writeFile("./grid#{grade}.csv", body, (error)->
				throw error if error
				console.log body
			)
	)