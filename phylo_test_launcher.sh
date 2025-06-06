#!/bin/bash

# Phylogenetic Software Test Suite Launcher
# Tests both IQ-TREE and BEAST2 using existing BEAST example datasets

echo "========================================"
echo "  Phylogenetic Software Test Suite"
echo "========================================"
echo "This script will test IQ-TREE and BEAST2"
echo "using example datasets from BEAST installation"
echo ""

# Set up application paths before checking software
echo "Setting up application paths..."
export PATH="/opt/sw/pub/apps:$PATH"
export PATH="/opt/sw/pub/apps/beast.v2.7.5/bin:$PATH"
echo "✓ Added /opt/sw/pub/apps to PATH"
echo "✓ Added /opt/sw/pub/apps/beast.v2.7.5/bin to PATH"
echo ""

# Function to check if command exists
check_software() {
    if command -v "$1" &> /dev/null; then
        echo "✓ $1 found at: $(which $1)"
        return 0
    else
        echo "✗ $1 not found"
        return 1
    fi
}

# Function to check if file exists and is executable
check_executable() {
    if [[ -x "$1" ]]; then
        echo "✓ $2 executable found at: $1"
        return 0
    else
        echo "✗ $2 executable not found at: $1"
        return 1
    fi
}

# Function to ask yes/no questions
ask_yes_no() {
    while true; do
        read -p "$1 (y/n): " yn
        case $yn in
            [Yy]* ) return 0;;
            [Nn]* ) return 1;;
            * ) echo "Please answer yes (y) or no (n).";;
        esac
    done
}

# Check available software
echo "Checking available phylogenetic software:"
iqtree_available=false
beast_available=false

# Check IQ-TREE
echo "Checking IQ-TREE..."
if check_software "iqtree"; then
    iqtree_available=true
elif check_software "iqtree2"; then
    iqtree_available=true
elif check_executable "/opt/sw/pub/apps/iqtree" "IQ-TREE"; then
    iqtree_available=true
elif check_executable "/opt/sw/pub/apps/iqtree2.3.5" "IQ-TREE2.3.5"; then
    iqtree_available=true
fi

# Check BEAST2
echo "Checking BEAST2..."
if check_software "beast"; then
    beast_available=true
elif check_software "beast2"; then
    beast_available=true
elif check_executable "/opt/sw/pub/apps/beast.v2.7.5/bin/beast" "BEAST2"; then
    beast_available=true
fi

echo ""

# Check BEAST example data
BEAST_DATA_PATH="/opt/sw/pub/apps/beast.v2.7.5/examples/nexus"
BEAST_XML_PATH="/opt/sw/pub/apps/beast.v2.7.5/examples"

echo "Checking BEAST example files:"
if [[ -d "$BEAST_DATA_PATH" ]]; then
    dataset_count=$(ls $BEAST_DATA_PATH/*.nex 2>/dev/null | wc -l)
    echo "✓ NEXUS datasets: $dataset_count files"
else
    echo "✗ NEXUS datasets not found at: $BEAST_DATA_PATH"
fi

if [[ -d "$BEAST_XML_PATH" ]]; then
    xml_count=$(ls $BEAST_XML_PATH/*.xml 2>/dev/null | wc -l)
    echo "✓ XML examples: $xml_count files"
else
    echo "✗ XML examples not found at: $BEAST_XML_PATH"
fi

echo ""

# Check SLURM availability
if command -v sbatch &> /dev/null; then
    echo "✓ SLURM job scheduler detected"
    scheduler="slurm"
else
    echo "! SLURM not detected - will run tests directly"
    scheduler="direct"
fi

echo ""
echo "========================================"

# Test selection menu
if [[ "$iqtree_available" == true ]] && [[ "$beast_available" == true ]]; then
    echo "Both IQ-TREE and BEAST2 are available."
    echo ""
    echo "Test options:"
    echo "1) Test IQ-TREE only"
    echo "2) Test BEAST2 only" 
    echo "3) Test both (recommended)"
    echo "4) Exit"
    echo ""
    read -p "Select option (1-4): " choice
elif [[ "$iqtree_available" == true ]]; then
    echo "Only IQ-TREE is available."
    if ask_yes_no "Run IQ-TREE test?"; then
        choice=1
    else
        choice=4
    fi
elif [[ "$beast_available" == true ]]; then
    echo "Only BEAST2 is available."
    if ask_yes_no "Run BEAST2 test?"; then
        choice=2
    else
        choice=4
    fi
else
    echo "Neither IQ-TREE nor BEAST2 found. Please install phylogenetic software first."
    exit 1
fi

case $choice in
    1)
        echo "Running IQ-TREE test..."
        if [[ "$scheduler" == "slurm" ]]; then
            echo "Submitting IQ-TREE job to SLURM..."
            job_id=$(sbatch --parsable iqtree_test.sh)
            echo "Job submitted with ID: $job_id"
            echo "Monitor with: squeue -j $job_id"
            echo "View output with: tail -f iqtree_test_${job_id}.out"
        else
            echo "Running IQ-TREE test directly..."
            bash iqtree_test.sh
        fi
        ;;
    2)
        echo "Running BEAST2 test..."
        if [[ "$scheduler" == "slurm" ]]; then
            echo "Submitting BEAST2 job to SLURM..."
            job_id=$(sbatch --parsable beast_test.sh)
            echo "Job submitted with ID: $job_id"
            echo "Monitor with: squeue -j $job_id"
            echo "View output with: tail -f beast_test_${job_id}.out"
        else
            echo "Running BEAST2 test directly..."
            bash beast_test.sh
        fi
        ;;
    3)
        echo "Running both IQ-TREE and BEAST2 tests..."
        if [[ "$scheduler" == "slurm" ]]; then
            echo "Submitting IQ-TREE job..."
            iqtree_job=$(sbatch --parsable iqtree_test.sh)
            echo "IQ-TREE job ID: $iqtree_job"
            
            echo "Submitting BEAST2 job..."
            beast_job=$(sbatch --parsable beast_test.sh)
            echo "BEAST2 job ID: $beast_job"
            
            echo ""
            echo "Both jobs submitted!"
            echo "Monitor IQ-TREE: squeue -j $iqtree_job"
            echo "Monitor BEAST2: squeue -j $beast_job"
            echo ""
            echo "View outputs:"
            echo "  tail -f iqtree_test_${iqtree_job}.out"
            echo "  tail -f beast_test_${beast_job}.out"
        else
            echo "Running IQ-TREE test..."
            bash iqtree_test.sh
            echo ""
            echo "Running BEAST2 test..."
            bash beast_test.sh
        fi
        ;;
    4)
        echo "Exiting..."
        exit 0
        ;;
    *)
        echo "Invalid choice. Exiting..."
        exit 1
        ;;
esac

echo ""
echo "========================================"
echo "Test execution initiated!"
echo ""

if [[ "$scheduler" == "slurm" ]]; then
    echo "Jobs have been submitted to the SLURM scheduler."
    echo "Use the commands above to monitor progress."
    echo ""
    echo "Tip: Create an alias for easy monitoring:"
    echo "  alias checkjobs='squeue -u \$(whoami)'"
else
    echo "Tests completed. Check the output above for results."
fi

echo ""
echo "Expected test results:"
echo "- IQ-TREE: Multiple tree files (.treefile) and log files (.iqtree)"
echo "- BEAST2: Log files (.log) and tree files (.trees)"
echo ""
echo "If tests fail, check:"
echo "1. Software installation and PATH"
echo "2. Module loading requirements"
echo "3. File permissions and disk space"
echo "4. BEAST example file locations"
echo ""
echo "========================================"
