#!/bin/bash

# AlphaFold3 Comprehensive Test Suite
# Tests container, databases, GPU, and both existing test scripts
# Expected runtime: 5-15 minutes depending on hardware
# Supports different execution modes: local, headnode, compute

set -e  # Exit on any error

# Execution mode (can be set via command line)
EXECUTION_MODE="local"  # local, headnode, compute

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
RESULTS_DIR="${SCRIPT_DIR}/alphafold3_test_results_${TIMESTAMP}"
LOG_FILE="${RESULTS_DIR}/alphafold3_test.log"

# AlphaFold3 paths (will be set by module)
AF3_MODULE="alphafold3/3.0"
AF3_ROOT="/opt/ohpc/pub/apps/alphafold3"
DB_ROOT="/opt/ohpc/pub/apps/public_databases"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Parse command line arguments
parse_arguments() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            --mode)
                EXECUTION_MODE="$2"
                shift 2
                ;;
            -h|--help)
                echo "AlphaFold3 Test Suite"
                echo "Usage: $0 [--mode MODE]"
                echo "Modes: local, headnode, compute"
                echo "  local    - Run all tests (default)"
                echo "  headnode - Run only head node compatible tests"
                echo "  compute  - Run only compute node tests (GPU required)"
                exit 0
                ;;
            *)
                echo "Unknown option: $1"
                exit 1
                ;;
        esac
    done
}

# Function to log with timestamp
log() {
    echo -e "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

# Function for colored output
print_status() {
    local status=$1
    local message=$2
    case $status in
        "INFO")  echo -e "${BLUE}[INFO]${NC} $message" | tee -a "$LOG_FILE" ;;
        "PASS")  echo -e "${GREEN}[PASS]${NC} $message" | tee -a "$LOG_FILE" ;;
        "FAIL")  echo -e "${RED}[FAIL]${NC} $message" | tee -a "$LOG_FILE" ;;
        "WARN")  echo -e "${YELLOW}[WARN]${NC} $message" | tee -a "$LOG_FILE" ;;
    esac
}

# Create results directory structure
setup_test_environment() {
    # Create directories FIRST, before any logging
    mkdir -p "$RESULTS_DIR" || {
        echo "ERROR: Failed to create results directory: $RESULTS_DIR"
        exit 1
    }
    
    # Create subdirectories
    mkdir -p "$RESULTS_DIR"/{logs,outputs,sequences,database_tests}
    
    # Initialize log file early so tee works
    touch "$LOG_FILE"
    
    # NOW we can safely use print_status with logging
    print_status "INFO" "Setting up AlphaFold3 test environment..."
    
    # Create test sequences directory with small protein examples
    cat > "${RESULTS_DIR}/sequences/small_peptide.fasta" << 'EOF'
>test_peptide_20aa
MKFLVNVALVFMVVYISAYL
EOF

    cat > "${RESULTS_DIR}/sequences/villin_headpiece.fasta" << 'EOF'
>villin_headpiece_35aa
MLSDEDFKAVFGMTRSAFANLPLWKQQNLKKEKGLF
EOF

    cat > "${RESULTS_DIR}/sequences/trp_cage.fasta" << 'EOF'
>trp_cage_20aa
NLYIQWLKDGGPSSGRPPPS
EOF

    log "Created test environment in: $RESULTS_DIR"
    log "Execution mode: $EXECUTION_MODE"
}

