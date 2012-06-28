csv = require 'csv'
_ = require 'underscore'
Table = require 'cli-table'
repl = require 'repl'

class Class
	constructor: (@shorthand, @code, @sect, @title, @teacher, @room, @capacity, @grade) ->
		@enrollment = []

	check_enrollment_possible: (student_id, cap = true) ->
		if (@enrollment.length >= parseInt(@capacity)) and cap
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
			  
			for i, student_day of current_student.schedule
				for meeting in class_meets
					if meeting.split('-')[0] is i
						if student_day[meeting.split('-')[1]]
							possible = false
							#console.log meeting
							#console.log current_student.schedule
			
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

load_data = (callback)->
	grades = [9, 10, 'COL']
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
			teachers_next_next_period = []
			
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
			if schedule[day][index+2]
				for class_code in schedule[day][index+2]
					if classes[class_code]
						teachers_next_next_period.push(classes[class_code].teacher)
			# check if a teacher is teaching multiple classes in a given period
			_.each(teachers_this_period, (teacher, i, list)->
				current = list.shift()
				if _.include(list, current)
					message = 'Check day ' + day + ' and period '+ index + ', ' + current + ' is overbooked'
					problems.push(['teacher conflict', message])
			)
			# check if a teacher is teaching more than three periods in a row
			_.each(teachers_this_period, (teacher) ->
				if _.include(teachers_prev_period, teacher) and _.include(teachers_next_period, teacher) and _.include(teachers_next_next_period, teacher)
					prev = index-1 + ''
					next = index+1 + ''
					next_next = index+2 + ''
					message = 'Check day ' + day + ' and periods ' + prev + ', ' + index + ', ' + next + ', ' + next_next + ' ' + teacher + ' is scheduled 3 or more periods in a row'
					problems.push(['4+ periods for teacher', message])
			)

generate_students = (grade)->
	switch grade
		when 9
			number = 160
		when 10
			number = 180
		when 'COL'
			number = 290
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
		_.times(1, (time) ->
			for student, index in students
				if student.section is 0 and student.grade is 9
					student.section = ([[2,5], [1,4,7], [3,6], [2,5], [3,6], [1,4,7], [1,4,7]])[index%7]
				if student.section is 0 and student.grade is 10
					student.section = ([[1,2,7], [3,4,8], [5,6], [1,2,7], [1,2,7], [3,4,8], [3,4,8], [5,6]])[index%8]
				
				available_classes = []
				available_classes = _.filter(classes, (class_) -> return filter(class_, student))
				old_classes = available_classes
				available_classes = _.filter(available_classes, (class_, name) -> return class_.check_enrollment_possible(student.id)[0])
				preferred_classes = _.filter(available_classes, (class_, name) -> return parseInt(class_.sect) in student.section)
				# if student.id is '173-10' and requirement is 'lab'
					# console.log preferred_classes
				# for c in available_classes
					# if c.code is 'SCS21QL' and student.id is '173-10'
						# console.log parseInt(class_.sect), student.section
  
				
				# console.log available_classes if index is 5
				# console.log requirement if available_classes.length is 0
			
				
			
				if student[requirement] isnt ''
					break
				
				if available_classes.length isnt 0
					if preferred_classes.length isnt 0
						least_student_class = preferred_classes[0]
						for class_, i in preferred_classes
							if class_.enrollment.length < least_student_class.enrollment.length
								least_student_class = class_
								
					
					else 
						least_student_class = available_classes[0]
						for class_, i in available_classes
							if class_.enrollment.length < least_student_class.enrollment.length
								least_student_class = class_
				
					least_student_class.enroll_student(student.id)
					student[requirement] += least_student_class.shorthand

		)
	
	fill_class('lab', (class_, student) ->
		return class_.grade is student.grade and class_.code.search(/SPS21QL|SCS21QL/) is 0
	)
	
	fill_class('science', (class_, student) ->
		# console.log class_.shorthand if student.lab.split('-')[0].split('')[2] is undefined
		return class_.grade is student.grade and class_.code.search(/SCS21|SPS21/) is 0 and class_.code.search(/SPS21QL|SCS21QL/) isnt 0 and student.lab.split('-')[0].split('')[2] is class_.sect
	)
	
	fill_class('math', (class_, student) ->
		return class_.grade is student.grade and class_.code.search(/MES21|MRS21/) is 0
	)
	
	fill_class('history', (class_, student) ->
		return class_.grade is student.grade and class_.code.search(/HGS21|HUS21/) is 0
	)
	
	fill_class('english', (class_, student) ->
		return class_.grade is student.grade and class_.code.search(/EES41|EES43/) is 0
	)
	
	fill_class('language', (class_, student) ->
		return class_.grade is student.grade and class_.code.search(/FSS32|FLS32|FMS32|FSS31|FLS31|FMS31/) is 0
	)
	
	# fill_class('gym', (class_, student) ->
	   # return class_.grade is student.grade and class_.code.search(/PE/) is 0
	# )
	
for c in classes
	console.log c
	if c.code is 'SPS21QL'
		console.log c.enrollment
	

load_data(()->
	# check_schedule()
	check_teachers()
	generate_students(9)
	generate_students(10)
	generate_students('COL')
	# print_schedule()
	populate_schedule_with_students()

	if problems.length > 1
		console.log problems.toString()
		
	counter = 0
	for student in students
		if not student.lab or not student.science or not student.math or not student.history or not student.english or not student.language #or not student.gym
			counter++
			# console.log student
			
	
		
	# for i, class_ of classes
		# console.log class_.enrollment.length
		
	console.log counter
	
	# for i, class_ of classes
		# console.log class_.enrollment.length + ' ' + i if class_.code.search(/SPS21QL|SCS21QL/) is 0
			
	# console.log students
	
	# console.log JSON.stringify(schedule)
)

###
debug = repl.start("SDB Debug> ")
debug.context.classes = classes
debug.context.students = students
debug.context.schedule = schedule