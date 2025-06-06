#!/bin/bash
#SBATCH --job-name=iqtree_test
#SBATCH --output=iqtree_test_%j.out
#SBATCH --error=iqtree_test_%j.err
#SBATCH --time=01:00:00
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=4
#SBATCH --mem=4GB
#SBATCH --partition=testing

# IQ-TREE phylogenetic analysis test script
# Tests IQ-TREE installation using BEAST example datasets

echo "=== IQ-TREE Phylogenetic Analysis Test ==="
echo "Job ID: $SLURM_JOB_ID"
echo "Node: $SLURMD_NODENAME"  
echo "Date: $(date)"
echo "Working directory: $(pwd)"
echo "=========================================="

# Set up application paths
export PATH="/opt/sw/pub/apps:$PATH"
export PATH="/opt/sw/pub/apps/beast.v2.7.5/bin:$PATH"

# Load modules if needed (uncomment and modify as needed)
# module load iqtree
# module load iqtree/2.2.0
# module load beast2

echo "Setting up application paths..."
echo "IQ-TREE path: /opt/sw/pub/apps/iqtree"
echo "BEAST path: /opt/sw/pub/apps/beast.v2.7.5/bin"

# Create working directory
WORK_DIR="iqtree_test_${SLURM_JOB_ID}"
mkdir -p $WORK_DIR
cd $WORK_DIR

echo "Working in directory: $(pwd)"

# Check if IQ-TREE is available
echo -e "\n1. CHECKING IQ-TREE INSTALLATION"
echo "================================"
if command -v iqtree &> /dev/null; then
    echo "✓ IQ-TREE found: $(which iqtree)"
    iqtree --version
    IQTREE_CMD="iqtree"
elif command -v iqtree2 &> /dev/null; then
    echo "✓ IQ-TREE2 found: $(which iqtree2)"
    iqtree2 --version
    IQTREE_CMD="iqtree2"
else
    echo "✗ IQ-TREE not found in PATH"
    echo "Please ensure IQ-TREE is installed and available"
    exit 1
fi

# Set path to BEAST example data
BEAST_DATA_PATH="/opt/sw/pub/apps/beast.v2.7.5/examples/nexus"

# Check if BEAST example data is accessible
echo -e "\n2. CHECKING BEAST EXAMPLE DATA ACCESS"
echo "====================================="
if [[ -d "$BEAST_DATA_PATH" ]]; then
    echo "✓ BEAST example data directory found: $BEAST_DATA_PATH"
    echo "Available datasets:"
    ls -la $BEAST_DATA_PATH/*.nex | head -10
else
    echo "✗ BEAST example data not found at $BEAST_DATA_PATH"
    echo "Please verify the BEAST installation path"
    exit 1
fi

# Test datasets to use
datasets=("primate-mtDNA.nex" "dna.nex" "angiosperms.nex" "Primates.nex")

echo -e "\n3. TESTING MULTIPLE DATASETS"
echo "============================"

for dataset in "${datasets[@]}"; do
    if [[ -f "$BEAST_DATA_PATH/$dataset" ]]; then
        echo -e "\n--- Testing dataset: $dataset ---"
        
        # Copy dataset to working directory
        cp "$BEAST_DATA_PATH/$dataset" ./
        
        # Get basic info about the dataset
        echo "Dataset information:"
        if grep -q "NTAX" $dataset; then
            ntax=$(grep "NTAX" $dataset | sed 's/.*NTAX=\([0-9]*\).*/\1/')
            nchar=$(grep "NCHAR" $dataset | sed 's/.*NCHAR=\([0-9]*\).*/\1/')
            echo "  Taxa: $ntax, Characters: $nchar"
        fi
        
        # Quick ML tree
        echo "Running quick ML analysis..."
        $IQTREE_CMD -s $dataset -m GTR+G -nt $SLURM_CPUS_PER_TASK --prefix ${dataset%.nex}_quick -quiet
        
        if [[ $? -eq 0 ]]; then
            echo "✓ Quick ML analysis completed for $dataset"
            if [[ -f "${dataset%.nex}_quick.iqtree" ]]; then
                logL=$(grep "Log-likelihood of the tree" ${dataset%.nex}_quick.iqtree | cut -d':' -f2 | tr -d ' ')
                echo "  Log-likelihood: $logL"
            fi
        else
            echo "✗ Quick ML analysis failed for $dataset"
        fi
    else
        echo "⚠ Dataset $dataset not found, skipping..."
    fi
done

