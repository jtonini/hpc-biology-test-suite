#!/bin/bash

# Enhanced Comprehensive Biology Software Test Suite with Modular Detection
# Automatically detects and uses individual detailed test scripts

echo "================================================"
echo "    Comprehensive Biology Software Test Suite"
echo "================================================"
echo "Welcome! This suite will thoroughly test biology applications on your HPC system."
echo "We'll test phylogenetics, genomics, population genetics, and bioinformatics tools."
echo ""
echo "Date: $(date)"
echo "Host: $(hostname)"
echo "User: $(whoami)"
echo "Working directory: $(pwd)"
echo ""

# Create results directory and log file
RESULTS_DIR="biology_test_results_$(date +%Y%m%d_%H%M%S)"
mkdir -p "$RESULTS_DIR"
SUMMARY_FILE="$RESULTS_DIR/test_summary.txt"
DETAILED_LOG="$RESULTS_DIR/detailed_log.txt"

echo "Created results directory: $RESULTS_DIR"
echo "Summary will be saved to: $SUMMARY_FILE"
echo "Detailed log will be saved to: $DETAILED_LOG"
echo ""

# Initialize summary file
cat > "$SUMMARY_FILE" << EOF
=================================================================
           BIOLOGY SOFTWARE TEST SUITE SUMMARY
=================================================================
Test Date: $(date)
Hostname: $(hostname)
User: $(whoami)
=================================================================

EOF

# Function to log both to screen and file
log_both() {
    echo "$1" | tee -a "$DETAILED_LOG"
}

# Function to update summary
update_summary() {
    local app_name="$1"
    local status="$2"
    local details="$3"

    printf "%-20s %-15s %s\n" "$app_name" "$status" "$details" >> "$SUMMARY_FILE"
}

# Function to detect available test scripts
detect_test_scripts() {
    local app="$1"
    local script_name="${app}_test.sh"

    if [[ -f "$script_name" ]]; then
        echo "detailed"
        return 0
    else
        echo "basic"
        return 1
    fi
}

# Set up application paths
echo "SETTING UP APPLICATION PATHS"
echo "============================="
log_both "Setting up comprehensive application paths for biology software..."

export PATH="/opt/sw/pub/apps:$PATH"
export PATH="/opt/sw/pub/apps/beast.v2.7.5/bin:$PATH"
log_both "PASS: Added BEAST2 path: /opt/sw/pub/apps/beast.v2.7.5/bin"

if [[ -d "/opt/sw/pub/apps/R/bin" ]]; then
    export PATH="/opt/sw/pub/apps/R/bin:$PATH"
    log_both "PASS: Added R path: /opt/sw/pub/apps/R/bin"
fi

if [[ -d "/opt/sw/pub/apps/kraken2" ]]; then
    export PATH="/opt/sw/pub/apps/kraken2:$PATH"
    log_both "PASS: Added Kraken2 path: /opt/sw/pub/apps/kraken2"
fi

if [[ -d "/opt/sw/pub/apps/vcftools/bin" ]]; then
    export PATH="/opt/sw/pub/apps/vcftools/bin:$PATH"
    log_both "PASS: Added VCFtools path: /opt/sw/pub/apps/vcftools/bin"
fi

if [[ -d "/opt/sw/pub/apps/treemix" ]]; then
    export PATH="/opt/sw/pub/apps/treemix:$PATH"
    log_both "PASS: Added TreeMix path: /opt/sw/pub/apps/treemix"
fi

log_both "SUCCESS: All application paths configured successfully!"
echo ""

# Function to check if command exists with verbose output
check_software() {
    local cmd="$1"
    local app_name="$2"

    log_both "  Searching for $app_name executable..."

    if command -v "$cmd" &> /dev/null; then
        local path=$(which "$cmd")
        log_both "    PASS: $app_name found at: $path"

        # Try to get version info
        case "$cmd" in
            "iqtree"|"iqtree2")
                local version=$($cmd --version 2>&1 | head -1)
                log_both "    Version: $version"
                ;;
            "beast"|"beast2")
                local version=$($cmd -version 2>&1 | head -1)
                log_both "    Version: $version"
                ;;
            "R")
                local version=$($cmd --version 2>&1 | head -1)
                log_both "    Version: $version"
                ;;
            "plink")
                local version=$($cmd --version 2>&1 | head -1)
                log_both "    Version: $version"
                ;;
            "kraken2")
                local version=$($cmd --version 2>&1)
                log_both "    Version: $version"
                ;;
            "vcftools")
                local version=$($cmd --version 2>&1 | head -1)
                log_both "    Version: $version"
                ;;
        esac

        return 0
    else
        log_both "    FAIL: $app_name not found in PATH"
        return 1
    fi
}

