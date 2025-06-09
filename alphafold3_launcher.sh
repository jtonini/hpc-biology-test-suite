#!/bin/bash

# AlphaFold3 Test Suite Launcher
# Handles execution on head node vs compute nodes with SLURM

set -e

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
AF3_TEST_SCRIPT="$SCRIPT_DIR/alphafold3_test.sh"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Default SLURM parameters (based on your cluster setup)
DEFAULT_PARTITION="gpunodes"
DEFAULT_NODES=1
DEFAULT_CPUS=8
DEFAULT_MEMORY="32G"
DEFAULT_TIME="30:00"
DEFAULT_GRES=""  # Empty by default - not all clusters use GRES

# Function for colored output
print_status() {
    local status=$1
    local message=$2
    case $status in
        "INFO")  echo -e "${BLUE}[INFO]${NC} $message" ;;
        "PASS")  echo -e "${GREEN}[PASS]${NC} $message" ;;
        "FAIL")  echo -e "${RED}[FAIL]${NC} $message" ;;
        "WARN")  echo -e "${YELLOW}[WARN]${NC} $message" ;;
    esac
}

# Show usage
show_usage() {
    cat << 'EOF'
================================================================================
                       AlphaFold3 Test Suite Launcher
================================================================================

DESCRIPTION:
    Intelligently runs AlphaFold3 tests on head nodes and compute nodes using SLURM.
    Designed for HPC environments where head nodes lack GPUs but compute nodes have them.
    
    NOTE: You must specify a MODE. Running without arguments shows this help.

USAGE:
    ./alphafold3_launcher.sh [MODE] [OPTIONS]

MODES:
    local       Run all tests locally (use only on compute nodes with GPU)
    headnode    Run head node tests only (no GPU/compute tests)
    slurm       Submit GPU tests to SLURM, run head node tests locally
    full        Run head node tests, then submit compute tests to SLURM

SLURM OPTIONS (for slurm/full modes):
    -p, --partition PARTITION   SLURM partition (default: gpunodes)
                               Available: gpunodes, cpunodes, allnodes, fiftyone, etc.
    -N, --nodes NODES          Number of nodes (default: 1)
    -c, --cpus CPUS            CPUs per task (default: 8)
    -m, --memory MEMORY        Memory per node (default: 32G)
    -t, --time TIME            Time limit (default: 30:00)
    -g, --gres GRES            GPU resources (default: none - many clusters don't need this)
                               Examples: gpu:1, gpu:tesla:1, gpu (depends on cluster)
    -A, --account ACCOUNT      SLURM account
    -q, --qos QOS              Quality of Service

OTHER OPTIONS:
    -h, --help                 Show this help
    -v, --verbose              Verbose output
    --dry-run                  Show SLURM command without submitting
    --debug                    Show detailed debugging info

CLUSTER-SPECIFIC INFO:
    Your cluster configuration:
    - GPU partition: gpunodes (node51 available, nodes 52-53 down)
    - CPU partitions: cpunodes (nodes 01-03)
    - Specific node partitions: fiftyone (node51), one/two/three (nodes 01-03)

EXAMPLES:
    # Show this help (same as running with no arguments)
    ./alphafold3_launcher.sh --help

    # Basic usage (recommended for head node)
    ./alphafold3_launcher.sh slurm

    # Target specific GPU node (node51 only)
    ./alphafold3_launcher.sh slurm -p fiftyone

    # Use more resources on GPU node
    ./alphafold3_launcher.sh slurm -p gpunodes -c 12 -m 48G

    # Add GRES if your cluster requires it (test first with --dry-run)
    ./alphafold3_launcher.sh slurm -g gpu:1 --dry-run

    # Just head node tests (quick validation)
    ./alphafold3_launcher.sh headnode

    # Run everything locally (only on GPU compute nodes like node51)
    ./alphafold3_launcher.sh local

    # Full test with monitoring
    ./alphafold3_launcher.sh full -p fiftyone -v

TROUBLESHOOTING:
    - GRES errors: Try without -g option or use --dry-run to test
    - Partition errors: Check available partitions with 'sinfo'
    - Module errors: Ensure 'module avail' shows alphafold3
    - Use --debug for detailed troubleshooting info

================================================================================
EOF
}

# Show debugging information
show_debug_info() {
    print_status "INFO" "=== DEBUG INFORMATION ==="
    print_status "INFO" "Current user: $(whoami)"
    print_status "INFO" "Current directory: $(pwd)"
    print_status "INFO" "Available partitions:"
    sinfo -s 2>/dev/null || print_status "WARN" "Could not get partition info"
    
    print_status "INFO" "Available modules:"
    module avail 2>&1 | grep -i alphafold || print_status "WARN" "No alphafold modules found"
    
    print_status "INFO" "SLURM environment:"
    if [[ -n "$SLURM_JOB_ID" ]]; then
        print_status "INFO" "  Running in SLURM job: $SLURM_JOB_ID"
        print_status "INFO" "  Node: $SLURMD_NODENAME"
    else
        print_status "INFO" "  Not in SLURM job"
    fi
    
    print_status "INFO" "GPU status:"
    if command -v nvidia-smi >/dev/null 2>&1; then
        nvidia-smi -L 2>/dev/null || print_status "INFO" "  nvidia-smi available but no GPUs detected"
    else
        print_status "INFO" "  nvidia-smi not available"
    fi
    print_status "INFO" "=== END DEBUG ==="
}

# Parse command line arguments
parse_args() {
    MODE="slurm"  # Default mode
    PARTITION="$DEFAULT_PARTITION"
    NODES="$DEFAULT_NODES"
    CPUS="$DEFAULT_CPUS"
    MEMORY="$DEFAULT_MEMORY"
    TIME="$DEFAULT_TIME"
    GRES="$DEFAULT_GRES"
    ACCOUNT=""
    QOS=""
    VERBOSE=false
    DRY_RUN=false
    DEBUG=false

    while [[ $# -gt 0 ]]; do
        case $1 in
            local|headnode|slurm|full)
                MODE="$1"
                shift
                ;;
            -p|--partition)
                PARTITION="$2"
                shift 2
                ;;
            -N|--nodes)
                NODES="$2"
                shift 2
                ;;
            -c|--cpus)
                CPUS="$2"
                shift 2
                ;;
            -m|--memory)
                MEMORY="$2"
                shift 2
                ;;
            -t|--time)
                TIME="$2"
                shift 2
                ;;
            -g|--gres)
                GRES="$2"
                shift 2
                ;;
            -A|--account)
                ACCOUNT="$2"
                shift 2
                ;;
            -q|--qos)
                QOS="$2"
                shift 2
                ;;
            -v|--verbose)
                VERBOSE=true
                shift
                ;;
            --dry-run)
                DRY_RUN=true
                shift
                ;;
            --debug)
                DEBUG=true
                VERBOSE=true
                shift
                ;;
            -h|--help)
                show_usage
                exit 0
                ;;
            *)
                echo "Unknown option: $1"
                show_usage
                exit 1
                ;;
        esac
    done
}

