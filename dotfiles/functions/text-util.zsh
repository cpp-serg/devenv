# cuts off the end of the line to fit the screwwwe0
alias wide0='cut -c-$((${COLUMNS}))'
# 23 is the length of the ascii color  enable/disable sequences in pgw/sgw logs
alias wide='cut -c-$((${COLUMNS}+23))'