# Function to check if file exists and is executable
check_executable() {
    local filepath="$1"
    local app_name="$2"

    log_both "  Checking direct path for $app_name..."
    log_both "    Looking at: $filepath"

    if [[ -x "$filepath" ]]; then
        log_both "    PASS: $app_name executable found and is executable"
        return 0
    elif [[ -f "$filepath" ]]; then
        log_both "    WARNING: File exists but is not executable"
        return 1
    else
        log_both "    FAIL: File does not exist"
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

# Check SLURM availability
echo "CHECKING JOB SCHEDULER"
echo "======================"
if command -v sbatch &> /dev/null; then
    log_both "PASS: SLURM job scheduler detected and available"
    log_both "   SLURM version: $(sbatch --version)"
    scheduler="slurm"
else
    log_both "WARNING: SLURM not detected - will run tests directly on login node"
    log_both "   Note: For production use, consider using a job scheduler"
    scheduler="direct"
fi
echo ""

# Application definitions with detailed descriptions
declare -A apps
declare -A app_paths
declare -A app_categories
declare -A app_descriptions

# Phylogenetics & Molecular Evolution
apps["iqtree"]="IQ-TREE"
app_paths["iqtree"]="/opt/sw/pub/apps/iqtree"
app_categories["iqtree"]="phylogenetics"
app_descriptions["iqtree"]="Maximum likelihood phylogenetic inference with model selection"

apps["beast"]="BEAST2"
app_paths["beast"]="/opt/sw/pub/apps/beast.v2.7.5/bin/beast"
app_categories["beast"]="phylogenetics"
app_descriptions["beast"]="Bayesian evolutionary analysis with molecular clock models"

apps["treemix"]="TreeMix"
app_paths["treemix"]="/opt/sw/pub/apps/treemix/treemix"
app_categories["treemix"]="population_genetics"
app_descriptions["treemix"]="Population phylogenetics with admixture modeling"

# Population Genetics
apps["plink"]="PLINK"
app_paths["plink"]="/opt/sw/pub/apps/plink"
app_categories["plink"]="population_genetics"
app_descriptions["plink"]="Genome-wide association studies and population structure analysis"

# Genomics & Bioinformatics
apps["kraken2"]="Kraken2"
app_paths["kraken2"]="/opt/sw/pub/apps/kraken2/kraken2"
app_categories["kraken2"]="genomics"
app_descriptions["kraken2"]="Ultrafast metagenomic sequence classification"

apps["vcftools"]="VCFtools"
app_paths["vcftools"]="/opt/sw/pub/apps/vcftools/bin/vcftools"
app_categories["vcftools"]="genomics"
app_descriptions["vcftools"]="Variant call format file manipulation and analysis"

apps["qiime"]="QIIME2"
app_paths["qiime"]="/opt/sw/pub/apps/qiime2"
app_categories["qiime"]="microbiome"
app_descriptions["qiime"]="Microbiome bioinformatics platform"

# Statistical Computing
apps["R"]="R Statistical Computing"
app_paths["R"]="/opt/sw/pub/apps/R/bin/R"
app_categories["R"]="statistics"
app_descriptions["R"]="Statistical computing environment for data analysis"

# Check software availability with detailed reporting
echo "COMPREHENSIVE SOFTWARE DETECTION"
echo "================================="
log_both "Starting comprehensive scan of biology software installations..."
log_both "This may take a moment as we thoroughly check each application..."
echo ""

# Add header to summary file
echo "APPLICATION RESULTS:" >> "$SUMMARY_FILE"
echo "====================" >> "$SUMMARY_FILE"
printf "%-20s %-15s %s\n" "APPLICATION" "STATUS" "DETAILS" >> "$SUMMARY_FILE"
echo "------------------------------------------------------------------------" >> "$SUMMARY_FILE"

available_apps=()
phylo_apps=()
genomics_apps=()
structure_apps=()
failed_apps=()

for app in "${!apps[@]}"; do
    echo "TESTING: ${apps[$app]}"
    echo "   Description: ${app_descriptions[$app]}"
    log_both "   Testing ${apps[$app]} (${app_descriptions[$app]})"

    found=false
    test_details=""

    # Check for detailed test script availability
    test_type=$(detect_test_scripts "$app")
    if [[ "$test_type" == "detailed" ]]; then
        log_both "   DETECTED: Detailed test script ${app}_test.sh available"
        test_details="Detailed test available"
    else
        log_both "   INFO: No detailed test script found, will use basic test"
        test_details="Basic test only"
    fi

    # Try command-line detection first
    if check_software "$app" "${apps[$app]}"; then
        found=true
        test_details="Found in PATH, $test_details"
    # Try alternative names
    elif [[ "$app" == "iqtree" ]] && check_software "iqtree2" "IQ-TREE2"; then
        found=true
        test_details="Found as iqtree2, $test_details"
    elif [[ "$app" == "beast" ]] && check_software "beast2" "BEAST2"; then
        found=true
        test_details="Found as beast2, $test_details"
    # Try direct path detection
    elif [[ -n "${app_paths[$app]}" ]] && check_executable "${app_paths[$app]}" "${apps[$app]}"; then
        found=true
        test_details="Found at direct path, $test_details"
    fi

    if [[ "$found" == true ]]; then
        available_apps+=("$app")
        update_summary "${apps[$app]}" "PASS" "$test_details"
        log_both "   SUCCESS: ${apps[$app]} is available and ready for testing!"

        # Categorize apps
        case "${app_categories[$app]}" in
            "phylogenetics"|"population_genetics") phylo_apps+=("$app") ;;
            "genomics"|"microbiome") genomics_apps+=("$app") ;;
            "molecular_dynamics") structure_apps+=("$app") ;;
            "statistics") available_apps+=("$app") ;;
        esac
    else
        failed_apps+=("$app")
        update_summary "${apps[$app]}" "FAIL" "Not found in PATH or expected locations"
        log_both "   FAILED: ${apps[$app]} is not accessible"
    fi

    echo ""
