import re,os

studyGuide = open('studyguide.txt','r')
if not os.path.exists('flashcards'):
    os.makedirs('flashcards')

strStudyGuide = ""
cardCategorys = []
#   Get past the intro
for line in studyGuide:
    strStudyGuide += line

#print strStudyGuide

for cat in re.findall('.*Questions [0-9]{4}',strStudyGuide):
        cardCategorys.append(re.sub('\s','_',cat)+'.csv')

#print cardCategorys
strStudyGuide = re.sub('[0-9]{4}\sNextGen.*?$','',strStudyGuide,0,re.MULTILINE)

strStudyGuideNoAnswers = re.sub('(^\s?Answer:?.*?^[A-Za-z]{1}.*?){1}.*?(?=(^[0-9]+\.\s))','Answer:\n',strStudyGuide,0,re.DOTALL|re.MULTILINE)
questions = []
print "Getting Questions"
for quest in re.findall('^[0-9]+\.\s.*?(?=Answer:)',strStudyGuideNoAnswers,re.DOTALL|re.MULTILINE):
    fixedQuestion = re.sub('\x93','&quot;',quest)
    fixedQuestion = re.sub('\x94','&quot;',fixedQuestion)
    fixedQuestion = re.sub('\"','&quot;',fixedQuestion)
    questions.append(fixedQuestion)

answers = []
print "Getting Answers"
for answer in re.findall('^\s?Answer:?.*?^[A-Za-z].*?(?=^[0-9]+\.\s|\Z)',strStudyGuide,re.DOTALL|re.MULTILINE):
    fixedAnswer = re.sub('\x95','&diams;',answer)
    fixedAnswer = re.sub('\x93','&quot;',fixedAnswer)
    fixedAnswer = re.sub('\x94','&quot;',fixedAnswer)
    fixedAnswer = re.sub('\"','&quot;',fixedAnswer)
    answers.append(fixedAnswer)

"""
print cardCategorys[0]
print questions[0]
print answers[0]
for quest in questions:
    print quest[:20]"""

print "Writing Files"
prevQuestNum = 0
curCategory = 0
categoryFile = open("flashcards/"+cardCategorys[0],'w')
for question,answer in zip(questions,answers):
    questnum = re.match('^[0-9]+\.',question).group(0)
    #print question[:20]
    curQuestNum = int(re.findall('^[0-9]+',question)[0])
    #print curQuestNum
    if curQuestNum < prevQuestNum:
        #print prevQuestNum,curQuestNum
        categoryFile.close()
        curCategory += 1
        categoryFile = open("flashcards/"+cardCategorys[curCategory],'w')
    categoryFile.write("\"<p align=\"left\">"+re.sub('\n','<br /> ',question)+"</p>\"")
    categoryFile.write(",")
    categoryFile.write("\"<p align=\"left\">"+re.sub('\n','<br /> ',answer)+"</p>\"")
    categoryFile.write("\n")
    prevQuestNum = curQuestNum

categoryFile.close()

if len(questions) == len(answers):
    print "The operation completed successfully"
else:
    print "There was an error in generating the flash cards"

raw_input("Please press enter to continue...")