# Check if we're on a head node or compute node
detect_node_type() {
    # Simple heuristic: check for GPU and SLURM environment
    if command -v nvidia-smi >/dev/null 2>&1 && nvidia-smi >/dev/null 2>&1; then
        echo "compute"
    elif [[ -n "$SLURM_JOB_ID" ]]; then
        echo "compute"
    else
        echo "head"
    fi
}

# Validate cluster configuration
validate_cluster_config() {
    print_status "INFO" "Validating cluster configuration..."
    
    # Check if SLURM is available
    if ! command -v sbatch >/dev/null 2>&1; then
        print_status "FAIL" "SLURM not available - cannot submit jobs"
        exit 1
    fi
    
    # Check if partition exists
    if [[ "$MODE" =~ ^(slurm|full)$ ]]; then
        if ! sinfo -p "$PARTITION" >/dev/null 2>&1; then
            print_status "WARN" "Partition '$PARTITION' may not exist"
            print_status "INFO" "Available partitions:"
            sinfo -s
        else
            local available_nodes=$(sinfo -p "$PARTITION" -h -t idle | wc -l)
            print_status "PASS" "Partition '$PARTITION' available with $available_nodes idle nodes"
        fi
    fi
    
    # Check if AlphaFold3 module is available
    if module avail 2>&1 | grep -q "alphafold3"; then
        print_status "PASS" "AlphaFold3 module is available"
    else
        print_status "WARN" "AlphaFold3 module may not be available"
    fi
}

# Build SLURM command
build_slurm_command() {
    local sbatch_cmd="sbatch"
    
    sbatch_cmd+=" --partition=$PARTITION"
    sbatch_cmd+=" --nodes=$NODES"
    sbatch_cmd+=" --cpus-per-task=$CPUS"
    sbatch_cmd+=" --mem=$MEMORY"
    sbatch_cmd+=" --time=$TIME"
    
    # Only add GRES if specified (many clusters don't need it)
    if [[ -n "$GRES" ]]; then
        sbatch_cmd+=" --gres=$GRES"
    fi
    
    if [[ -n "$ACCOUNT" ]]; then
        sbatch_cmd+=" --account=$ACCOUNT"
    fi
    
    if [[ -n "$QOS" ]]; then
        sbatch_cmd+=" --qos=$QOS"
    fi
    
    # Job name and output
    sbatch_cmd+=" --job-name=af3_test"
    sbatch_cmd+=" --output=af3_test_%j.out"
    sbatch_cmd+=" --error=af3_test_%j.err"
    
    echo "$sbatch_cmd"
}

