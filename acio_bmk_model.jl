


# import packages
import XLSX
using DataFrames
using LinearAlgebra

# read detailed 2017 make table
makeTable = XLSX.readtable("data/IOMake_Before_Redefinitions_2017_Detail.xlsx", 
                           "2017",
                           "A:OO";
                           first_row=6,
                           header=true)

# convert to data frame
makeDF = DataFrame(makeTable)

# change missing to 0. not ideal b.c BEA keeps true
# zeros blank. will revisit this another time.
makeDF = coalesce.(makeDF,0)

# drop missing rows and row and column totals.
makeDF = makeDF[1:402, 1:404]

# industry descriptions
indDesc = makeDF[1:end,1:2]

# drop description column
makeDF = makeDF[1:end, 1:end .∉2]

# read detailed 2017 use table to a data frame
useTable = XLSX.readtable("data/IOUse_Before_Redefinitions_PRO_2017_Detail.xlsx", 
                          "2017",
                          "A:PK";
                          first_row=6,
                          header=true)

# convert to data frame
useDF = DataFrame(useTable)

# convert missing to zero
useDF = coalesce.(useDF,0)

# drop intermediate total, final demand total, and final total columns
# drop intermediate total, value added total, and final total rows
useDF = useDF[1:end .∉[[403, 407, 408]],1:end .∉[[405, 426, 427]]]

# commodity and value added descriptions
comDesc = useDF[1:402,1:2]
vaDesc = useDF[403:405,1:2]
useDF = useDF[1:end, 1:end .∉2]

indComDesc = outerjoin(indDescDF,comDescDF,on=:Code)

# imports and final demand table
fdDF = useDF[1:402, 1:end .∉[2:403]]
impDF = fdDF[:,9]
fdDF = fdDF[:, 1:end .∉9]

# value added table
vaDF = useDF[403:405, 1:403]

# use table
useDF = useDF[1:402, 1:403]

# some data checks

# total commodity use by all markets
comuse = sum(Matrix{Int64}(useDF[:,2:end]), dims = 2) +
            sum(Matrix{Int64}(fdDF[:,2:end]), dims = 2)

# total commodity availability
comavail = sum(Matrix{Int64}(makeDF[:,2:end]), dims = 1) +
            -1*reshape(Vector{Int64}(impDF), (1,402))

# use equals availability
com_bal = comuse - comavail'
com_bal[abs.(com_bal) .> 10] # small differences

# total industry output
output = sum(Matrix{Int64}(makeDF[:,2:end]), dims = 2)

# total industry outlays
outlays = sum(Matrix{Int64}(useDF[:,2:end]), dims = 1) +
            sum(Matrix{Int64}(vaDF[:,2:end]), dims = 1)

# output equals outlays
ind_bal = output - outlays' 
ind_bal[abs.(ind_bal) .> 10] # small differences

# GDI + imports
gdiplusimp = sum(Matrix{Int64}(vaDF[:,2:end]), dims = 1) +
                -1*reshape(Vector{Int64}(impDF), (1,402))

# GDP + imports
gdpplusimp = sum(Matrix{Int64}(fdDF[:,2:end]), dims = 2)

# GDI + imports = GDP net of imports
gdp_bal = sum(gdiplusimp) - sum(gdpplusimp) # small difference

# form the submatrices and assemble the data. 

# A-by-A and C-by-C portions have all 0 entries
abya = zeros(402,402)
abya = hcat(indDesc[:,1], abya)
abya = DataFrame(abya, names(useDF))
cbyc = zeros(402,402)
cbyc = hcat(comDesc[:,1], cbyc)
cbyc = DataFrame(cbyc,names(makeDF))

# transactions matrix
T_left = vcat(abya, useDF)
T_right = vcat(makeDF[:,2:end], cbyc[:,2:end])
T_ = hcat(T_left, T_right) # duplicate variable names

# leakage vector
l_va = sum(Matrix{Int64}(vaDF[:, 2:end]), dims = 1)
l_ = hcat("L00", l_va, -1*reshape(Vector{Int64}(impDF), (1,402)))

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

