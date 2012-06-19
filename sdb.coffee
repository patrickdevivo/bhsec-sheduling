csv = require 'csv'
_ = require 'underscore'
Table = require 'cli-table'

class Class
	constructor: (@code, @sect, @title, @teacher, @room, @capacity, @grade) ->

classes = {}
schedule = {
	M: [[], [], [], [], [], [], [], []] # DAY: period[classess[]]
	T: [[], [], [], [], [], [], [], []]
	W: [[], [], [], [], [], [], [], []]
	R: [[], [], [], [], [], [], [], []]
	F: [[], [], [], [], [], [], [], []]
}

load_data = (callback)->
	grades = [9, 10]
	remaining = grades.length
	_.each(grades, (grade)->
		raw_classes = []
		raw_schedule = []
		csv()
			.fromPath("./grid#{grade}.csv")
			.on('data', (data, index)->
				if index < 9 and index >= 1 # store the schedule section of the csv
					raw_schedule.push(data)
				if index > 10 # store the classes section of the csv
					raw_classes.push(data)
			)
			.on('end', (count)->
				_.each(raw_classes, (class_, index)-> # add to classess object new instance of every read in class with our code (M1) + grade (10) as key --> M110
					classes[class_[0]+'-'+grade] = new Class class_[1], class_[2], class_[3].toUpperCase(), class_[4].toUpperCase(), class_[5], class_[6], grade
				)
				_.each(raw_schedule, (row, period)->
					# console.log row
					schedule.M[row[0]].push(_.map(row[1].split(' '), (code)->code+'-'+grade))
					schedule.T[row[0]].push(_.map(row[2].split(' '), (code)->code+'-'+grade))
					schedule.W[row[0]].push(_.map(row[3].split(' '), (code)->code+'-'+grade))
					schedule.R[row[0]].push(_.map(row[4].split(' '), (code)->code+'-'+grade))
					schedule.F[row[0]].push(_.map(row[5].split(' '), (code)->code+'-'+grade))
				)
				
				# some cleaning
				for period in [0..8]
					_.each(schedule, (day, key)->
						day[period] = _.flatten(day[period])
						day[period] = _.map(day[period], (code)-> if code and code.charAt(0) is '-' then return '' else return code)
						day[period] = _.without(day[period], '')
					)
				if (--remaining is 0)
					callback()
			)
			.on('error', (error)->
				console.log error
			)
	)
	
problems = new Table({
	head: ['Error', 'Message']
})

check_schedule = ->
	for day of schedule
		for period in schedule[day]
			for class_code in period
				problems.push(['unknown class code used', 'what class is ' + class_code + ' referring to?']) if not classes[class_code]
	
check_teachers = ->
	for day of schedule
		for period, index in schedule[day]
			# console.log schedule[day][index] is period
			teachers_prev_period = []
			teachers_this_period = []
			teachers_next_period = []
			
			if schedule[day][index-1]
				for class_code in schedule[day][index-1]
					if classes[class_code]
						teachers_prev_period.push(classes[class_code].teacher)
			for class_code in schedule[day][index]
				if classes[class_code]
					teachers_this_period.push(classes[class_code].teacher)
			if schedule[day][index+1]
				for class_code in schedule[day][index+1]
					if classes[class_code]
						teachers_next_period.push(classes[class_code].teacher)
			# check if a teacher is teaching multiple classes in a given period
			_.each(teachers_this_period, (teacher, i, list)->
				current = list.shift()
				if _.include(list, current)
					message = 'Check day ' + day + ' and period '+ index + ', ' + current + ' is overbooked'
					console.log message
					problems.push(['teacher conflict', message])
			)
			# check if a teacher is teaching more than three periods in a row
			_.each(teachers_this_period, (teacher) ->
				if _.include(teachers_prev_period, teacher) and _.include(teachers_next_period, teacher)
					prev = index-1 + ''
					next = index+1 + ''
					message = 'Check day ' + day + ' and periods ' + prev + ', ' + index + ', ' + next + ', ' + teacher + ' is scheduled 3 or more periods in a row'
					problems.push(['3+ periods for teacher', message])
			)

load_data(()->
	check_schedule()
	check_teachers()
	
	if problems.length > 1
		console.log problems.toString()
		
	console.log JSON.stringify(schedule)
)