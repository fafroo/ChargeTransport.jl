
#=
# PSC device with Beer-Lambert generation rate (1D).
([source code](SOURCE_URL))

Simulating a three layer PSC device SiO2| MAPI | SiO2 with mobile ions where the ion vacancy
accumulation is limited by the Fermi-Dirac integral of order -1. The simulations are performed
out of equilibrium, time-dependent and with abrupt interfaces. A linear I-V measurement
protocol is included and the corresponding solution vectors after the scan can be depicted.

The parameters can be found in Table S.13, https://arxiv.org/abs/2009.04384. Or here:
https://github.com/barnesgroupICL/Driftfusion/blob/Methods-IonMonger-Comparison/Input_files/IonMonger_default_bulk.csv
=#

module Ex108_PSC_BeerLambert_Generation

using VoronoiFVM
using ChargeTransport
using ExtendableGrids
using GridVisualize
using PyPlot

function main(;n = 2, Plotter = PyPlot, plotting = false, verbose = false, test = false)

    ################################################################################
    if test == false
        println("Set up grid and regions")
    end
    ################################################################################
    ## region numbers
    regionDonor     = 1                           # n doped region
    regionIntrinsic = 2                           # intrinsic region
    regionAcceptor  = 3                           # p doped region
    regions         = [regionDonor, regionIntrinsic, regionAcceptor]
    numberOfRegions = length(regions)

    ## boundary region numbers
    bregionDonor    = 1
    bregionAcceptor = 2

    ## grid
    h_ndoping       = 9.90e-6 * cm
    h_intrinsic     = 4.00e-5 * cm + 2.0e-7 * cm
    h_pdoping       = 1.99e-5 * cm
    heightLayers    = [h_ndoping,
                       h_ndoping + h_intrinsic,
                       h_ndoping + h_intrinsic + h_pdoping]

    x0              = 0.0 * cm
    δ               = 4*n        # the larger, the finer the mesh
    t               = 0.5*(cm)/δ # tolerance for geomspace and glue (with factor 10)
    k               = 1.5        # the closer to 1, the closer to the boundary geomspace

    coord_n_u       = collect(range(x0, h_ndoping/2, step=h_ndoping/(0.8*δ)))
    coord_n_g       = geomspace(h_ndoping/2,
                                h_ndoping,
                                h_ndoping/(0.7*δ),
                                h_ndoping/(1.1*δ),
                                tol=t)
    coord_i_g1      = geomspace(h_ndoping,
                                h_ndoping+h_intrinsic/k,
                                h_intrinsic/(2.8*δ),
                                h_intrinsic/(2.1*δ),
                                tol=t)
    coord_i_g2      = geomspace(h_ndoping+h_intrinsic/k,
                                h_ndoping+h_intrinsic,
                                h_intrinsic/(2.1*δ),
                                h_intrinsic/(2.8*δ),
                                tol=t)
    coord_p_g       = geomspace(h_ndoping+h_intrinsic,
                                h_ndoping+h_intrinsic+h_pdoping/2,
                                h_pdoping/(1.6*δ),
                                h_pdoping/(1.6*δ),
                                tol=t)
    coord_p_u       = collect(range(h_ndoping+h_intrinsic+h_pdoping/2, h_ndoping+h_intrinsic+h_pdoping, step=h_pdoping/(1.3*δ)))

    coord           = glue(coord_n_u, coord_n_g,  tol=10*t)
    coord           = glue(coord,     coord_i_g1, tol=10*t)
    coord           = glue(coord,     coord_i_g2, tol=10*t)
    coord           = glue(coord,     coord_p_g,  tol=10*t)
    coord           = glue(coord,     coord_p_u,  tol=10*t)
    grid            = ExtendableGrids.simplexgrid(coord)

    ## set different regions in grid, doping profiles do not intersect
    cellmask!(grid, [0.0 * μm],        [heightLayers[1]], regionDonor, tol = 1.0e-18)     # n-doped region   = 1
    cellmask!(grid, [heightLayers[1]], [heightLayers[2]], regionIntrinsic, tol = 1.0e-18) # intrinsic region = 2
    cellmask!(grid, [heightLayers[2]], [heightLayers[3]], regionAcceptor, tol = 1.0e-18)  # p-doped region   = 3

    if plotting
        gridplot(grid, Plotter = Plotter)
        Plotter.title("Grid")
        Plotter.figure()
    end

    if test == false
        println("*** done\n")
    end
    ################################################################################
    if test == false
        println("Define physical parameters and model")
    end
    ################################################################################

    ## set indices of the quasi Fermi potentials
    iphin              = 1 # electron quasi Fermi potential
    iphip              = 2 # hole quasi Fermi potential
    iphia              = 3 # anion vacancy quasi Fermi potential

    numberOfCarriers   = 3 # electrons, holes and anion vacancies

    ## temperature
    T                  = 298.0                 *  K

    ## band edge energies
    Ec_d               = -4.0                  *  eV
    Ev_d               = -5.8                  *  eV

    Ec_i               = -3.7                  *  eV
    Ev_i               = -5.4                  *  eV

    Ec_a               = -3.4                  *  eV
    Ev_a               = -5.1                  *  eV

    ## ############ adjust Na, Ea for anion vacancies here ###########
    Nanion             = 1.0e21                / (cm^3)
    Ea_i               = -4.45                 *  eV
    ## ############ adjust Na, Ea for anion vacancies here ###########

    EC                 = [Ec_d, Ec_i, Ec_a]
    EV                 = [Ev_d, Ev_i, Ev_a]
    EA                 = [0.0,  Ea_i,  0.0]

    ## effective densities of state
    Nc_d               = 5.0e19                / (cm^3)
    Nv_d               = 5.0e19                / (cm^3)

    Nc_i               = 8.1e18                / (cm^3)
    Nv_i               = 5.8e18                / (cm^3)

    Nc_a               = 5.0e19                / (cm^3)
    Nv_a               = 5.0e19                / (cm^3)

    NC                 = [Nc_d, Nc_i,  Nc_a]
    NV                 = [Nv_d, Nv_i,  Nv_a]
    NAnion             = [0.0,  Nanion, 0.0]

    ## mobilities
    μn_d             = 3.89                    * (cm^2) / (V * s)
    μp_d             = 3.89                    * (cm^2) / (V * s)

    μn_i             = 6.62e1                  * (cm^2) / (V * s)
    μp_i             = 6.62e1                  * (cm^2) / (V * s)

    μa_i             = 3.93e-12                * (cm^2) / (V * s)

    μn_a             = 3.89e-1                 * (cm^2) / (V * s)
    μp_a             = 3.89e-1                 * (cm^2) / (V * s)

    μn               = [μn_d, μn_i, μn_a]
    μp               = [μp_d, μp_i, μp_a]
    μa               = [0.0,  μa_i, 0.0 ]

    ## relative dielectric permittivity
    ε_d                = 10.0                  *  1.0
    ε_i                = 24.1                  *  1.0
    ε_a                = 3.0                   *  1.0

    ε                  = [ε_d, ε_i, ε_a]

    ## radiative recombination
    r0_d               = 0.0e0                 * cm^3 / s
    r0_i               = 0.0e0                 * cm^3 / s
    r0_a               = 0.0e0                 * cm^3 / s

    r0                 = [r0_d, r0_i, r0_a]

    ## life times and trap densities
    τn_d               = 1.0e100               * s
    τp_d               = 1.0e100               * s

    τn_i               = 3.0e-9                * s
    τp_i               = 3.0e-7                * s
    τn_a               = τn_d
    τp_a               = τp_d
    τn                 = [τn_d, τn_i, τn_a]
    τp                 = [τp_d, τp_i, τp_a]

    ## SRH trap energies
    Ei_d               = -5.0                  * eV
    Ei_i               = -4.55                 * eV
    Ei_a               = -4.1                  * eV

    EI                 = [Ei_d, Ei_i, Ei_a]

    ## Auger recombination
    Auger              = 0.0

    ## generation
    photonflux_i       = 1.4e21                / (m^2 * s)
    absorption_i       = 1.3e7                 / m
    incidentPhotonFlux = [0.0, photonflux_i, 0.0]
    absorption         = [0.0, absorption_i, 0.0]
    generationPeak     = h_ndoping

    ## doping
    Nd                 = 1.00e18               / (cm^3)
    Na                 = 1.00e18               / (cm^3)
    C0                 = 1.6e19                / (cm^3)

    ## contact voltage
    voltageAcceptor    = 1.2                   * V

    if test == false
        println("*** done\n")
    end
    ################################################################################
    if test == false
        println("Define System and fill in information about model")
    end
    ################################################################################

    ## Initialize Data instance and fill in predefined data
    data                               = Data(grid, numberOfCarriers)
    data.modelType                     = Transient
    data.F                             = [Boltzmann, Boltzmann, FermiDiracMinusOne]

    data.bulkRecombination             = set_bulk_recombination(;iphin = iphin, iphip = iphip,
                                                                 bulk_recomb_Auger = true,
                                                                 bulk_recomb_radiative = true,
                                                                 bulk_recomb_SRH = true)
    data.boundaryType[bregionAcceptor] = OhmicContact
    data.boundaryType[bregionDonor]    = OhmicContact
    data.generationModel               = GenerationBeerLambert
    data.enableIonicCarriers           = enable_ionic_carriers(ionic_carriers = [iphia], regions = [regionIntrinsic])
    data.fluxApproximation            .= ExcessChemicalPotential

    if test == false
        println("*** done\n")
    end

    ################################################################################
    if test == false
        println("Define Params and fill in physical parameters")
    end
    ################################################################################

    params                                              = Params(grid, numberOfCarriers)

    params.temperature                                  = T
    params.UT                                           = (kB * params.temperature) / q
    params.chargeNumbers[iphin]                         = -1
    params.chargeNumbers[iphip]                         =  1
    params.chargeNumbers[iphia]                         =  1

    for ireg in 1:numberOfRegions # interior region data

        params.dielectricConstant[ireg]                 = ε[ireg] * ε0

        ## effective DOS, band edge energy and mobilities
        params.densityOfStates[iphin, ireg]             = NC[ireg]
        params.densityOfStates[iphip, ireg]             = NV[ireg]
        params.densityOfStates[iphia, ireg]             = NAnion[ireg]

        params.bandEdgeEnergy[iphin, ireg]              = EC[ireg]
        params.bandEdgeEnergy[iphip, ireg]              = EV[ireg]
        params.bandEdgeEnergy[iphia, ireg]              = EA[ireg]

        params.mobility[iphin, ireg]                    = μn[ireg]
        params.mobility[iphip, ireg]                    = μp[ireg]
        params.mobility[iphia, ireg]                    = μa[ireg]

        ## recombination parameters
        params.recombinationRadiative[ireg]             = r0[ireg]
        params.recombinationSRHLifetime[iphin, ireg]    = τn[ireg]
        params.recombinationSRHLifetime[iphip, ireg]    = τp[ireg]
        params.recombinationSRHTrapDensity[iphin, ireg] = trap_density!(iphin, ireg, data, EI[ireg])
        params.recombinationSRHTrapDensity[iphip, ireg] = trap_density!(iphip, ireg, data, EI[ireg])
        params.recombinationAuger[iphin, ireg]          = Auger
        params.recombinationAuger[iphip, ireg]          = Auger

        ## generation parameters
        params.generationIncidentPhotonFlux[ireg]       = incidentPhotonFlux[ireg]
        params.generationAbsorption[ireg]               = absorption[ireg]
    end

    # parameter which passes the shift information in the Beer-Lambert generation
    params.generationPeak                               = generationPeak

    ## boundary region data
    params.bDensityOfStates[iphin, bregionDonor]        = Nc_d
    params.bDensityOfStates[iphip, bregionDonor]        = Nv_d

    params.bDensityOfStates[iphin, bregionAcceptor]     = Nc_a
    params.bDensityOfStates[iphip, bregionAcceptor]     = Nv_a

    params.bBandEdgeEnergy[iphin, bregionDonor]         = Ec_d
    params.bBandEdgeEnergy[iphip, bregionDonor]         = Ev_d

    params.bBandEdgeEnergy[iphin, bregionAcceptor]      = Ec_a
    params.bBandEdgeEnergy[iphip, bregionAcceptor]      = Ev_a

    ## interior doping
    params.doping[iphin, regionDonor]                   = Nd
    params.doping[iphia, regionIntrinsic]               = C0
    params.doping[iphip, regionAcceptor]                = Na

    ## boundary doping
    params.bDoping[iphip, bregionAcceptor]              = Na
    params.bDoping[iphin, bregionDonor]                 = Nd

    data.params                                         = params
    ctsys                                               = System(grid, data, unknown_storage=:sparse)

    if test == false
        println("*** done\n")
    end

    ################################################################################
    if test == false
        println("Define outer boundary conditions")
    end
    ################################################################################

    ## set zero voltage ohmic contacts for electrons and holes at all outer boundaries.
    set_contact!(ctsys, bregionAcceptor, Δu = 0.0)
    set_contact!(ctsys, bregionDonor,    Δu = 0.0)

    if test == false
        println("*** done\n")
    end
    ################################################################################
    if test == false
        println("Define control parameters for Newton solver")
    end
    ################################################################################

    control                   = NewtonControl()
    control.verbose           = verbose
    control.max_iterations    = 300
    control.tol_absolute      = 1.0e-10
    control.tol_relative      = 1.0e-10
    control.handle_exceptions = true
    control.tol_round         = 1.0e-10
    control.max_round         = 5
    control.damp_initial      = 0.5
    control.damp_growth       = 1.21 # >= 1

    if test == false
        println("*** done\n")
    end
    ################################################################################
    if test == false
        println("Compute solution in thermodynamic equilibrium")
    end
    ################################################################################

    ## initialize solution and starting vectors
    initialGuess  = unknowns(ctsys)
    solution      = unknowns(ctsys)

    solution      = equilibrium_solve!(ctsys, control = control, nonlinear_steps = 20)

    initialGuess .= solution

    if plotting
        label_solution, label_density, label_energy, label_BEE = set_plotting_labels(data)

        ## add labels for anion vacancy
        label_energy[1, iphia] = "\$E_a-q\\psi\$"; label_energy[2, iphia] = "\$ - q \\varphi_a\$"; label_BEE[iphia] = "\$E_a\$"
        label_density[iphia]   = "a";              label_solution[iphia]  = "\$ \\varphi_a\$"

        plot_energies(Plotter, grid, data, solution, "Equilibrium", label_energy)
        Plotter.figure()
        plot_densities(Plotter, grid, data, solution,"Equilibrium", label_density)
        Plotter.figure()
        plot_solution(Plotter, grid, data, solution, "Equilibrium", label_solution)
        Plotter.figure()
    end

    if test == false
        println("*** done\n")
    end

    ################################################################################
    if test == false
        println("Upward scan with increasing bias and generation")
    end
    ################################################################################

    data.calculationType = OutOfEquilibrium
    ## primary data for I-V scan protocol
    scanrate      = 1.0 * V/s
    number_tsteps = 21
    endVoltage    = voltageAcceptor # bias goes until the given voltage at acceptor boundary
    tend          = endVoltage/scanrate
    tvalues       = range(0, stop = tend, length = number_tsteps)

    # these values are needed for putting the generation slightly on
    I      = collect(length(tvalues):-1:0.0)
    LAMBDA = 10 .^ (-I)

    for istep = 2:number_tsteps

        ## turn slowly generation on
        data.λ2   = LAMBDA[istep + 1]

        t  = tvalues[istep]       # Actual time
        Δu = t * scanrate         # Applied voltage
        Δt = t - tvalues[istep-1] # Time step size

        set_contact!(ctsys, bregionAcceptor, Δu = Δu)

        if test == false
            println("increase generation with λ2 = $(data.λ2)")
            println("time value: t = $(t)")
        end

        solve!(solution, initialGuess, ctsys, control  = control, tstep = Δt)

        initialGuess .= solution

    end # time loop

    if plotting
        plot_energies(Plotter, grid, data, solution, "bias \$\\Delta u\$ = $(voltageAcceptor)", label_energy)
        Plotter.figure()
        plot_densities(Plotter, grid, data, solution,"bias \$\\Delta u\$ = $(voltageAcceptor)", label_density)
        Plotter.figure()
        plot_solution(Plotter, grid, data, solution, "bias \$\\Delta u\$ = $(voltageAcceptor)", label_solution)
    end

    if test == false
        println("*** done\n")
    end

    ################################################################################
    if test == false
        println("Reverse scan protocol")
    end
    ################################################################################
    ## for saving I-V data
    IV            = zeros(0) # for IV values
    biasValues    = zeros(0) # for bias values

    for istep = number_tsteps:-1:2

        t  = tvalues[istep]       # Actual time
        Δu = t * scanrate         # Applied voltage
        Δt = t - tvalues[istep-1] # Time step size

        set_contact!(ctsys, bregionAcceptor, Δu = Δu)

        if test == false
            println("applied voltage: Δu = $(Δu)")
        end

        solve!(solution, initialGuess, ctsys, control  = control, tstep = Δt)

        ## get I-V data
        current = get_current_val(ctsys, solution, initialGuess, Δt)

        push!(IV, current)
        push!(biasValues, Δu)

        initialGuess .= solution

    end # time loop


    if plotting
        Plotter.figure()
        plot_IV(Plotter, biasValues, -IV, "bias \$\\Delta u\$ = $(biasValues[end])", plotGridpoints = true)
    end

    if test == false
        println("*** done\n")
    end

    testval = sum(filter(!isnan, solution))/length(solution) # when using sparse storage, we get NaN values in solution
    return testval

    println("*** done\n")

end #  main

function test()
    testval = -1.0893186658197205
    main(test = true) ≈ testval
end

if test == false
    println("This message should show when this module is successfully recompiled.")
end

end # module