# Detailed analysis on primate dataset
echo -e "\n4. DETAILED ANALYSIS - PRIMATE mtDNA"
echo "==================================="
MAIN_DATASET="primate-mtDNA.nex"

if [[ -f "$BEAST_DATA_PATH/$MAIN_DATASET" ]]; then
    cp "$BEAST_DATA_PATH/$MAIN_DATASET" ./
    
    echo "Running comprehensive analysis on $MAIN_DATASET..."
    
    # Model selection
    echo "Step 1: Model selection with ModelFinder..."
    $IQTREE_CMD -s $MAIN_DATASET -m MFP -nt $SLURM_CPUS_PER_TASK --prefix primate_models
    
    if [[ $? -eq 0 ]] && [[ -f "primate_models.iqtree" ]]; then
        echo "✓ Model selection completed"
        best_model=$(grep "Best-fit model" primate_models.iqtree | cut -d':' -f2 | tr -d ' ')
        echo "  Best model: $best_model"
    else
        echo "✗ Model selection failed, using GTR+I+G"
        best_model="GTR+I+G"
    fi
    
    # ML tree with bootstrap
    echo "Step 2: ML tree with bootstrap support..."
    $IQTREE_CMD -s $MAIN_DATASET -m $best_model -bb 1000 -nt $SLURM_CPUS_PER_TASK --prefix primate_bootstrap
    
    if [[ $? -eq 0 ]]; then
        echo "✓ Bootstrap analysis completed"
        if [[ -f "primate_bootstrap.treefile" ]]; then
            echo "  Tree file: primate_bootstrap.treefile"
        fi
    else
        echo "✗ Bootstrap analysis failed"
    fi
    
    # SH-aLRT test
    echo "Step 3: SH-aLRT branch support test..."
    $IQTREE_CMD -s $MAIN_DATASET -m $best_model -alrt 1000 -nt $SLURM_CPUS_PER_TASK --prefix primate_alrt
    
    if [[ $? -eq 0 ]]; then
        echo "✓ SH-aLRT test completed"
    else
        echo "✗ SH-aLRT test failed"
    fi
    
else
    echo "✗ Main dataset $MAIN_DATASET not found"
fi

# Test partition analysis if suitable dataset exists
echo -e "\n5. PARTITION ANALYSIS TEST"
echo "========================="
PARTITION_DATASET="dna.nex"

if [[ -f "$BEAST_DATA_PATH/$PARTITION_DATASET" ]]; then
    cp "$BEAST_DATA_PATH/$PARTITION_DATASET" ./
    
    # Create simple partition file for codon positions
    echo "Creating partition file for codon positions..."
    cat > simple_partitions.txt << 'EOF'
DNA, pos1 = 1-898\3
DNA, pos2 = 2-898\3  
DNA, pos3 = 3-898\3
EOF
    
    echo "Running partitioned analysis..."
    $IQTREE_CMD -s $PARTITION_DATASET -p simple_partitions.txt -m MFP -nt $SLURM_CPUS_PER_TASK --prefix partition_test -quiet
    
    if [[ $? -eq 0 ]]; then
        echo "✓ Partition analysis completed"
    else
        echo "✗ Partition analysis failed"
    fi
fi

# Performance and summary
echo -e "\n6. PERFORMANCE SUMMARY"
echo "====================="
echo "Files generated:"
ls -la *.treefile *.iqtree *.log 2>/dev/null | wc -l | xargs echo "Total output files:"

echo -e "\nRuntime summary:"
for logfile in *.iqtree; do
    if [[ -f "$logfile" ]]; then
        runtime=$(grep "Total wall-clock time" "$logfile" 2>/dev/null | cut -d':' -f2-)
        if [[ -n "$runtime" ]]; then
            echo "  $(basename $logfile .iqtree): $runtime"
        fi
    fi
done

# Check for common issues
echo -e "\n7. DIAGNOSTIC CHECK"
echo "=================="
error_count=0
for logfile in *.iqtree; do
    if [[ -f "$logfile" ]] && grep -q "ERROR" "$logfile"; then
        echo "⚠ Errors found in $logfile"
        ((error_count++))
    fi
done

if [[ $error_count -eq 0 ]]; then
    echo "✓ No errors detected in log files"
else
    echo "⚠ $error_count files contain errors - check individual log files"
fi

echo -e "\n=========================================="
echo "IQ-TREE test completed at: $(date)"
echo "Check individual .iqtree files for detailed results"
echo "=========================================="
