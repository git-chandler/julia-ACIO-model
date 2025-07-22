#=
This code reads and processes data for constructing an ACIO model.
Data are from the BEA benchmark detail I-O tables.
=#

# set working directory
cd("/home/chandler/julia-ACIO-model/")
julia -project="."

#use_table_path = "/home/chandler/julia-ACIO-model/"

# import packages
import XLSX
#using DataFrames

# read detailed 2017 use table to a data frame
useTable = XLSX.readdata("IOUse_Before_Redefinitions_PRO_2017_Detail.xlsx", 
                         "2017",
                         "A6:PK414")

# drop intermediate total, final demand total, and final total columns
# drop intermediate total, value added total, and final total rows
useTable = useTable[1:end .∉[[404, 408, 409]],1:end .∉[[405, 426, 427]]]

# commodity and value added descriptions
comDesc = useTable[1:403, 1:2]
vaDesc = useTable[404:406,1:2]
useTable = useTable[1:end, 1:end .≠2]

# final demand table
fdTable = useTable[1:403, 1:end .∉[2:403]]

# value added table
vaTable = useTable[1:end .∉[2:403], 1:403]

# use table
useTable = useTable[1:403, 1:403]

# read detailed 2017 use table to a data frame
makeTable = XLSX.readdata("IOMake_Before_Redefinitions_2017_Detail.xlsx", 
                          "2017",
                          "A6:OO414")

# reading too many rows. drop missing rows and row and column totals.
makeTable = makeTable[1:403, 1:404]

# industry descriptions
indDesc = makeTable[1:end, 1:2]

# drop description column
makeTable = makeTable[1:end, 1:end .∉2]