# Test module loading
test_module_loading() {
    print_status "INFO" "Testing module loading..."
    
    # Check if module is already loaded (e.g., via SLURM job)
    if [[ -n "$ALPHAFOLD_CONTAINER" && -n "$ALPHAFOLD_DB" ]]; then
        print_status "PASS" "AlphaFold3 module already loaded"
        print_status "INFO" "ALPHAFOLD_CONTAINER: $ALPHAFOLD_CONTAINER"
        print_status "INFO" "ALPHAFOLD_DB: $ALPHAFOLD_DB"
        return 0
    fi
    
    # Try to initialize module system if needed
    if [[ -f /etc/profile.d/modules.sh ]]; then
        source /etc/profile.d/modules.sh
    elif [[ -f /opt/ohpc/admin/lmod/lmod/init/bash ]]; then
        source /opt/ohpc/admin/lmod/lmod/init/bash
    elif [[ -f /usr/share/lmod/lmod/init/bash ]]; then
        source /usr/share/lmod/lmod/init/bash
    fi
    
    # Check if module is available
    if module avail 2>&1 | grep -q "alphafold3"; then
        print_status "PASS" "AlphaFold3 module is available"
        
        # Try to load the module
        print_status "INFO" "Loading AlphaFold3 module..."
        if module load "$AF3_MODULE" 2>&1; then
            print_status "PASS" "AlphaFold3 module loaded successfully"
        elif module --ignore_cache load "$AF3_MODULE" 2>&1; then
            print_status "PASS" "AlphaFold3 module loaded successfully (cache ignored)"
        else
            print_status "WARN" "Failed to load AlphaFold3 module, using manual setup"
            manual_setup_paths
            return 0
        fi
        
        # Check environment variables after loading
        if [[ -n "$ALPHAFOLD_CONTAINER" ]]; then
            print_status "PASS" "ALPHAFOLD_CONTAINER set to: $ALPHAFOLD_CONTAINER"
        else
            print_status "WARN" "ALPHAFOLD_CONTAINER not set, using manual setup"
            manual_setup_paths
            return 0
        fi
        
        if [[ -n "$ALPHAFOLD_DB" ]]; then
            print_status "PASS" "ALPHAFOLD_DB set to: $ALPHAFOLD_DB"
        else
            print_status "WARN" "ALPHAFOLD_DB not set, using manual setup"
            manual_setup_paths
            return 0
        fi
    else
        print_status "WARN" "AlphaFold3 module not found, using manual setup"
        manual_setup_paths
    fi
}

# Manual path setup as fallback
manual_setup_paths() {
    print_status "INFO" "Setting up AlphaFold3 paths manually..."
    export ALPHAFOLD_CONTAINER="/opt/ohpc/pub/apps/alphafold3/alphafold3_latest.sif"
    export ALPHAFOLD_DB="/opt/ohpc/pub/apps/public_databases"
    
    # Verify manual paths exist
    if [[ -f "$ALPHAFOLD_CONTAINER" ]]; then
        print_status "PASS" "Container found at: $ALPHAFOLD_CONTAINER"
    else
        print_status "FAIL" "Container not found at: $ALPHAFOLD_CONTAINER"
        exit 1
    fi
    
    if [[ -d "$ALPHAFOLD_DB" ]]; then
        print_status "PASS" "Database directory found at: $ALPHAFOLD_DB"
    else
        print_status "FAIL" "Database directory not found at: $ALPHAFOLD_DB"
        exit 1
    fi
    
    print_status "PASS" "Manual setup completed successfully"
}

# Test container accessibility
test_container() {
    print_status "INFO" "Testing AlphaFold3 container..."
    
    # Debug filesystem access
    print_status "INFO" "Debugging container file access..."
    print_status "INFO" "Current user: $(whoami)"
    print_status "INFO" "Current node: $(hostname)"
    print_status "INFO" "Expected container path: $ALPHAFOLD_CONTAINER"
    
    # Check parent directory first
    local container_dir=$(dirname "$ALPHAFOLD_CONTAINER")
    print_status "INFO" "Checking parent directory: $container_dir"
    if [[ -d "$container_dir" ]]; then
        print_status "PASS" "Parent directory exists"
        print_status "INFO" "Directory contents:"
        ls -la "$container_dir" 2>&1 | tee -a "$LOG_FILE"
    else
        print_status "FAIL" "Parent directory does not exist: $container_dir"
        return 1
    fi
    
    # Check file existence with detailed info
    if [[ -e "$ALPHAFOLD_CONTAINER" ]]; then
        print_status "PASS" "Container file exists"
        print_status "INFO" "File details:"
        ls -la "$ALPHAFOLD_CONTAINER" 2>&1 | tee -a "$LOG_FILE"
        
        # Check if it's readable
        if [[ -r "$ALPHAFOLD_CONTAINER" ]]; then
            print_status "PASS" "Container file is readable"
        else
            print_status "FAIL" "Container file exists but is not readable"
            print_status "INFO" "File permissions:"
            stat "$ALPHAFOLD_CONTAINER" 2>&1 | tee -a "$LOG_FILE"
            return 1
        fi
    else
        print_status "FAIL" "Container file not found: $ALPHAFOLD_CONTAINER"
        print_status "INFO" "Searching for container files in directory..."
        find "$container_dir" -name "*.sif" 2>/dev/null | tee -a "$LOG_FILE" || true
        return 1
    fi
    
    # Test container can be executed
    print_status "INFO" "Testing container execution..."
    if apptainer exec "$ALPHAFOLD_CONTAINER" python --version > "${RESULTS_DIR}/logs/container_python.log" 2>&1; then
        print_status "PASS" "Container is executable"
        cat "${RESULTS_DIR}/logs/container_python.log" | tee -a "$LOG_FILE"
    else
        print_status "FAIL" "Container execution failed"
        cat "${RESULTS_DIR}/logs/container_python.log" | tee -a "$LOG_FILE"
        
        # Additional debugging for container execution failure
        print_status "INFO" "Checking apptainer/singularity availability..."
        if command -v apptainer >/dev/null 2>&1; then
            print_status "PASS" "apptainer command found: $(which apptainer)"
        elif command -v singularity >/dev/null 2>&1; then
            print_status "WARN" "singularity found but apptainer preferred: $(which singularity)"
        else
            print_status "FAIL" "Neither apptainer nor singularity found"
        fi
        return 1
    fi
    
    # Test AlphaFold3 help if available
    print_status "INFO" "Testing af3_run alias..."
    if command -v af3_run >/dev/null 2>&1; then
        print_status "PASS" "af3_run alias is available"
        if af3_run --help > "${RESULTS_DIR}/logs/af3_help.log" 2>&1; then
            print_status "PASS" "AlphaFold3 help command works"
        else
            print_status "WARN" "AlphaFold3 help command failed (may be normal)"
        fi
    else
        print_status "WARN" "af3_run alias not set up"
        print_status "INFO" "Will test direct apptainer execution instead"
    fi
}