# Run head node tests only
run_headnode_tests() {
    print_status "INFO" "Running head node tests..."
    
    if [[ ! -f "$AF3_TEST_SCRIPT" ]]; then
        print_status "FAIL" "AlphaFold3 test script not found: $AF3_TEST_SCRIPT"
        exit 1
    fi
    
    # Run with headnode flag
    bash "$AF3_TEST_SCRIPT" --mode headnode
}

# Submit compute node tests to SLURM
submit_compute_tests() {
    print_status "INFO" "Submitting compute node tests to SLURM..."
    
    local sbatch_cmd=$(build_slurm_command)
    
    # Create temporary SLURM script
    local slurm_script="/tmp/af3_slurm_test_$$.sh"
    
    cat > "$slurm_script" << 'EOF'
#!/bin/bash
#SBATCH --job-name=af3_test
EOF

    # Add SLURM directives
    echo "#SBATCH --partition=$PARTITION" >> "$slurm_script"
    echo "#SBATCH --nodes=$NODES" >> "$slurm_script"
    echo "#SBATCH --cpus-per-task=$CPUS" >> "$slurm_script"
    echo "#SBATCH --mem=$MEMORY" >> "$slurm_script"
    echo "#SBATCH --time=$TIME" >> "$slurm_script"
    
    if [[ -n "$GRES" ]]; then
        echo "#SBATCH --gres=$GRES" >> "$slurm_script"
    fi
    
    if [[ -n "$ACCOUNT" ]]; then
        echo "#SBATCH --account=$ACCOUNT" >> "$slurm_script"
    fi
    
    if [[ -n "$QOS" ]]; then
        echo "#SBATCH --qos=$QOS" >> "$slurm_script"
    fi
    
    # Add script content
    cat >> "$slurm_script" << EOF

echo "=========================================="
echo "AlphaFold3 Compute Node Test"
echo "Node: \$SLURMD_NODENAME"
echo "Job ID: \$SLURM_JOB_ID"
echo "Started at: \$(date)"
echo "=========================================="

# Change to script directory
cd "$SCRIPT_DIR"

# Try to initialize module system if needed
if [[ -f /etc/profile.d/modules.sh ]]; then
    source /etc/profile.d/modules.sh
elif [[ -f /opt/ohpc/admin/lmod/lmod/init/bash ]]; then
    source /opt/ohpc/admin/lmod/lmod/init/bash
elif [[ -f /usr/share/lmod/lmod/init/bash ]]; then
    source /usr/share/lmod/lmod/init/bash
fi

# Load required modules - ESSENTIAL for AlphaFold3 paths
echo "Loading AlphaFold3 module..."
if module load alphafold3/3.0 2>&1; then
    echo "Module loaded successfully"
elif module --ignore_cache load alphafold3/3.0 2>&1; then
    echo "Module loaded successfully (cache ignored)"
else
    echo "Warning: Module load failed, trying to set paths manually..."
    export ALPHAFOLD_CONTAINER="/opt/ohpc/pub/apps/alphafold3/alphafold3_latest.sif"
    export ALPHAFOLD_DB="/opt/ohpc/pub/apps/public_databases"
fi

# Verify module loaded correctly
echo "ALPHAFOLD_CONTAINER: \$ALPHAFOLD_CONTAINER"
echo "ALPHAFOLD_DB: \$ALPHAFOLD_DB"

# Verify test script exists
if [[ ! -f "$AF3_TEST_SCRIPT" ]]; then
    echo "ERROR: AlphaFold3 test script not found: $AF3_TEST_SCRIPT"
    echo "Current directory: \$(pwd)"
    echo "Directory contents:"
    ls -la
    exit 1
fi

# Run compute node tests
echo "Running: bash $AF3_TEST_SCRIPT --mode compute"
bash "$AF3_TEST_SCRIPT" --mode compute

echo "=========================================="
echo "Compute node test completed at: \$(date)"
echo "=========================================="
EOF

    if [[ "$DRY_RUN" == true ]]; then
        print_status "INFO" "=== DRY RUN - SLURM SCRIPT ==="
        cat "$slurm_script"
        print_status "INFO" "=== WOULD SUBMIT WITH ==="
        echo "sbatch $slurm_script"
        print_status "INFO" "=== END DRY RUN ==="
        rm "$slurm_script"
        return 0
    fi
    
    # Submit job and capture both stdout and stderr
    print_status "INFO" "Submitting job with: sbatch $slurm_script"
    local job_output
    local job_exit_code
    
    job_output=$(sbatch "$slurm_script" 2>&1)
    job_exit_code=$?
    
    if [[ $job_exit_code -eq 0 ]]; then
        local job_id=$(echo "$job_output" | grep -oE '[0-9]+$' || echo "unknown")
        print_status "PASS" "Job submitted successfully: $job_output"
        print_status "INFO" "Job ID: $job_id"
        print_status "INFO" "Monitor with: squeue -j $job_id"
        print_status "INFO" "View output: tail -f af3_test_${job_id}.out"
        print_status "INFO" "View errors: tail -f af3_test_${job_id}.err"
        
        # Wait for job completion if requested
        if [[ "$MODE" == "full" ]]; then
            print_status "INFO" "Waiting for SLURM job to complete..."
            
            while squeue -j "$job_id" >/dev/null 2>&1; do
                print_status "INFO" "Job $job_id still running... (checking every 30s)"
                sleep 30
            done
            
            print_status "PASS" "SLURM job $job_id completed"
            
            # Show job results
            if [[ -f "af3_test_${job_id}.out" ]]; then
                print_status "INFO" "Job output (last 50 lines):"
                tail -50 "af3_test_${job_id}.out"
            fi
            
            if [[ -f "af3_test_${job_id}.err" && -s "af3_test_${job_id}.err" ]]; then
                print_status "WARN" "Job errors:"
                tail -50 "af3_test_${job_id}.err"
            fi
        fi
    else
        print_status "FAIL" "Failed to submit job (exit code: $job_exit_code)"
        print_status "FAIL" "Error output: $job_output"
        
        # Show helpful suggestions
        if echo "$job_output" | grep -q "Invalid generic resource"; then
            print_status "INFO" "SUGGESTION: Try without GRES option:"
            print_status "INFO" "  $0 slurm -p $PARTITION"
            print_status "INFO" "Or try different GRES formats with --dry-run:"
            print_status "INFO" "  $0 slurm -g gpu --dry-run"
            print_status "INFO" "  $0 slurm -g gpu:tesla:1 --dry-run"
        elif echo "$job_output" | grep -q "Invalid partition"; then
            print_status "INFO" "SUGGESTION: Check available partitions with 'sinfo'"
        fi
        
        rm "$slurm_script"
        exit 1
    fi
    
    # Clean up temporary script
    rm "$slurm_script"
}

