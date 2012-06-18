import re,random

def check_stud(cl,classes):
	gr = {}
	for c in cl:
		for p in db[c]["period"]:
			for d in [x for x in db[c]["days"] if x != '-']:
				if (d,int(p)) in gr:
					print "Conflict: %s per %s day %s" % (c,d,p)
					return False
				else:
					gr[(d,int(p))] = c
	return gr

def print_sched(gr,classes):
	"""docstring for print_sched"""
	for p in range(8):
		print p, "\t",
		for d in "MTWRF":
			print gr.get((d,p),"\t"),
			print "\t",
		print

if __name__=="__main__":
	qpat = re.compile(r'"?([^"]+)"?')

	# for x in dir(qpat):
	#	  if '_' not in x:
	#		  print x

	fin = open ("grid10.csv",'r')

	#raw grid

	rg = []

	for x in fin.readline().split(','):
		# print x
		#print qpat.match(x).groups()[0]
		pass

	for x in range(7):
		rg.append(fin.readline().split(','))

	grid = {}

	for i,v in enumerate(rg):
		grid[i+1] = {}
		for d,day in enumerate("MTWRF"):
			c = qpat.match(v[d+1])
			if c:
				grid[i+1][day] = set(c.groups()[0].split())

	#print grid

	classes = {}

	lkup = {}

	l = fin.readline().strip()

	while l:
		l = l.split(',')
		if l[0] and l[0] != '"CLASS"':
			# print l
			# c = qpat.match()
			l = [qpat.match(i).groups()[0] for i in l if qpat.match(i)]
			cl = (l[1],int(l[2]))
			lkup[l[0]] = cl
			meets = ''
			classes[cl] = {"name":l[3].upper(),"teacher":l[4],"capacity":int(l[5]),"roster":[], "period":'', "days": '-----'} # chang period/day to tuple meeting times
			
		l = fin.readline().strip()

	fin.close()

	for p, ds in grid.items():
		for d, c in ds.items():
			for x in c:
				if x in lkup:
					dd = classes[lkup[x]]["days"]
					dow = 'MTWRF'.index(d)
					classes[lkup[x]]["days"] = dd[:dow] + d + dd[dow+1:]
					if str(p) not in classes[lkup[x]]["period"]:
						classes[lkup[x]]["period"] += str(p)
				

	r = random.choice(lkup.keys())
	#print lkup[r],classes[lkup[r]]

	students = {}

	for x in xrange(170):
		students[x] = []
		gp = random.choice([(1,2,7),(3,4,8),(1,2,7),(3,4,8),(1,2,7),(3,4,8),(5,6),(5,6)])
		chem = random.choice(gp)
		c = lkup["C"+str(chem)]
		students[x].append(c)
		classes[c]["roster"].append(x)
		c = lkup["CL"+str(chem)]
		students[x].append(c)
		classes[c]["roster"].append(x)
		for cl in ("M","E","H"):
			code = random.choice(gp)
			print cl+str(code)
			c = lkup[cl+str(code)]
			students[x].append(c)
			classes[c]["roster"].append(x)
		code = random.choice(gp)
		for l in "SLM":
			if "F" + l + str(code) in lkup:
				c = lkup["F" + l + str(code)]
				students[x].append(c)
				classes[c]["roster"].append(x)
				

	#for s in random.sample(range(170),3):
		#print s
		#print students[s]
		#m=check_stud(students[s],classes)
		#print m
		#if m:
			#print_sched(m,classes)

	for c in classes:
		# print c
		classes[c]["roster"].sort()
		if len(classes[c]["roster"]) > int(classes[c]["capacity"]):
			print "Overbooked", c, classes[c]
		if 1 == c[1]:
			print c, ' '.join([str(x) for x in classes[c]["roster"]])	 