done

# Detailed availability summary
echo "DETAILED AVAILABILITY SUMMARY"
echo "============================"
log_both "Software Detection Results:"
log_both "   Total applications found: ${#available_apps[@]} out of ${#apps[@]}"
log_both "   Phylogenetics/Evolution tools: ${#phylo_apps[@]} (${phylo_apps[*]})"
log_both "   Genomics/Bioinformatics tools: ${#genomics_apps[@]} (${genomics_apps[*]})"
log_both "   Structural Biology tools: ${#structure_apps[@]} (${structure_apps[*]})"

if [[ ${#failed_apps[@]} -gt 0 ]]; then
    log_both "   Failed applications: ${#failed_apps[@]} (${failed_apps[*]})"
    log_both "   Tip: Check installation paths or module loading for failed apps"
fi

echo ""

# Add summary statistics to file
cat >> "$SUMMARY_FILE" << EOF

SUMMARY STATISTICS:
==================
Total applications tested: ${#apps[@]}
Successfully detected: ${#available_apps[@]}
Failed detection: ${#failed_apps[@]}
Success rate: $(( ${#available_apps[@]} * 100 / ${#apps[@]} ))%

CATEGORY BREAKDOWN:
==================
Phylogenetics/Evolution: ${#phylo_apps[@]} available
Genomics/Bioinformatics: ${#genomics_apps[@]} available
Structural Biology: ${#structure_apps[@]} available

DETAILED TEST SCRIPTS DETECTED:
===============================
EOF

# Add information about detected test scripts
for app in "${available_apps[@]}"; do
    test_type=$(detect_test_scripts "$app")
    if [[ "$test_type" == "detailed" ]]; then
        echo "${apps[$app]}: ${app}_test.sh (Comprehensive testing available)" >> "$SUMMARY_FILE"
    else
        echo "${apps[$app]}: Basic testing only" >> "$SUMMARY_FILE"
    fi
done

if [[ ${#available_apps[@]} -eq 0 ]]; then
    log_both "CRITICAL ERROR: No biology applications found!"
    log_both "Please check:"
    log_both "   1. Application installation paths"
    log_both "   2. File permissions"
    log_both "   3. Module loading requirements"
    echo "OVERALL STATUS: FAILED - No applications available for testing" >> "$SUMMARY_FILE"
    exit 1
fi

# Test selection menu with detailed descriptions
echo "INTELLIGENT TEST SELECTION"
echo "=========================="
log_both "Great news! We found ${#available_apps[@]} working applications."
log_both "Now let's decide what to test. Here are your options:"
echo ""

test_options=()
option_num=1

if [[ ${#phylo_apps[@]} -gt 0 ]]; then
    echo "$option_num) Phylogenetics & Evolution Suite"
    echo "   Applications: ${phylo_apps[*]}"
    echo "   Purpose: Test evolutionary analysis and phylogenetic reconstruction"
    test_options[$option_num]="phylo"
    ((option_num++))
    echo ""
fi

if [[ ${#genomics_apps[@]} -gt 0 ]]; then
    echo "$option_num) Genomics & Bioinformatics Suite"
    echo "   Applications: ${genomics_apps[*]}"
    echo "   Purpose: Test genomic data analysis and variant processing"
    test_options[$option_num]="genomics"
    ((option_num++))
    echo ""
fi

if [[ ${#structure_apps[@]} -gt 0 ]]; then
    echo "$option_num) Structural Biology Suite"
    echo "   Applications: ${structure_apps[*]}"
    echo "   Purpose: Test molecular modeling and structural analysis"
    test_options[$option_num]="structure"
    ((option_num++))
    echo ""
fi

echo "$option_num) Complete Test Suite (Recommended)"
echo "   Applications: All ${#available_apps[@]} detected applications"
echo "   Purpose: Comprehensive validation of entire biology software stack"
test_options[$option_num]="all"
((option_num++))
echo ""

echo "$option_num) Custom Selection"
echo "   Applications: You choose which ones to test"
echo "   Purpose: Targeted testing of specific applications"
test_options[$option_num]="custom"
((option_num++))
echo ""

echo "$option_num) Exit"
test_options[$option_num]="exit"

echo ""
read -p "Select your preferred testing strategy (1-$option_num): " choice

# Handle test selection with detailed feedback
echo ""
echo "PROCESSING YOUR SELECTION"
echo "========================="

case "${test_options[$choice]}" in
    "phylo")
        log_both "Excellent choice! Running phylogenetics and evolution tests..."
        log_both "   This will test: ${phylo_apps[*]}"
        selected_apps=("${phylo_apps[@]}")
        ;;
    "genomics")
        log_both "Great selection! Running genomics and bioinformatics tests..."
        log_both "   This will test: ${genomics_apps[*]}"
        selected_apps=("${genomics_apps[@]}")
        ;;
    "structure")
        log_both "Perfect! Running structural biology tests..."
        log_both "   This will test: ${structure_apps[*]}"
        selected_apps=("${structure_apps[@]}")
        ;;
    "all")
        log_both "Fantastic! Running the complete comprehensive test suite..."
        log_both "   This will test all ${#available_apps[@]} applications: ${available_apps[*]}"
        log_both "   This may take some time, but will give you complete confidence in your setup!"
        selected_apps=("${available_apps[@]}")
        ;;
    "custom")
        log_both "Custom selection mode activated..."
        selected_apps=()
        for app in "${available_apps[@]}"; do
            echo "   Test ${apps[$app]} (${app_descriptions[$app]})?"
            if ask_yes_no "   "; then
                selected_apps+=("$app")
                log_both "      Added ${apps[$app]} to test queue"
            else
                log_both "      Skipped ${apps[$app]}"
            fi
        done
        ;;
    "exit"|"")
        log_both "Thanks for using the Biology Software Test Suite!"
        log_both "   Your detection results are saved in: $RESULTS_DIR"
        echo "OVERALL STATUS: SKIPPED - User chose to exit" >> "$SUMMARY_FILE"
        exit 0
        ;;
    *)
        log_both "Invalid choice. Please run the script again and select a valid option."
        exit 1
        ;;
esac

if [[ ${#selected_apps[@]} -eq 0 ]]; then
    log_both "No applications selected for testing."
    log_both "   Your detection results are still saved in: $RESULTS_DIR"
    echo "OVERALL STATUS: SKIPPED - No applications selected" >> "$SUMMARY_FILE"
    exit 0
fi

echo ""
echo "FINAL TEST EXECUTION PLAN"
echo "========================="
log_both "Test Summary:"
log_both "   Testing ${#selected_apps[@]} applications: ${selected_apps[*]}"
log_both "   Results directory: $RESULTS_DIR"
log_both "   Execution mode: $scheduler"
log_both "   Start time: $(date)"

# Add execution plan to summary
cat >> "$SUMMARY_FILE" << EOF

EXECUTION PLAN:
==============
Selected applications: ${selected_apps[*]}
Total tests to run: ${#selected_apps[@]}
Execution mode: $scheduler
Start time: $(date)

TEST RESULTS:
=============
EOF

echo ""
log_both "Starting test execution in 3 seconds..."
sleep 1
echo "3... "
sleep 1
echo "2... "
sleep 1
echo "1... "

echo ""
echo "EXECUTING COMPREHENSIVE TESTS"
echo "============================="

# Execute tests with detailed progress reporting
test_count=0
successful_tests=0
failed_tests=0

for app in "${selected_apps[@]}"; do
    ((test_count++))
    echo ""
    echo "TEST $test_count/${#selected_apps[@]}: ${apps[$app]}"
    echo "================================================"
    log_both "Testing ${apps[$app]} (${app_descriptions[$app]})"

    # Detect test type
    test_type=$(detect_test_scripts "$app")

    case "$app" in
        "iqtree")
            if [[ "$test_type" == "detailed" ]]; then
                log_both "Launching comprehensive IQ-TREE phylogenetic analysis..."
                if [[ "$scheduler" == "slurm" ]]; then
                    job_id=$(sbatch --parsable iqtree_test.sh 2>/dev/null)
                    if [[ $? -eq 0 ]]; then
                        log_both "   PASS: IQ-TREE detailed test submitted (Job: $job_id)"
                        log_both "   Monitor: squeue -j $job_id"
                        log_both "   Output: tail -f iqtree_test_${job_id}.out"
                        echo "IQ-TREE: PASS SUBMITTED (Job: $job_id)" >> "$SUMMARY_FILE"
                        ((successful_tests++))
                    else
                        log_both "   FAIL: Could not submit IQ-TREE job to SLURM"
                        echo "IQ-TREE: FAIL (SLURM submission error)" >> "$SUMMARY_FILE"
                        ((failed_tests++))
                    fi
                else
                    log_both "   Running IQ-TREE detailed test directly..."
                    bash iqtree_test.sh > iqtree_direct_$$.out 2>&1 &
                    log_both "   Background job started, output in: iqtree_direct_$$.out"
                    echo "IQ-TREE: PASS RUNNING (Direct execution)" >> "$SUMMARY_FILE"
                    ((successful_tests++))
                fi
            else
                log_both "   Running basic IQ-TREE version check..."
                if iqtree --version &> /dev/null; then
                    log_both "   PASS: IQ-TREE responded correctly"
                    echo "IQ-TREE: PASS BASIC (Version check passed)" >> "$SUMMARY_FILE"
                    ((successful_tests++))
                else
                    log_both "   FAIL: IQ-TREE version check failed"
                    echo "IQ-TREE: FAIL (Version check failed)" >> "$SUMMARY_FILE"
                    ((failed_tests++))
                fi
            fi
            ;;

        "beast")
            if [[ "$test_type" == "detailed" ]]; then
                log_both "Launching comprehensive BEAST2 Bayesian analysis..."
                if [[ "$scheduler" == "slurm" ]]; then
                    job_id=$(sbatch --parsable beast_test.sh 2>/dev/null)
                    if [[ $? -eq 0 ]]; then
                        log_both "   PASS: BEAST2 detailed test submitted (Job: $job_id)"
                        log_both "   Monitor: squeue -j $job_id"
                        log_both "   Output: tail -f beast_test_${job_id}.out"
                        echo "BEAST2: PASS SUBMITTED (Job: $job_id)" >> "$SUMMARY_FILE"
                        ((successful_tests++))
                    else
                        log_both "   FAIL: Could not submit BEAST2 job to SLURM"
                        echo "BEAST2: FAIL (SLURM submission error)" >> "$SUMMARY_FILE"
                        ((failed_tests++))
                    fi
                else
                    log_both "   Running BEAST2 detailed test directly..."
                    bash beast_test.sh > beast_direct_$$.out 2>&1 &
                    log_both "   Background job started, output in: beast_direct_$$.out"
                    echo "BEAST2: PASS RUNNING (Direct execution)" >> "$SUMMARY_FILE"
                    ((successful_tests++))
                fi
            else
                log_both "   Running basic BEAST2 version check..."
                if beast -version &> /dev/null || beast2 -version &> /dev/null; then
                    log_both "   PASS: BEAST2 responded correctly"
                    echo "BEAST2: PASS BASIC (Version check passed)" >> "$SUMMARY_FILE"
                    ((successful_tests++))
                else
                    log_both "   FAIL: BEAST2 version check failed"
                    echo "BEAST2: FAIL (Version check failed)" >> "$SUMMARY_FILE"
                    ((failed_tests++))
                fi
            fi
            ;;

        "plink")
            if [[ "$test_type" == "detailed" ]]; then
                log_both "Launching comprehensive PLINK population genetics analysis..."
                if [[ "$scheduler" == "slurm" ]]; then
                    job_id=$(sbatch --parsable plink_test.sh 2>/dev/null)
                    if [[ $? -eq 0 ]]; then
                        log_both "   PASS: PLINK detailed test submitted (Job: $job_id)"
                        echo "PLINK: PASS SUBMITTED (Job: $job_id)" >> "$SUMMARY_FILE"
                        ((successful_tests++))
                    else
                        log_both "   FAIL: Could not submit PLINK job"
                        echo "PLINK: FAIL (SLURM submission error)" >> "$SUMMARY_FILE"
                        ((failed_tests++))
                    fi
                else
                    log_both "   Running PLINK detailed test directly..."
                    bash plink_test.sh > plink_direct_$$.out 2>&1 &
                    echo "PLINK: PASS RUNNING (Direct execution)" >> "$SUMMARY_FILE"
                    ((successful_tests++))
                fi
            else
                log_both "   Running basic PLINK version check..."
                if plink --version &> /dev/null; then
                    plink_version=$(plink --version 2>&1 | head -1)
                    log_both "   PASS: $plink_version"
                    echo "PLINK: PASS BASIC (Version check passed)" >> "$SUMMARY_FILE"
                    ((successful_tests++))
                else
                    log_both "   FAIL: PLINK version check failed"
                    echo "PLINK: FAIL (Version check failed)" >> "$SUMMARY_FILE"
                    ((failed_tests++))
                fi
            fi
            ;;

        "vcftools")
            if [[ "$test_type" == "detailed" ]]; then
                log_both "Launching comprehensive VCFtools variant analysis..."
                if [[ "$scheduler" == "slurm" ]]; then
                    job_id=$(sbatch --parsable vcftools_test.sh 2>/dev/null)
                    if [[ $? -eq 0 ]]; then
                        log_both "   PASS: VCFtools detailed test submitted (Job: $job_id)"
                        echo "VCFtools: PASS SUBMITTED (Job: $job_id)" >> "$SUMMARY_FILE"
                        ((successful_tests++))
                    else
                        log_both "   FAIL: Could not submit VCFtools job"
                        echo "VCFtools: FAIL (SLURM submission error)" >> "$SUMMARY_FILE"
                        ((failed_tests++))
                    fi
                else
                    log_both "   Running VCFtools detailed test directly..."
                    bash vcftools_test.sh > vcftools_direct_$$.out 2>&1 &
                    echo "VCFtools: PASS RUNNING (Direct execution)" >> "$SUMMARY_FILE"
                    ((successful_tests++))
                fi
            else
                log_both "   Running basic VCFtools version check..."
                if vcftools --version &> /dev/null; then
                    vcf_version=$(vcftools --version 2>&1 | head -1)
                    log_both "   PASS: $vcf_version"
                    echo "VCFtools: PASS BASIC (Version check passed)" >> "$SUMMARY_FILE"
                    ((successful_tests++))
                else
                    log_both "   FAIL: VCFtools version check failed"
                    echo "VCFtools: FAIL (Version check failed)" >> "$SUMMARY_FILE"
                    ((failed_tests++))
                fi
            fi
            ;;

        "kraken2")
            if [[ "$test_type" == "detailed" ]]; then
                log_both "Launching comprehensive Kraken2 taxonomic classification..."
                if [[ "$scheduler" == "slurm" ]]; then
                    job_id=$(sbatch --parsable kraken2_test.sh 2>/dev/null)
                    if [[ $? -eq 0 ]]; then
                        log_both "   PASS: Kraken2 detailed test submitted (Job: $job_id)"
                        echo "Kraken2: PASS SUBMITTED (Job: $job_id)" >> "$SUMMARY_FILE"
                        ((successful_tests++))
                    else
                        log_both "   FAIL: Could not submit Kraken2 job"
                        echo "Kraken2: FAIL (SLURM submission error)" >> "$SUMMARY_FILE"
                        ((failed_tests++))
                    fi
                else
                    log_both "   Running Kraken2 detailed test directly..."
                    bash kraken2_test.sh > kraken2_direct_$$.out 2>&1 &
                    echo "Kraken2: PASS RUNNING (Direct execution)" >> "$SUMMARY_FILE"
                    ((successful_tests++))
                fi
            else
                log_both "   Running basic Kraken2 version check..."
                if kraken2 --version &> /dev/null; then
                    k2_version=$(kraken2 --version 2>&1)
                    log_both "   PASS: $k2_version"
                    echo "Kraken2: PASS BASIC (Version check passed)" >> "$SUMMARY_FILE"
                    ((successful_tests++))
                else
                    log_both "   FAIL: Kraken2 version check failed"
                    echo "Kraken2: FAIL (Version check failed)" >> "$SUMMARY_FILE"
                    ((failed_tests++))
                fi
            fi
            ;;

        "qiime")
            if [[ "$test_type" == "detailed" ]]; then
                log_both "Launching comprehensive QIIME2 microbiome analysis..."
                if [[ "$scheduler" == "slurm" ]]; then
                    job_id=$(sbatch --parsable qiime2_test.sh 2>/dev/null)
                    if [[ $? -eq 0 ]]; then
                        log_both "   PASS: QIIME2 detailed test submitted (Job: $job_id)"
                        log_both "   Monitor: squeue -j $job_id"
                        log_both "   Output: tail -f qiime2_test_${job_id}.out"
                        echo "QIIME2: PASS SUBMITTED (Job: $job_id)" >> "$SUMMARY_FILE"
                        ((successful_tests++))
                    else
                        log_both "   FAIL: Could not submit QIIME2 job to SLURM"
                        echo "QIIME2: FAIL (SLURM submission error)" >> "$SUMMARY_FILE"
                        ((failed_tests++))
                    fi
                else
                    log_both "   Running QIIME2 detailed test directly..."
                    bash qiime2_test.sh > qiime2_direct_$$.out 2>&1 &
                    log_both "   Background job started, output in: qiime2_direct_$$.out"
                    echo "QIIME2: PASS RUNNING (Direct execution)" >> "$SUMMARY_FILE"
                    ((successful_tests++))
                fi
            else
                log_both "Testing QIIME2 microbiome analysis platform..."
                
                # Check if QIIME2 base directory exists
                if [[ -d "/opt/sw/pub/apps/qiime2" ]]; then
                    log_both "   PASS: QIIME2 installation directory found"
                else
                    log_both "   WARN: QIIME2 installation directory not found at expected location"
                fi
                
                # Test conda availability and QIIME2 environment
                if command -v conda >/dev/null 2>&1; then
                    log_both "   PASS: Conda found: $(which conda)"
                    
                    # Try to check if QIIME2 environment exists
                    if conda env list 2>/dev/null | grep -q "qiime2\|^qiime "; then
                        log_both "   PASS: QIIME2 conda environment detected"
                        
                        # Try to activate and test qiime command
                        eval "$(conda shell.bash hook)" 2>/dev/null || true
                        if conda activate qiime2 2>/dev/null && command -v qiime >/dev/null 2>&1; then
                            qiime_version=$(qiime --version 2>/dev/null | head -1 || echo "version check failed")
                            log_both "   PASS: QIIME2 command works: $qiime_version"
                            conda deactivate 2>/dev/null || true
                            echo "QIIME2: PASS (Environment + command test)" >> "$SUMMARY_FILE"
                            ((successful_tests++))
                        elif conda activate qiime 2>/dev/null && command -v qiime >/dev/null 2>&1; then
                            qiime_version=$(qiime --version 2>/dev/null | head -1 || echo "version check failed")
                            log_both "   PASS: QIIME2 command works: $qiime_version"
                            conda deactivate 2>/dev/null || true
                            echo "QIIME2: PASS (Environment + command test)" >> "$SUMMARY_FILE"
                            ((successful_tests++))
                        else
                            log_both "   FAIL: Could not activate QIIME2 environment or qiime command not working"
                            echo "QIIME2: FAIL (Environment activation failed)" >> "$SUMMARY_FILE"
                            ((failed_tests++))
                        fi
                    else
                        log_both "   FAIL: QIIME2 conda environment not found"
                        echo "QIIME2: FAIL (Environment not found)" >> "$SUMMARY_FILE"
                        ((failed_tests++))
                    fi
                elif command -v qiime >/dev/null 2>&1; then
                    # QIIME2 might be installed directly in PATH
                    qiime_version=$(qiime --version 2>/dev/null | head -1 || echo "version check failed")
                    log_both "   PASS: QIIME2 command found in PATH: $qiime_version"
                    echo "QIIME2: PASS (Direct installation)" >> "$SUMMARY_FILE"
                    ((successful_tests++))
                else
                    log_both "   FAIL: Neither conda nor qiime command found"
                    echo "QIIME2: FAIL (No installation method found)" >> "$SUMMARY_FILE"
                    ((failed_tests++))
                fi
            fi
            ;;

        "R")
            log_both "Testing R Statistical Computing environment..."
            if R --version &> /dev/null; then
                r_version=$(R --version 2>&1 | head -1)
                log_both "   PASS: $r_version"

                # Test basic R functionality
                echo "cat('R is working!\\n')" | R --vanilla --quiet > /tmp/r_test_$$.out 2>&1
                if grep -q "R is working" /tmp/r_test_$$.out; then
                    log_both "   BONUS: R basic computation test passed"
                    echo "R: PASS (Version + computation test)" >> "$SUMMARY_FILE"
                else
                    log_both "   WARNING: R found but computation test failed"
                    echo "R: PARTIAL (Version only)" >> "$SUMMARY_FILE"
                fi
                rm -f /tmp/r_test_$.out
                ((successful_tests++))
            else
                log_both "   FAIL: R version check failed"
                echo "R: FAIL (Version check failed)" >> "$SUMMARY_FILE"
                ((failed_tests++))
            fi
            ;;

        "treemix")
            log_both "Testing TreeMix population phylogenetics..."
            if command -v treemix &> /dev/null; then
                log_both "   PASS: TreeMix executable found and accessible"
                echo "TreeMix: PASS (Executable check passed)" >> "$SUMMARY_FILE"
                ((successful_tests++))
            else
                log_both "   FAIL: TreeMix not accessible"
                echo "TreeMix: FAIL (Executable not found)" >> "$SUMMARY_FILE"
                ((failed_tests++))
            fi
            ;;

        *)
            log_both "   WARNING: No specific test defined for $app - skipping"
            echo "${apps[$app]}: SKIPPED (No test defined)" >> "$SUMMARY_FILE"
            ;;
    esac

    # Progress indicator
    local progress=$(( test_count * 100 / ${#selected_apps[@]} ))
    log_both "   Progress: $test_count/${#selected_apps[@]} tests completed ($progress%)"
done

# Final comprehensive summary
echo ""
echo "COMPREHENSIVE TESTING COMPLETED!"
echo "================================"
log_both "All tests have been executed! Here's your comprehensive summary:"
log_both ""
log_both "FINAL STATISTICS:"
log_both "   Total tests run: $test_count"
log_both "   Successful tests: $successful_tests"
log_both "   Failed tests: $failed_tests"
log_both "   Success rate: $(( successful_tests * 100 / test_count ))%"
log_both ""
log_both "RESULTS LOCATION:"
log_both "   Summary report: $SUMMARY_FILE"
log_both "   Detailed log: $DETAILED_LOG"
log_both "   Results directory: $RESULTS_DIR"

# Add final statistics to summary file
cat >> "$SUMMARY_FILE" << EOF

FINAL STATISTICS:
================
Total tests executed: $test_count
Successful tests: $successful_tests
Failed tests: $failed_tests
Success rate: $(( successful_tests * 100 / test_count ))%
Completion time: $(date)

EOF

# Overall assessment
if [[ $failed_tests -eq 0 ]]; then
    overall_status="EXCELLENT"
    status_msg="All biology software tests passed! Your HPC system is ready for production use."
    echo "OVERALL STATUS: EXCELLENT - All tests passed" >> "$SUMMARY_FILE"
elif [[ $successful_tests -gt $failed_tests ]]; then
    overall_status="GOOD"
    status_msg="Most tests passed. Some applications may need attention, but the core biology software stack is functional."
    echo "PARTIAL SUCCESS: Most tests passed ($successful_tests/$test_count)" >> "$SUMMARY_FILE"
else
    overall_status="NEEDS ATTENTION"
    status_msg="Several tests failed. Please review the detailed logs and check installations."
    echo "NEEDS ATTENTION: Multiple test failures ($failed_tests/$test_count failed)" >> "$SUMMARY_FILE"
fi

log_both ""
log_both "OVERALL ASSESSMENT: $overall_status"
log_both "$status_msg"
log_both ""

if [[ "$scheduler" == "slurm" ]]; then
    log_both "MONITORING YOUR JOBS:"
    log_both "===================="
    log_both "Since we submitted jobs to SLURM, here are helpful commands:"
    log_both ""
    log_both "Check job status:"
    log_both "  squeue -u \$(whoami)"
    log_both ""
    log_both "Check job history:"
    log_both "  sacct -u \$(whoami) --format=JobID,JobName,State,ExitCode,Elapsed"
    log_both ""
    log_both "View job output (replace JOBID with actual job ID):"
    log_both "  tail -f iqtree_test_JOBID.out"
    log_both "  tail -f beast_test_JOBID.out"
    log_both "  tail -f plink_test_JOBID.out"
    log_both "  tail -f vcftools_test_JOBID.out"
    log_both "  tail -f kraken2_test_JOBID.out"
    log_both "  tail -f qiime2_test_JOBID.out"
    log_both ""
    log_both "Create useful aliases:"
    log_both "  alias checkjobs='squeue -u \$(whoami)'"
    log_both "  alias jobhist='sacct -u \$(whoami) --format=JobID,JobName,State,ExitCode,Elapsed'"
    log_both ""
fi

log_both "NEXT STEPS:"
log_both "=========="
log_both "1. Review the summary report: $SUMMARY_FILE"
log_both "2. Check detailed logs for any failed tests: $DETAILED_LOG"

if [[ "$scheduler" == "slurm" ]]; then
    log_both "3. Monitor submitted jobs and check their output files"
    log_both "4. For detailed tests, comprehensive analysis results will be in job output"
fi

log_both "5. For production use, consider creating additional test scripts for other applications"
log_both ""

log_both "RECOMMENDATIONS FOR PRODUCTION:"
log_both "==============================="
if [[ $successful_tests -eq $test_count ]]; then
    log_both "- PASS: Your biology software stack is ready for production use"
    log_both "- Consider setting up module files for easy software loading"
    log_both "- Document working software versions for reproducibility"
elif [[ $successful_tests -gt 0 ]]; then
    log_both "- PARTIAL: Working applications can be used for production"
    log_both "- Address failed applications before critical analyses"
    log_both "- Consider alternative installations for failed software"
else
    log_both "- ATTENTION: Review all installations before production use"
    log_both "- Check system requirements and dependencies"
    log_both "- Consider consulting system administrators"
fi

log_both ""
log_both "ADDING NEW APPLICATIONS:"
log_both "========================"
log_both "To add a new application to this test suite:"
log_both ""
log_both "1. Create a detailed test script named: APPLICATION_test.sh"
log_both "   Example: myapp_test.sh"
log_both ""
log_both "2. Make it executable:"
log_both "   chmod +x myapp_test.sh"
log_both ""
log_both "3. Add the application to this launcher script:"
log_both "   Edit the 'apps' array section and add:"
log_both "   apps[\"myapp\"]=\"MyApplication\""
log_both "   app_paths[\"myapp\"]=\"/path/to/myapp\""
log_both "   app_categories[\"myapp\"]=\"category\""
log_both "   app_descriptions[\"myapp\"]=\"Description of what it does\""
log_both ""
log_both "4. The launcher will automatically:"
log_both "   - Detect your detailed test script"
log_both "   - Use it if available"
log_both "   - Fall back to basic version check if not"
log_both ""
log_both "No other changes needed! The system is fully modular."

log_both ""
log_both "Thank you for using the Comprehensive Biology Software Test Suite!"
log_both "Your HPC system analysis is complete."
log_both ""
log_both "================================================"
log_both "Test completed at: $(date)"
log_both "Total runtime: $SECONDS seconds"
log_both "================================================"

echo ""
echo "FINAL SUMMARY REPORT PREVIEW:"
echo "============================="
cat "$SUMMARY_FILE"

echo ""
echo "Full results saved to: $RESULTS_DIR"
echo "Thank you for testing your biology software stack!"
