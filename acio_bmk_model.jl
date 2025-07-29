

# import packages
import XLSX
using DataFrames
using LinearAlgebra

# read detailed 2017 make table
makeTable = XLSX.readdata("data/IOMake_Before_Redefinitions_2017_Detail.xlsx", 
                          "2017",
                          "A6:OO414")

# change missing to 0. not ideal b.c BEA keeps true
# zeroes blank. will revisit this another time.
makeTable = coalesce.(makeTable,0)

# reading too many rows. drop missing rows and row and column totals.
makeTable = makeTable[1:403, 1:404]

# industry descriptions
indDesc = makeTable[1:end, 1:2]

# drop description column
makeTable = makeTable[1:end, 1:end .∉2]

nind = size(makeTable)[1]-1 # number of industries
ncom = size(makeTable)[2]-1 # number of commodities

# read detailed 2017 use table to a data frame
useTable = XLSX.readdata("data/IOUse_Before_Redefinitions_PRO_2017_Detail.xlsx", 
                         "2017",
                         "A6:PK414")

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

imports0 = fdTable[:,9]

# value added table
vaTable = useTable[1:end .∉[2:403], 1:403]

# use table
useTable = useTable[1:403, 1:403]

# some data checks

# total commodity use by all markets
comuse = sum(useTable[2:end,2:end], dims = 2) +
            sum(fdTable[2:end,2:end], dims = 2)

# total commodity availability
comavail = sum(makeTable[2:end,2:end], dims = 1) +
            reshape(imports[2:end,:], (1,ncom))

# use equals availability
com_bal = comuse - comavail'
com_bal[abs.(com_bal) .> 10] # small differences

# total industry output
output = sum(makeTable[2:end,2:end], dims = 2)

# total industry outlays
outlays = sum(useTable[2:end,2:end], dims = 1) +
            sum(vaTable[2:end,2:end], dims = 1)

# output equals outlays
ind_bal = output - outlays' 
ind_bal[abs.(ind_bal) .> 10] # small differences

# GDI + imports
gdiplusimp = sum(vaTable[2:end,2:end], dims = 1) +
                reshape(imports[2:end,:], (1,ncom))

# GDP + imports
gdpplusimp = sum(fdTable[2:end,2:end], dims = 2)

# GDI + imports = GDP net of imports
gdp_bal = sum(gdiplusimp) - sum(gdpplusimp) # small difference

# form the submatrices and assemble the data. 

# A-by-A and C-by-C portions have all 0 entries
abya = zeros(nind, nind)
abya = hcat(indDesc[2:end,1], abya)
abya = vcat(reshape(useTable[1,:], (1, 403)), abya)
cbyc = zeros(ncom, ncom)
cbyc = hcat(comDesc[2:end,1], cbyc)
cbyc = vcat(reshape(makeTable[1,:], (1,403)), cbyc)

# transactions matrix
T_left = vcat(abya, useTable[2:end,:])
T_right = vcat(makeTable[:,2:end], cbyc[2:end,2:end])
T_ = hcat(T_left, T_right)

# leakage vector
l_va = sum(vaTable[2:end, 2:end], dims = 1)
l_ = hcat("L00", l_va, reshape(imports[2:end,:], (1,nind)))

# injection vector
x_ = sum(fdTable[2:end,2:end], dims = 2)
x_ = vcat(zeros(nind,1), x_, 0)
x_ = vcat("X00", x_)

# assemble the whole matrix
acio = vcat(T_, l_)
acio = hcat(acio, x_)

# account balance tests
row_s = sum(acio[2:805,2:end], dims = 2)
col_s = sum(acio[2:end,2:805], dims = 1)
acct_bal = row_s-col_s' 
acct_bal[abs.(acct_bal) .> 10] # small differences

# build the model
# note that i have to specify Matrix{Float64} for the data 
# portion of T_. because the row and column names are strings
# in T_, it's considered Matrix{Any}.

# gross output vector (lower case y_)
y_ = sum(acio[2:805,2:end], dims = 2) 

# inverse diagonal matrix of gross output (capital Y_)
Y_ = inv(diagm(vec(y_.+eps(Float64))))

# direct requirements multiplier matrix
A_ = Matrix{Float64}(T_[2:end,2:end])*Y_

# total requirements multiplier matrix
M_ = inv(Matrix{Int64}(I,804,804)-(A_))

# value added and imports multiplier vector
v_ = Y_ * Matrix{Float64}(l_[:,2:end])'

# test the model

# total requirements times final demand sums reproduces gross output
balM_ = M_*x_[2:805,:] - y_
balM_[abs.(balM_) .> 10] # doesn't balance

imbal = balM_[abs.(balM_) .> 10]
imbal_index = findall(x -> x == imbal[1], balM_)
indDesc[imbal_index[1][1]+1, :]

## 4200ID customs duties

useTable[1, imbal_index[1][1]+1]
y_[imbal_index[1][1]]
(M_*x_[2:805,:])[imbal_index[1][1]]

# gross output times value added reproduces GDI + imports
balv_ = y_'*v_ - ones( 1,(ncom+nind))*l_[:,2:end]'
balv_ 

# walras's law
balW = sum(v_'*M_*x_[2:805,:]) - sum(x_[2:805,:])
balW # small difference