# Test GPU availability
test_gpu() {
    print_status "INFO" "Testing GPU availability..."
    
    # Skip GPU tests in headnode mode
    if [[ "$EXECUTION_MODE" == "headnode" ]]; then
        print_status "INFO" "Skipping GPU tests (headnode mode)"
        return 0
    fi
    
    # Check nvidia-smi
    if nvidia-smi > "${RESULTS_DIR}/logs/nvidia_smi.log" 2>&1; then
        print_status "PASS" "nvidia-smi works"
        log "GPU Information:"
        head -20 "${RESULTS_DIR}/logs/nvidia_smi.log" | tee -a "$LOG_FILE"
    else
        if [[ "$EXECUTION_MODE" == "compute" ]]; then
            print_status "FAIL" "nvidia-smi failed - GPU should be available on compute node"
            return 1
        else
            print_status "WARN" "nvidia-smi failed - GPU may not be available"
            return 0
        fi
    fi
    
    # Test GPU access from container
    if apptainer exec --nv "$ALPHAFOLD_CONTAINER" nvidia-smi > "${RESULTS_DIR}/logs/container_gpu.log" 2>&1; then
        print_status "PASS" "GPU accessible from container"
    else
        if [[ "$EXECUTION_MODE" == "compute" ]]; then
            print_status "FAIL" "GPU not accessible from container"
            cat "${RESULTS_DIR}/logs/container_gpu.log" | tee -a "$LOG_FILE"
            return 1
        else
            print_status "WARN" "GPU not accessible from container"
            cat "${RESULTS_DIR}/logs/container_gpu.log" | tee -a "$LOG_FILE"
        fi
    fi
    
    # Test CUDA from container
    if apptainer exec --nv "$ALPHAFOLD_CONTAINER" python -c "import torch; print(f'CUDA available: {torch.cuda.is_available()}'); print(f'CUDA devices: {torch.cuda.device_count()}')" > "${RESULTS_DIR}/logs/cuda_test.log" 2>&1; then
        print_status "PASS" "CUDA test completed"
        cat "${RESULTS_DIR}/logs/cuda_test.log" | tee -a "$LOG_FILE"
    else
        if [[ "$EXECUTION_MODE" == "compute" ]]; then
            print_status "FAIL" "CUDA test failed"
            cat "${RESULTS_DIR}/logs/cuda_test.log" | tee -a "$LOG_FILE"
            return 1
        else
            print_status "WARN" "CUDA test failed"
            cat "${RESULTS_DIR}/logs/cuda_test.log" | tee -a "$LOG_FILE"
        fi
    fi
}

