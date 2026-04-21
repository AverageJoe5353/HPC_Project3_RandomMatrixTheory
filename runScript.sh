#!/bin/bash

# Compile the program
echo "Compiling Eigenvalue Calculator..."
mpiifx -O3 main.f90 manager.f90 worker.f90 -o runEigen -qmkl
echo "Compilation Successful!"

N_PROCS=(2 4 8 16 32 64 128) # Number of processes to run with (number of workers will be N_PROCS - 1)
NDATS=(128 256 512 1024 2048 4096) # Number of eigenvalues to compute
NMATS=(500 750 1000 1250 1500 1750) # Size of the matrices

numRuns=$(( ${#NMATS[@]} * ${#NDATS[@]} * ${#N_PROCS[@]} )) # Total number of runs to execute (for progress tracking)
runCount=0 # Counter for completed runs

# Loop over different configurations
echo "Starting $numRuns runs..."
for N in "${NMATS[@]}"; do
    for NDAT in "${NDATS[@]}"; do
        for N_PROC in "${N_PROCS[@]}"; do
            echo "Running with N=$N, NDAT=$NDAT, N_PROCS=$N_PROC..."
            mpirun -np $N_PROC ./runEigen -N $N -D $NDAT

            echo "Done! ($((++runCount))/$numRuns)"
        done
    done
done
echo "All runs completed!"