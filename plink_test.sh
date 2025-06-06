#!/bin/bash
#SBATCH --job-name=plink_test
#SBATCH --output=plink_test_%j.out
#SBATCH --error=plink_test_%j.err
#SBATCH --time=00:30:00
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=2
#SBATCH --mem=2GB
#SBATCH --partition=testing

# PLINK population genetics test script

echo "=== PLINK Population Genetics Test ==="
echo "Job ID: $SLURM_JOB_ID"
echo "Node: $SLURMD_NODENAME"
echo "Date: $(date)"
echo "Working directory: $(pwd)"
echo "======================================"

# Set up application paths
export PATH="/opt/sw/pub/apps:$PATH"

# Load modules if needed (uncomment and modify as needed)
# module load plink

# Create working directory
WORK_DIR="plink_test_${SLURM_JOB_ID}"
mkdir -p $WORK_DIR
cd $WORK_DIR

echo "Working in directory: $(pwd)"

# Check if PLINK is available
echo -e "\n1. CHECKING PLINK INSTALLATION"
echo "=============================="
if command -v plink &> /dev/null; then
    echo "PASS: PLINK found: $(which plink)"
    plink --version | head -5
    PLINK_CMD="plink"
elif command -v plink2 &> /dev/null; then
    echo "PASS: PLINK2 found: $(which plink2)"
    plink2 --version | head -5
    PLINK_CMD="plink2"
else
    echo "FAIL: PLINK not found in PATH"
    echo "Please ensure PLINK is installed and available"
    exit 1
fi

# Create test dataset
echo -e "\n2. CREATING TEST DATASET"
echo "========================"
echo "Generating synthetic population genetics data for testing..."

# Create simple PED file (simulated data for 10 individuals, 5 SNPs)
cat > test_data.ped << 'EOF'
FAM001 IND001 0 0 1 2 1 1 2 2 1 2 2 1 1 1
FAM001 IND002 0 0 1 2 1 2 2 2 1 1 2 2 1 2
FAM002 IND003 0 0 2 1 2 1 1 1 2 2 1 1 2 2
FAM002 IND004 0 0 2 1 1 1 1 2 2 1 1 2 2 1
FAM003 IND005 0 0 1 1 1 2 2 1 1 2 2 2 1 1
FAM003 IND006 0 0 1 2 2 1 1 1 2 2 1 1 2 2
FAM004 IND007 0 0 2 2 1 1 2 2 1 1 2 1 1 2
FAM004 IND008 0 0 2 1 2 2 1 1 1 2 2 2 1 1
FAM005 IND009 0 0 1 1 1 1 2 2 2 1 1 2 2 2
FAM005 IND010 0 0 1 2 2 2 1 1 1 1 2 2 2 1
EOF

# Create corresponding MAP file
cat > test_data.map << 'EOF'
1 SNP001 0 1000
1 SNP002 0 2000
1 SNP003 0 3000
1 SNP004 0 4000
1 SNP005 0 5000
EOF

if [[ -f "test_data.ped" ]] && [[ -f "test_data.map" ]]; then
    echo "PASS: Test dataset created successfully"
    echo "  Individuals: $(wc -l < test_data.ped)"
    echo "  SNPs: $(wc -l < test_data.map)"
else
    echo "FAIL: Could not create test dataset"
    exit 1
fi

# Test 1: Basic file conversion
echo -e "\n3. BASIC FILE CONVERSION TEST"
echo "============================="
echo "Converting PED/MAP to binary format..."
$PLINK_CMD --file test_data --make-bed --out test_binary --noweb --silent

if [[ $? -eq 0 ]] && [[ -f "test_binary.bed" ]]; then
    echo "PASS: Binary file conversion successful"
    echo "  Files created: test_binary.bed, test_binary.bim, test_binary.fam"
else
    echo "FAIL: Binary file conversion failed"
    exit 1
fi

# Test 2: Basic statistics
echo -e "\n4. BASIC STATISTICS TEST"
echo "========================"
echo "Calculating allele frequencies and missing data rates..."
$PLINK_CMD --bfile test_binary --freq --missing --out basic_stats --noweb --silent

if [[ $? -eq 0 ]] && [[ -f "basic_stats.frq" ]]; then
    echo "PASS: Basic statistics calculation successful"
    echo "  Frequency file: basic_stats.frq"
    echo "  Missing data file: basic_stats.lmiss"
    
    # Show sample of results
    echo "  Sample allele frequencies:"
    head -3 basic_stats.frq
else
    echo "FAIL: Basic statistics calculation failed"
fi

# Test 3: Quality control filtering
echo -e "\n5. QUALITY CONTROL FILTERING TEST"
echo "================================="
echo "Applying basic QC filters..."
$PLINK_CMD --bfile test_binary --maf 0.01 --geno 0.1 --mind 0.1 --make-bed --out qc_filtered --noweb --silent

if [[ $? -eq 0 ]] && [[ -f "qc_filtered.bed" ]]; then
    echo "PASS: Quality control filtering successful"
    
    # Compare before/after
    orig_snps=$(wc -l < test_binary.bim)
    filt_snps=$(wc -l < qc_filtered.bim)
    echo "  SNPs before QC: $orig_snps"
    echo "  SNPs after QC: $filt_snps"
else
    echo "FAIL: Quality control filtering failed"
fi

# Test 4: Hardy-Weinberg equilibrium test
echo -e "\n6. HARDY-WEINBERG EQUILIBRIUM TEST"
echo "=================================="
echo "Testing for Hardy-Weinberg equilibrium..."
$PLINK_CMD --bfile test_binary --hardy --out hwe_test --noweb --silent

