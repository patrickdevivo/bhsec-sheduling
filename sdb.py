import re,random

qpat = re.compile(r'"?([^"]+)"?')

# for x in dir(qpat):
#     if '_' not in x:
#         print x
grade = 9
file = 'grid%s.csv' % (grade)
fin = open (file,'r')

#raw grid

rg = []

for x in fin.readline().split(','):
    # print x
    # print qpat.match(x).groups()[0]
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
lkup9 = {}

l = fin.readline().strip()

while l:
    l = l.split(',')
    if l[0] and l[0] != '"CLASS"':
        # print l
        # c = qpat.match()
        l = [qpat.match(i).groups()[0] for i in l if qpat.match(i)]
        #course code, section number is the key for classes
        cl = (l[1],int(l[2]))
		lkup[l[0]] = cl
        # print l
        classes[cl] = {"name":l[3].upper(),"teacher":l[4],"capacity":int(l[5]),"roster":[],"meets":[]}
        
    l = fin.readline().strip()

fin.close()

for p, ds in grid.items():
    for d, c in ds.items():
        for x in c:
            if x in lkup:
                classes[lkup[x]]["meets"].append((d,p))
                
#for debugging
r = random.choice(lkup.keys())
#print lkup[r],classes[lkup[r]]


def check_teachers(db=classes):
    teachTime = {}
    gr = {}
    for c in db.values():
        for m in c["meets"]:
            if m in teachTime.get(c["teacher"],{}):
                print "Teacher conflict, %s: %s per %s day %s" % (c["teacher"], c, m[0], m[1])
        gr[tuple(c["meets"])] = c["name"]
        teachTime[c["teacher"]] = c["meets"]
    prevDay = ''
    prevPeriod = 9
    classesInRow = 0
    for teacher in teachTime.values():
        teacher.sort()
        for day, period in teacher:
            if day != prevDay:
                prevDay = day
                classesInRow = 0
                prevPeriod = 9
            else:
                if period == prevPeriod + 1:
                    classesInRow += 1
            if classesInRow == 3:
                print "Flagging 3 classes in a row"
            if classesInRow == 4:
                print "4 classes in a row"
            prevPeriod = period
                    
            

def check_stud(cl,db=classes):
    gr = {}
    times = []
    for c in cl:
        for m in db[c]["meets"]:
            if m in times: 
                print "Conflict: %s per %s day %s" % (c,d,p)
                return False
            else:
                times.append(m)
                gr[tuple(db[c]["meets"])] = c
    return gr

def print_sched(gr,db=classes):
    """docstring for print_sched"""
    for p in range(8):
        print p, "\t",
        for d in "MTWRF":
            print gr.get((d,p),"\t"),
            print "\t",
        print

students = {}
for x in xrange(170):
    students[x] = []
    if grade is 10:
        gp = random.choice([(1,2,7),(3,4,8),(1,2,7),(3,4,8),(1,2,7),(3,4,8),(5,6),(5,6)])
        chem = random.choice(gp)
        c = lkup["CL"+str(chem)]
    if grade is 9:
        gp = random.choice([(1,3,5),(2,4,6),(1,3,5),(2,4,6),(1,3,5),(2,4,6),(5,6),(5,6)])
		c = lkup[""]
    #note two things happen when you add a class
    breakcount = 0
    while classes[c]["capacity"] < len(classes[c]["roster"]):
        breakcount += 1
        chem = random.choice(gp)
        c = lkup["C"+str(chem)]
        if breakcount > 8:
            break
    students[x].append(c)
    classes[c]["roster"].append(x)
    c = lkup["CL"+str(chem)]
    students[x].append(c)
    classes[c]["roster"].append(x)
    
    breakcount = 0

    for cl in ("M","E","H"):
        code = random.choice(gp)
        c = lkup[cl+str(code)]
        while classes[c]["capacity"] < len(classes[c]["roster"]):
            breakcount += 1
            code = random.choice(gp)
            c = lkup[cl+str(code)]
            if breakcount > 100:
                break
        students[x].append(c)
        classes[c]["roster"].append(x)
        breakcount = 0
    code = random.choice(gp)
    for l in "SLM":
        if "F" + l + str(code) in lkup:
            c = lkup["F" + l + str(code)]
            students[x].append(c)
            classes[c]["roster"].append(x)
            
for s in random.sample(range(170),3):
    # print s
    # print students[s]
    m=check_stud(students[s])
    # print m
    # if m:
        # print_sched(m)

check_teachers()
        
for c in classes:
    # print c
    classes[c]["roster"].sort()
    if len(classes[c]["roster"]) > int(classes[c]["capacity"]):
        print "Overbooked by %s" % str(len(classes[c]["roster"])-classes[c]["capacity"]), c, classes[c]
    elif len(classes[c]["roster"]) < 5:
        print "Underbooked at %s" % str(len(classes[c]["roster"])), c, classes[c]
    # if 1 == c[1]:
        # print c, ' '.join([str(x) for x in classes[c]["roster"]])    