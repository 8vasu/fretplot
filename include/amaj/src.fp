# Set diagram rotation angle.
rotn -90
# Set this to True to decrease space
# between fret 0 and the string labels.
onf0 True

# We do not want all frets for this chord diagram.
numfrt 3
frets 0 1 2 3

# Label the frets appropriately.
fl1 5
fl3 7
# Label the strings.
sl1 {\small e}
sl2 {\small B}
sl3 {\small G}
sl4 {\small D}
sl5 {\small A}
sl6 {\small E}

# A major triad barre chord.
## Specify the barre.
barres <1-6,1>
bx<1-6,1> fill=black, draw=black
## Specify the notes.
notes <6,1> <3,2> <4,3> <5,3> <2,1> <1,1>
## Set note styles and lables.
nx<6,1> shape=circle,draw=red,text=white,fill=red,inner sep=1.5
nl<6,1> {\scriptsize A}
##
nx<5,3> shape=circle,draw=red,text=blue,fill=white,inner sep=1.7
nl<5,3> {\scriptsize E}
##
nx<4,3> shape=circle,draw=red,text=white,fill=red,inner sep=1.5
nl<4,3> {\scriptsize A}
##
nx<3,2> shape=circle,draw=red,text=blue,fill=white,inner sep=0.3
nl<3,2> {\scriptsize C$\sharp$}
##
nx<2,1> shape=circle,draw=red,text=blue,fill=white,inner sep=1.7
nl<2,1> {\scriptsize E}
##
nx<1,1> shape=circle,draw=red,text=white,fill=red,inner sep=1.5
nl<1,1> {\scriptsize A}