# Test database files and functionality
test_databases() {
    print_status "INFO" "Testing database files and functionality..."
    
    # Check database files exist
    local databases=(
        "bfd-first_non_consensus_sequences.fasta"
        "mgy_clusters_2022_05.fa"
        "nt_rna_2023_02_23_clust_seq_id_90_cov_80_rep_seq.fasta"
        "pdb_seqres_2022_09_28.fasta"
        "rfam_14_9_clust_seq_id_90_cov_80_rep_seq.fasta"
        "rnacentral_active_seq_id_90_cov_80_linclust.fasta"
        "uniprot_all_2021_04.fa"
        "uniref90_2022_05.fa"
    )
    
    local db_status=0
    for db in "${databases[@]}"; do
        if [[ -f "$DB_ROOT/$db" ]]; then
            print_status "PASS" "Database file exists: $db"
            # Test file readability and get basic stats
            local size=$(du -h "$DB_ROOT/$db" | cut -f1)
            local lines=$(head -1000 "$DB_ROOT/$db" | wc -l)
            log "  Size: $size, First 1000 lines: $lines"
        else
            print_status "FAIL" "Database file missing: $db"
            db_status=1
        fi
    done
    
    # Check mmcif_files directory
    if [[ -d "$DB_ROOT/mmcif_files" ]]; then
        local mmcif_count=$(ls "$DB_ROOT/mmcif_files" | wc -l)
        print_status "PASS" "mmcif_files directory exists with $mmcif_count files"
    else
        print_status "FAIL" "mmcif_files directory missing"
        db_status=1
    fi
    
    # Test database functionality with a quick sequence search
    print_status "INFO" "Testing database functionality..."
    
    # Simple grep test on smaller databases
    if grep -m 1 ">" "$DB_ROOT/pdb_seqres_2022_09_28.fasta" > "${RESULTS_DIR}/database_tests/pdb_test.log" 2>&1; then
        print_status "PASS" "PDB sequences database is readable and searchable"
        cat "${RESULTS_DIR}/database_tests/pdb_test.log" | tee -a "$LOG_FILE"
    else
        print_status "FAIL" "PDB sequences database test failed"
        db_status=1
    fi
    
    return $db_status
}

# Run existing AlphaFold3 test scripts
run_existing_tests() {
    print_status "INFO" "Running existing AlphaFold3 test scripts..."
    
    # Skip compute-intensive tests in headnode mode
    if [[ "$EXECUTION_MODE" == "headnode" ]]; then
        print_status "INFO" "Skipping existing test scripts (headnode mode)"
        return 0
    fi
    
    cd "$AF3_ROOT"
    
    # Run run_alphafold_test.py
    print_status "INFO" "Running run_alphafold_test.py..."
    if timeout 300 python run_alphafold_test.py > "${RESULTS_DIR}/outputs/alphafold_test_output.log" 2>&1; then
        print_status "PASS" "run_alphafold_test.py completed successfully"
    else
        local exit_code=$?
        if [[ $exit_code -eq 124 ]]; then
            print_status "WARN" "run_alphafold_test.py timed out after 5 minutes"
        else
            print_status "FAIL" "run_alphafold_test.py failed with exit code: $exit_code"
        fi
        cat "${RESULTS_DIR}/outputs/alphafold_test_output.log" | tail -50 | tee -a "$LOG_FILE"
    fi
    
    # Run run_alphafold_data_test.py
    print_status "INFO" "Running run_alphafold_data_test.py..."
    if timeout 300 python run_alphafold_data_test.py > "${RESULTS_DIR}/outputs/alphafold_data_test_output.log" 2>&1; then
        print_status "PASS" "run_alphafold_data_test.py completed successfully"
    else
        local exit_code=$?
        if [[ $exit_code -eq 124 ]]; then
            print_status "WARN" "run_alphafold_data_test.py timed out after 5 minutes"
        else
            print_status "FAIL" "run_alphafold_data_test.py failed with exit code: $exit_code"
        fi
        cat "${RESULTS_DIR}/outputs/alphafold_data_test_output.log" | tail -50 | tee -a "$LOG_FILE"
    fi
    
    cd "$SCRIPT_DIR"
}