if [[ $? -eq 0 ]] && [[ -f "hwe_test.hwe" ]]; then
    echo "PASS: Hardy-Weinberg test successful"
    echo "  Results file: hwe_test.hwe"
    
    # Show sample results
    if [[ -s "hwe_test.hwe" ]]; then
        echo "  Sample HWE results:"
        head -3 hwe_test.hwe
    fi
else
    echo "FAIL: Hardy-Weinberg test failed"
fi

# Test 5: Linkage disequilibrium
echo -e "\n7. LINKAGE DISEQUILIBRIUM TEST"
echo "=============================="
echo "Calculating linkage disequilibrium..."
$PLINK_CMD --bfile test_binary --r2 --ld-window 5 --out ld_test --noweb --silent

if [[ $? -eq 0 ]] && [[ -f "ld_test.ld" ]]; then
    echo "PASS: Linkage disequilibrium calculation successful"
    echo "  Results file: ld_test.ld"
    
    if [[ -s "ld_test.ld" ]]; then
        echo "  Number of LD pairs: $(wc -l < ld_test.ld)"
    fi
else
    echo "FAIL: Linkage disequilibrium calculation failed"
fi

# Test 6: Population structure (if PLINK version supports it)
echo -e "\n8. POPULATION STRUCTURE TEST"
echo "============================"
echo "Testing population structure analysis..."

# Create population cluster file for testing
cat > test_clusters.txt << 'EOF'
FAM001 IND001 POP1
FAM001 IND002 POP1
FAM002 IND003 POP1
FAM002 IND004 POP1
FAM003 IND005 POP2
FAM003 IND006 POP2
FAM004 IND007 POP2
FAM004 IND008 POP2
FAM005 IND009 POP2
FAM005 IND010 POP2
EOF

$PLINK_CMD --bfile test_binary --within test_clusters.txt --fst --out fst_test --noweb --silent 2>/dev/null

if [[ $? -eq 0 ]] && [[ -f "fst_test.fst" ]]; then
    echo "PASS: Population structure analysis successful"
    echo "  FST results: fst_test.fst"
else
    echo "INFO: Population structure test skipped (may not be supported in this PLINK version)"
fi

# Test 7: Association analysis simulation
echo -e "\n9. ASSOCIATION ANALYSIS TEST"
echo "============================"
echo "Creating case-control dataset for association testing..."

# Create simple phenotype file (first 5 individuals as cases, rest as controls)
cat > test_pheno.txt << 'EOF'
FAM001 IND001 2
FAM001 IND002 2
FAM002 IND003 2
FAM002 IND004 2
FAM003 IND005 2
FAM003 IND006 1
FAM004 IND007 1
FAM004 IND008 1
FAM005 IND009 1
FAM005 IND010 1
EOF

$PLINK_CMD --bfile test_binary --pheno test_pheno.txt --assoc --out assoc_test --noweb --silent

if [[ $? -eq 0 ]] && [[ -f "assoc_test.assoc" ]]; then
    echo "PASS: Association analysis successful"
    echo "  Results file: assoc_test.assoc"
    
    if [[ -s "assoc_test.assoc" ]]; then
        echo "  Sample association results:"
        head -3 assoc_test.assoc
    fi
else
    echo "FAIL: Association analysis failed"
fi

# Performance summary
echo -e "\n10. PERFORMANCE SUMMARY"
echo "======================"
echo "Files generated:"
ls -la *.bed *.bim *.fam *.frq *.hwe *.ld *.assoc 2>/dev/null | wc -l | xargs echo "Total output files:"

echo -e "\nFile sizes:"
for file in *.bed *.bim *.fam *.log; do
    if [[ -f "$file" ]]; then
        size=$(ls -lh "$file" | awk '{print $5}')
        echo "  $file: $size"
    fi
done

# Check for errors in log files
echo -e "\n11. ERROR CHECK"
echo "==============="
error_count=0
for logfile in *.log; do
    if [[ -f "$logfile" ]] && grep -qi "error\|fail" "$logfile"; then
        echo "WARNING: Potential issues found in $logfile"
        ((error_count++))
    fi
done

if [[ $error_count -eq 0 ]]; then
    echo "PASS: No errors detected in log files"
else
    echo "WARNING: $error_count log files contain potential issues"
fi

# Final assessment
echo -e "\n12. FINAL ASSESSMENT"
echo "==================="
total_tests=9
passed_tests=0

# Count successful files as proxy for passed tests
[[ -f "test_binary.bed" ]] && ((passed_tests++))
[[ -f "basic_stats.frq" ]] && ((passed_tests++))
[[ -f "qc_filtered.bed" ]] && ((passed_tests++))
[[ -f "hwe_test.hwe" ]] && ((passed_tests++))
[[ -f "ld_test.ld" ]] && ((passed_tests++))
[[ -f "assoc_test.assoc" ]] && ((passed_tests++))

echo "Test summary:"
echo "  Total tests: $total_tests"
echo "  Passed tests: $passed_tests"
echo "  Success rate: $(( passed_tests * 100 / total_tests ))%"

if [[ $passed_tests -eq $total_tests ]]; then
    echo "EXCELLENT: All PLINK tests passed!"
    echo "PLINK is fully functional for population genetics analysis"
elif [[ $passed_tests -gt $(( total_tests / 2 )) ]]; then
    echo "GOOD: Most PLINK tests passed"
    echo "PLINK core functionality is working"
else
    echo "ATTENTION: Several PLINK tests failed"
    echo "Check installation and dependencies"
fi

echo -e "\n======================================"
echo "PLINK test completed at: $(date)"
echo "Working directory: $(pwd)"
echo "======================================"