# Run tests locally
run_local_tests() {
    local node_type=$(detect_node_type)
    
    if [[ "$node_type" == "head" ]]; then
        print_status "WARN" "Running on head node - GPU tests may fail"
        print_status "WARN" "Consider using 'slurm' mode instead"
    fi
    
    print_status "INFO" "Running all tests locally..."
    bash "$AF3_TEST_SCRIPT" --mode local
}

# Main execution
main() {
    echo "========================================"
    echo "AlphaFold3 Test Suite Launcher"
    echo "========================================"
    echo "Mode: $MODE"
    echo "Node type: $(detect_node_type)"
    echo ""
    
    # Show debug info if requested
    if [[ "$DEBUG" == true ]]; then
        show_debug_info
        echo ""
    fi
    
    # Validate cluster configuration
    validate_cluster_config
    echo ""
    
    case $MODE in
        "local")
            run_local_tests
            ;;
        "headnode")
            run_headnode_tests
            ;;
        "slurm")
            submit_compute_tests
            ;;
        "full")
            run_headnode_tests
            echo ""
            submit_compute_tests
            ;;
        *)
            print_status "FAIL" "Unknown mode: $MODE"
            show_usage
            exit 1
            ;;
    esac
    
    echo ""
    echo "========================================"
    echo "Launcher completed successfully!"
    echo "========================================"
}

# Parse arguments and run
# If no arguments provided, show help
if [[ $# -eq 0 ]]; then
    show_usage
    exit 0
fi

parse_args "$@"

if [[ "$VERBOSE" == true ]]; then
    print_status "INFO" "Configuration:"
    print_status "INFO" "  Mode: $MODE"
    print_status "INFO" "  Partition: $PARTITION"
    print_status "INFO" "  Nodes: $NODES, CPUs: $CPUS, Memory: $MEMORY"
    print_status "INFO" "  Time: $TIME"
    if [[ -n "$GRES" ]]; then 
        print_status "INFO" "  GRES: $GRES"
    else
        print_status "INFO" "  GRES: none (may not be needed for this cluster)"
    fi
    if [[ -n "$ACCOUNT" ]]; then print_status "INFO" "  Account: $ACCOUNT"; fi
    if [[ -n "$QOS" ]]; then print_status "INFO" "  QOS: $QOS"; fi
    echo ""
fi

main