# Run a quick functional test with small protein
run_functional_test() {
    print_status "INFO" "Running functional test with small protein..."
    
    # Skip functional tests in headnode mode
    if [[ "$EXECUTION_MODE" == "headnode" ]]; then
        print_status "INFO" "Skipping functional test (headnode mode)"
        return 0
    fi
    
    cd "$RESULTS_DIR/outputs"
    
    # Test with the smallest peptide (20aa)
    local test_sequence="${RESULTS_DIR}/sequences/small_peptide.fasta"
    
    print_status "INFO" "Testing prediction with 20aa peptide..."
    
    # Run with reduced parameters for speed
    if timeout 600 af3_run \
        --fasta_paths="$test_sequence" \
        --model_dir="$ALPHAFOLD_DB" \
        --output_dir="${RESULTS_DIR}/outputs/prediction_test" \
        --max_template_date=2023-01-01 \
        --db_preset=reduced_dbs \
        > "${RESULTS_DIR}/outputs/functional_test.log" 2>&1; then
        print_status "PASS" "Functional prediction test completed"
        
        # Check if output files were created
        if [[ -d "${RESULTS_DIR}/outputs/prediction_test" ]]; then
            local output_files=$(ls "${RESULTS_DIR}/outputs/prediction_test" 2>/dev/null | wc -l)
            print_status "PASS" "Prediction created $output_files output files"
        fi
    else
        local exit_code=$?
        if [[ $exit_code -eq 124 ]]; then
            print_status "WARN" "Functional test timed out after 10 minutes"
        else
            print_status "FAIL" "Functional test failed with exit code: $exit_code"
        fi
        
        # Show last 50 lines of log for debugging
        tail -50 "${RESULTS_DIR}/outputs/functional_test.log" | tee -a "$LOG_FILE"
    fi
}

# Generate test report
generate_report() {
    print_status "INFO" "Generating test report..."
    
    local report_file="${RESULTS_DIR}/alphafold3_test_report.txt"
    
    cat > "$report_file" << EOF
================================================================================
AlphaFold3 Test Suite Report
================================================================================
Test Date: $(date)
Test Duration: $(($(date +%s) - start_time)) seconds
Execution Mode: $EXECUTION_MODE
Results Directory: $RESULTS_DIR

SYSTEM INFORMATION:
- Hostname: $(hostname)
- OS: $(uname -a)
- AlphaFold3 Module: $AF3_MODULE
- Container: $ALPHAFOLD_CONTAINER
- Database Path: $ALPHAFOLD_DB
$(if [[ -n "$SLURM_JOB_ID" ]]; then echo "- SLURM Job ID: $SLURM_JOB_ID"; fi)
$(if [[ -n "$SLURMD_NODENAME" ]]; then echo "- SLURM Node: $SLURMD_NODENAME"; fi)

GPU INFORMATION:
$(if [[ -f "${RESULTS_DIR}/logs/cuda_test.log" ]]; then cat "${RESULTS_DIR}/logs/cuda_test.log"; else echo "GPU test not completed or skipped"; fi)

TEST RESULTS SUMMARY:
$(grep -E "\[(PASS|FAIL|WARN)\]" "$LOG_FILE" | sort | uniq -c)

DETAILED LOG:
See: $LOG_FILE

OUTPUT FILES:
$(find "$RESULTS_DIR" -type f -name "*.log" -o -name "*.out" -o -name "*.fasta" | sort)

================================================================================
EOF

    log "Test report generated: $report_file"
    print_status "PASS" "AlphaFold3 test suite completed!"
}

# Main execution
main() {
    local start_time=$(date +%s)
    
    # Parse command line arguments
    parse_arguments "$@"
    
    echo "========================================"
    echo "AlphaFold3 Comprehensive Test Suite"
    echo "========================================"
    echo "Execution Mode: $EXECUTION_MODE"
    echo "Started at: $(date)"
    echo ""
    
    setup_test_environment
    
    # Run tests based on execution mode
    case $EXECUTION_MODE in
        "headnode")
            print_status "INFO" "Running head node tests only..."
            test_module_loading
            test_container
            test_databases
            ;;
        "compute")
            print_status "INFO" "Running compute node tests only..."
            test_module_loading
            test_container
            test_gpu || exit 1  # GPU must work on compute nodes
            run_existing_tests
            run_functional_test
            ;;
        "local"|*)
            print_status "INFO" "Running all tests..."
            test_module_loading
            test_container
            test_gpu
            test_databases
            run_existing_tests
            run_functional_test
            ;;
    esac
    
    generate_report
    
    local end_time=$(date +%s)
    local duration=$((end_time - start_time))
    
    echo ""
    echo "========================================"
    echo "Test suite completed in ${duration} seconds"
    echo "Results saved to: $RESULTS_DIR"
    echo "========================================"
}

# Trap to ensure cleanup on exit
trap 'log "Test interrupted or failed"' ERR

# Run main function with all arguments
main "$@"
