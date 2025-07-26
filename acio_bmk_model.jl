
# set working directory
cd("/home/chandler/julia-ACIO-model/")

# import packages
import XLSX
using DataFrames
using LinearAlgebra

# read detailed 2017 use table to a data frame
useTable = XLSX.readdata("data/IOUse_Before_Redefinitions_PRO_2017_Detail.xlsx", 
                         "2017",
                         "A6:PK414")

# change missing to 0. not ideal b.c BEA keeps true
# zeroes blank. will revisit this another time.
useTable = coalesce.(useTable,0)

# drop intermediate total, final demand total, and final total columns
# drop intermediate total, value added total, and final total rows
useTable = useTable[1:end .∉[[404, 408, 409]],1:end .∉[[405, 426, 427]]]

# commodity and value added descriptions
comDesc = useTable[1:403, 1:2]
vaDesc = useTable[404:406,1:2]
useTable = useTable[1:end, 1:end .≠2]

# imports and final demand table
fdTable = useTable[1:403, 1:end .∉[2:403]]
imports = vcat(fdTable[1,9], -1*fdTable[2:end,9])
fdTable = fdTable[:, 1:end .∉9]

# value added table
vaTable = useTable[1:end .∉[2:403], 1:403]

# use table
useTable = useTable[1:403, 1:403]

# read detailed 2017 use table to a data frame
makeTable = XLSX.readdata("data/IOMake_Before_Redefinitions_2017_Detail.xlsx", 
                          "2017",
                          "A6:OO414")

makeTable = coalesce.(makeTable,0)

# reading too many rows. drop missing rows and row and column totals.
makeTable = makeTable[1:403, 1:404]

# industry descriptions
indDesc = makeTable[1:end, 1:2]

# drop description column
makeTable = makeTable[1:end, 1:end .∉2]

#=
form the submatrices and assemble the data. 
=#

# A-by-A and C-by-C portions have all 0 entries
abya = zeros(402, 402)
abya = hcat(indDesc[2:end,1], abya)
abya = vcat(reshape(useTable[1,:], (1, 403)), abya)
cbyc = zeros(402, 402)
cbyc = hcat(comDesc[2:end,1], cbyc)
cbyc = vcat(reshape(makeTable[1,:], (1,403)), cbyc)

# transactions matrix
T_left = vcat(abya, useTable[2:end,:])
T_right = vcat(makeTable[:,2:end], cbyc[2:end,2:end])
T_ = hcat(T_left, T_right)

# leakage matrix
L_va = hcat(vaTable[2:end, 2:end], zeros(3, 402))
L04 = hcat(zeros(1,402), reshape(imports[2:end,:], (1,402)))
L_ = vcat(L_va, L04)
L_ = hcat(["L01", "L02", "L03", "L04"], L_)

# injection matrix
abyx = zeros(402,19)
lbyx = zeros(4,19)
X_ = vcat(reshape(fdTable[1,2:end], (1,19)), abyx, fdTable[2:end,2:end], lbyx)

# assemble the whole matrix
acio = vcat(T_, L_)
acio = hcat(acio, X_)

# balance tests
row_s = sum(acio[2:805,2:end], dims = 2)
col_s = sum(acio[2:end,2:805], dims = 1)
bal = row_s-col_s'

# these are fine. some are on the order of 10^1. maybe a GRAS
# implementation in the future would resolve the differences.

# build the model
Y_ = sum(acio[2:805,2:end], dims = 2)
Y_inv = inv(diagm(vec(Y_.+eps(Float64))))
A_ = T_[2:end,2:end]*Y_inv
M_ = inv(Matrix{Int64}(I,804,804)-(A_))
