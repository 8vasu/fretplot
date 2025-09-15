# Set a Boolean parameter.
onf0 False
# Negate a Boolean parameter.
flip onf0

# Perform some arithmetic operations on numerical parameters.
+rotn 90
/rotn 2
-rotn 45
%numstr 4

# Setting styles of some frets.
fx0 solid,line width=1.2,color=black
fx1 solid,line width=0.6,color=brown
# Setting labels of some frets.
fl3 3
fl5 5

# Setting styles of some strings.
sx1 solid,line width=0.5,color=black
# Setting labels of some strings.
sl1 {\scriptsize e}

# List of notes to be drawn.
notes <6,5> <3,6> <4,7> <5,7> <2,5> <1,5>
# Style a note.
nx<6,5> shape=circle,draw=red,text=white,fill=red,inner sep=1.5
# Label a note.
nl<6,5> {\scriptsize A}
# Change style of the note.
nx<6,5> shape=rectangle,draw=red,text=blue,fill=white,fill opacity=0.5,inner sep=1.0
# Relabel the note.
nl<6,5> 1
# Add some notes.
>notes <1,0> <1,1>
# Remove some notes.
<notes <5,5> <1,5> <2,2>
# Add more to existing style of a note.
&nx<2,5> draw=red,shape=circle
