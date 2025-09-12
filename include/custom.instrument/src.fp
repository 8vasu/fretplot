zoom 0.8
rotn -95

# Set fret and string counts
numfrt 5
numstr 8

# Set frets
# Fret 0 is the nut
frets 0 1 3 4 5

# Set strings
strings 1 2 3 4 5 6 7 8
# Remove a string
<strings 3

# Label frets
fl1 1
fl4 4
fl5 5

# Style the frets
fx1 dashed,line width=0.6,color=black
fx3 solid,line width=0.6,color=red

# Label strings
sl1 1
sl2 2
sl4 4
sl5 5
sl6 6
sl7 7
sl8 8

# Draw the frets over the strings
sovf False

# Add a note
notes <6,0>
nx<6,0> shape=circle,draw=red,text=white,fill=red,inner sep=1.5
nl<6,0> {\scriptsize A}
# I want this note to be drawn on fret 0 (nut)
onf0 True
