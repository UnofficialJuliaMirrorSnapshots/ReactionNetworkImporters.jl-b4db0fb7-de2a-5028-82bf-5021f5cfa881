# load a BioNetGen defined BCR network, solve the ODEs
# plot a specific observable and compare to the BioNetGen solution

using DiffEqBase, DiffEqBiological, Plots, OrdinaryDiffEq, Sundials, DataFrames, CSVFiles, LinearAlgebra
using ReactionNetworkImporters
using TimerOutputs

# parameters
doplot = true
networkname = "testbcrbng"
tf = 10000.

# BNG simulation data
datadir  = joinpath(@__DIR__,"../data/bcr")
fname    = joinpath(datadir, "bcr.net")
gdatfile = joinpath(datadir, "bcr.gdat")
print("getting gdat file...")
gdatdf = DataFrame(load(File(format"CSV", gdatfile), header_exists=true, spacedelim=true) )
println("done")

# we'll time the DiffEq solvers 
const to = TimerOutput()
reset_timer!(to)

# BioNetGen network
@timeit to "bionetgen" prnbng = loadrxnetwork(BNGNetwork(),string(networkname,"bng"), fname); 
rnbng = prnbng.rn; u0 = prnbng.u₀; p = prnbng.p; 
@timeit to "baddodes" addodes!(rnbng; build_jac=false, build_symfuncs=false)
@timeit to "bODEProb" boprob = ODEProblem(rnbng, u0, (0.,tf), p)
show(to)

# BNG simulation results for Activated Syk
asykgroups = prnbng.groupstoids[:Activated_Syk]
asyksyms = findall(x -> x ∈ asykgroups, rnbng.syms_to_ints)
# asynbng = zeros(length(gdatdf[:time]))
# for sym in asyksyms
#     global asynbng
#     asynbng += gdatdf[sym]
# end

# DiffEq solver 
reset_timer!(to); @timeit to "BNG_CVODE_BDF" begin bsol = solve(boprob, CVODE_BDF(),dense=false, saveat=1., abstol=1e-8, reltol=1e-8); end; show(to)
# #reset_timer!(to); @timeit to "BNG_RODAS5_BDF" begin bsol2 = solve(boprob, rodas5(autodiff=false),dense=false, saveat=1., abstol=1e-8, reltol=1e-8); end; show(to)

# Activated Syk from DiffEq
basyk = sum(bsol[asykgroups,:], dims=1)

if doplot
    plotlyjs()
    plot(gdatdf[:time][2:end], gdatdf[:Activated_Syk][2:end], xscale=:log10, label=:AsykGroup, linestyle=:dot)
#     # plot!(cdatdf[:time][2:end], asynbng[2:end], xscale=:log10, label=:AsykSum)
    plot!(bsol.t[2:end], basyk'[2:end], label=:AsykDEBio, xscale=:log10)
end

# test the error, note may be large in abs value though small relatively
# #norm(gdatdf[:Activated_Syk] - asynbng, Inf)
# #norm(asynbng - basyk', Inf)
norm(gdatdf[:Activated_Syk] - basyk', Inf)

# #@assert all(abs.(gdatdf[:Activated_Syk] - asynbng) .< 1e-6 * abs.(gdatdf[:Activated_Syk]))