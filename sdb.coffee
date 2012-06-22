csv = require 'csv'
_ = require 'underscore'
Table = require 'cli-table'
fs = require 'fs'
request = require 'request'
repl = require 'repl'

class Class
	constructor: (@shorthand, @code, @sect, @title, @teacher, @room, @capacity, @grade) ->
		@enrollment = []

	check_enrollment_possible: (student_id) ->
		if @enrollment.length >= @capacity
			message = [false, 'Not enough space']
		else
			current_student = ''
			_.each(students, (student, index) =>
				if student.id is student_id
					current_student = students[index]
			)
			
			# check if class fits in student's current schedule
			possible = true
			class_meets = this.get_meeting_times()
								
			# console.log class_meets
					
			for i, student_day of current_student.schedule
				for meeting in class_meets
					if meeting.split('-')[0] is i
						if current_student.schedule[meeting.split('-')[0]][meeting.split('-')[1]] isnt ''
							possible = false
			
			if possible is false then note = 'Conflict' else note = ''
			message = [possible, note]
			return message
			
	get_meeting_times: ->
		class_meets = []
		for j, day of schedule
			for period, period_number in day
				for class_ in period
					if class_ is @shorthand # when
						class_meets.push(j+'-'+period_number)
						
		return class_meets
		

	enroll_student: (student_id) ->
		if this.check_enrollment_possible(student_id)[0] is true
			@enrollment.push(student_id)
			class_meets = this.get_meeting_times()
			
			# lookup current student
			current_student = ''
			_.each(students, (student, index) =>
				if student.id is student_id
					current_student = students[index]
			)
			
			for meeting in class_meets
				current_student.schedule[meeting.split('-')[0]][meeting.split('-')[1]] += this.shorthand
			
			return true
		else
			return false
			

classes = {}
schedule = {
	M: [[], [], [], [], [], [], [], []] # DAY: period[classess[]]
	T: [[], [], [], [], [], [], [], []]
	W: [[], [], [], [], [], [], [], []]
	R: [[], [], [], [], [], [], [], []]
	F: [[], [], [], [], [], [], [], []]
}
students = []

# request.get('https://docs.google.com/spreadsheet/pub?key=0Aqmu56ahZ_JbdHpQYkpUamkyOEFvZWZiNGdWYWNnbUE&output=csv', (error, response, body)->
# 	fs.writeFile('./grid9.csv', body, (err)->
# 		console.log err if err
# 	)
# )

load_data = (callback)->
	grades = [9, 10, 'GEN']
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
					classes[class_[0]+'-'+grade] = new Class class_[0]+'-'+grade, class_[1], class_[2], class_[3].toUpperCase(), class_[4].toUpperCase(), class_[5], class_[6], grade
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

printable_schedule = new Table(
	head: ['Period', 'M', 'T', 'W', 'R', 'F']
)

print_schedule = ->
	_.times(9, (i)->
		printable_schedule.push([i, schedule.M[i], schedule.T[i], schedule.W[i], schedule.R[i], schedule.F[i]])
	)
	console.log printable_schedule.toString()

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

generate_students = (grade)->
	switch grade
		when 9
			number = 160
		when 10
			number = 180
		when 'COL'
			number = 150
		else
			number = 0
		
	_.times(number, (i)->
		new_student = {
			id: i+'-'+grade
			grade: grade
			history: ''
			english: ''
			math: ''
			science: ''
			lab: ''
			language: ''
			gym: ''
			art: ''
			section: 0
			schedule: {
				M: ['', '', '', '', '', '', '', ''] # DAY: period[classess[]]
				T: ['', '', '', '', '', '', '', '']
				W: ['', '', '', '', '', '', '', '']
				R: ['', '', '', '', '', '', '', '']
				F: ['', '', '', '', '', '', '', '']
			}
		}
		students.push(new_student)
	)

populate_schedule_with_students = ->
	
	fill_class = (requirement, filter) ->	
		# place students in history class
		for student in students
			available_classes = _.filter(classes, (class_, name) -> return filter(class_, student, name))
			available_classes = _.filter(available_classes, (class_, name) -> return class_.check_enrollment_possible())
			
			if student.section is 0 and student.grade is 9
				student.section = _.shuffle([[2,5], [1,4,7], [3,6], [2,5], [3,6], [1,4,7], [1,4,7]])[0]
			if student.section is 0 and student.grade is 10
				student.section = _.shuffle([[1,2,7], [3,4,8], [5,6], [1,2,7], [1,2,7], [3,4,8], [3,4,8], [5,6]])[0]
			
			# go thru available classes to join, if it's possible to join, join
			for class_, i in available_classes
				class_code = class_.shorthand.split('-')[0]
				class_section = class_code.charAt(class_code.length-1)
				class_section = parseInt(class_section)
				if class_.check_enrollment_possible(student.id)[0] is true and student[requirement] is '' and _.contains(student.section, class_section)
					class_.enroll_student(student.id)
					student[requirement] += class_.shorthand
				else if i is available_classes.length - 1 and class_.check_enrollment_possible(student.id)[0] is false
					problems.push(['student error', 'Could not put student ' + student.id + ' in a ' + requirement + ' class'])
		
	fill_class('science', (class_, student, name) ->
		return class_.grade is student.grade and class_.code.search(/SCS21|SPS21/) is 0
	)
	
	fill_class('lab', (class_, student, name) ->
		return class_.grade is student.grade and class_.code.search(/SPS21QL|SCS21QL/) is 0 and student.science.split('-')[0].split('')[1] is class_.section
	)
	
	fill_class('math', (class_, student, name) ->
		return class_.grade is student.grade and class_.code.search(/MES21|MRS21/) is 0
	)
	
	fill_class('history', (class_, student, name) ->
		return class_.grade is student.grade and class_.code.search(/HGS21|HUS21/) is 0
	)
	
	fill_class('english', (class_, student, name) ->
		return class_.grade is student.grade and class_.code.search(/EES41|EES43/) is 0
	)
	
		
load_data(()->
	check_schedule()
	check_teachers()
	generate_students(9)
	generate_students(10)
	# print_schedule()
	populate_schedule_with_students()
	
	# if problems.length > 1
		# console.log problems.toString()
		
	# console.log JSON.stringify(schedule)
	
	for class_ in classes
		console.log 's'
)

debug = repl.start("SDB Debug> ")
debug.context.classes = classes
debug.context.students = students