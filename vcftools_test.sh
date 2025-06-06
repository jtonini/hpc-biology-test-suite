#!/bin/bash
#SBATCH --job-name=vcftools_test
#SBATCH --output=vcftools_test_%j.out
#SBATCH --error=vcftools_test_%j.err
#SBATCH --time=00:30:00
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=2
#SBATCH --mem=2GB
#SBATCH --partition=testing

# VCFtools variant analysis test script

echo "=== VCFtools Variant Analysis Test ==="
echo "Job ID: $SLURM_JOB_ID"
echo "Node: $SLURMD_NODENAME"
echo "Date: $(date)"
echo "Working directory: $(pwd)"
echo "======================================"

# Set up application paths
export PATH="/opt/sw/pub/apps:$PATH"
export PATH="/opt/sw/pub/apps/vcftools/bin:$PATH"

# Load modules if needed (uncomment and modify as needed)
# module load vcftools

# Create working directory
WORK_DIR="vcftools_test_${SLURM_JOB_ID}"
mkdir -p $WORK_DIR
cd $WORK_DIR

echo "Working in directory: $(pwd)"

# Check if VCFtools is available
echo -e "\n1. CHECKING VCFTOOLS INSTALLATION"
echo "================================="
if command -v vcftools &> /dev/null; then
    echo "PASS: VCFtools found: $(which vcftools)"
    vcftools --version 2>&1 | head -3
    VCFTOOLS_CMD="vcftools"
else
    echo "FAIL: VCFtools not found in PATH"
    echo "Please ensure VCFtools is installed and available"
    exit 1
fi

# Create test VCF file
echo -e "\n2. CREATING TEST VCF DATASET"
echo "============================"
echo "Generating synthetic VCF data for testing..."

cat > test_variants.vcf << 'EOF'
##fileformat=VCFv4.2
##fileDate=20240101
##source=test_data_generator
##reference=test_genome
##contig=<ID=chr1,length=10000>
##contig=<ID=chr2,length=10000>
##INFO=<ID=DP,Number=1,Type=Integer,Description="Total Depth">
##INFO=<ID=AF,Number=A,Type=Float,Description="Allele Frequency">
##FORMAT=<ID=GT,Number=1,Type=String,Description="Genotype">
##FORMAT=<ID=DP,Number=1,Type=Integer,Description="Read Depth">
##FORMAT=<ID=GQ,Number=1,Type=Integer,Description="Genotype Quality">
#CHROM	POS	ID	REF	ALT	QUAL	FILTER	INFO	FORMAT	SAMPLE1	SAMPLE2	SAMPLE3	SAMPLE4	SAMPLE5
chr1	1000	SNP001	A	T	30	PASS	DP=100;AF=0.4	GT:DP:GQ	0/1:20:30	1/1:25:40	0/0:15:25	0/1:18:35	0/0:22:30
chr1	2000	SNP002	C	G	45	PASS	DP=120;AF=0.3	GT:DP:GQ	0/0:30:45	0/1:28:38	0/1:20:30	0/0:25:40	1/1:27:42
chr1	3000	SNP003	G	A	50	PASS	DP=80;AF=0.6	GT:DP:GQ	1/1:16:25	0/1:18:30	1/1:12:20	0/1:14:28	0/1:20:35
chr1	4000	SNP004	T	C	35	PASS	DP=90;AF=0.2	GT:DP:GQ	0/0:24:35	0/0:26:40	0/1:15:25	0/0:19:30	0/0:21:32
chr2	1500	SNP005	A	G	40	PASS	DP=110;AF=0.5	GT:DP:GQ	0/1:22:35	1/1:24:38	0/0:18:28	0/1:20:32	1/1:26:40
chr2	2500	SNP006	C	T	55	PASS	DP=95;AF=0.3	GT:DP:GQ	0/0:19:30	0/1:21:35	0/0:17:25	0/1:23:38	0/0:25:42
chr2	3500	SNP007	G	C	25	PASS	DP=75;AF=0.4	GT:DP:GQ	0/1:15:22	0/0:16:28	1/1:12:18	0/1:18:30	0/0:20:35
chr2	4500	SNP008	T	A	60	PASS	DP=130;AF=0.7	GT:DP:GQ	1/1:28:45	0/1:30:48	1/1:25:40	1/1:32:50	0/1:27:42
EOF

if [[ -f "test_variants.vcf" ]]; then
    echo "PASS: Test VCF file created successfully"
    echo "  Variants: $(grep -v '^#' test_variants.vcf | wc -l)"
    echo "  Samples: $(grep -v '^#' test_variants.vcf | head -1 | cut -f10- | wc -w)"
    echo "  Chromosomes: $(grep -v '^#' test_variants.vcf | cut -f1 | sort -u | wc -l)"
else
    echo "FAIL: Could not create test VCF file"
    exit 1
fi

# Test 1: Basic file validation
echo -e "\n3. VCF FILE VALIDATION TEST"
echo "==========================="
echo "Validating VCF file format..."
$VCFTOOLS_CMD --vcf test_variants.vcf --out validation_test

if [[ $? -eq 0 ]]; then
    echo "PASS: VCF file validation successful"
    if [[ -f "validation_test.log" ]]; then
        echo "  Log file created: validation_test.log"
    fi
else
    echo "FAIL: VCF file validation failed"
fi

# Test 2: Basic statistics
echo -e "\n4. BASIC VARIANT STATISTICS"
echo "==========================="
echo "Calculating basic variant statistics..."
$VCFTOOLS_CMD --vcf test_variants.vcf --freq --out freq_stats

if [[ $? -eq 0 ]] && [[ -f "freq_stats.frq" ]]; then
    echo "PASS: Frequency calculation successful"
    echo "  Frequency file: freq_stats.frq"
    
    # Show sample frequencies
    echo "  Sample allele frequencies:"
    head -3 freq_stats.frq
else
    echo "FAIL: Frequency calculation failed"
fi

# Test 3: Site quality filtering
echo -e "\n5. QUALITY FILTERING TEST"
echo "========================="
echo "Filtering variants by quality..."
$VCFTOOLS_CMD --vcf test_variants.vcf --minQ 30 --recode --out quality_filtered

if [[ $? -eq 0 ]] && [[ -f "quality_filtered.recode.vcf" ]]; then
    echo "PASS: Quality filtering successful"
    
    orig_vars=$(grep -v '^#' test_variants.vcf | wc -l)
    filt_vars=$(grep -v '^#' quality_filtered.recode.vcf | wc -l)
    echo "  Variants before filtering: $orig_vars"
    echo "  Variants after filtering: $filt_vars"
else
    echo "FAIL: Quality filtering failed"
fi

# Test 4: Depth statistics
echo -e "\n6. DEPTH STATISTICS TEST"
echo "========================"
echo "Calculating depth statistics..."
$VCFTOOLS_CMD --vcf test_variants.vcf --depth --out depth_stats

if [[ $? -eq 0 ]] && [[ -f "depth_stats.idepth" ]]; then
    echo "PASS: Depth calculation successful"
    echo "  Individual depth file: depth_stats.idepth"
    
    # Show sample depth stats
    if [[ -s "depth_stats.idepth" ]]; then
        echo "  Sample depth statistics:"
        head -3 depth_stats.idepth
    fi
else
    echo "FAIL: Depth calculation failed"
fi

# Test 5: Site depth statistics
echo -e "\n7. SITE DEPTH STATISTICS TEST"
echo "============================="
echo "Calculating per-site depth statistics..."
$VCFTOOLS_CMD --vcf test_variants.vcf --site-mean-depth --out site_depth_stats

if [[ $? -eq 0 ]] && [[ -f "site_depth_stats.ldepth.mean" ]]; then
    echo "PASS: Site depth calculation successful"
    echo "  Site depth file: site_depth_stats.ldepth.mean"
    
    if [[ -s "site_depth_stats.ldepth.mean" ]]; then
        echo "  Sample site depths:"
        head -3 site_depth_stats.ldepth.mean
    fi
else
    echo "FAIL: Site depth calculation failed"
fi

# Test 6: Missing data analysis
echo -e "\n8. MISSING DATA ANALYSIS"
echo "========================"
echo "Analyzing missing data patterns..."
$VCFTOOLS_CMD --vcf test_variants.vcf --missing-indv --out missing_indv
$VCFTOOLS_CMD --vcf test_variants.vcf --missing-site --out missing_site

if [[ $? -eq 0 ]] && [[ -f "missing_indv.imiss" ]] && [[ -f "missing_site.lmiss" ]]; then
    echo "PASS: Missing data analysis successful"
    echo "  Individual missingness: missing_indv.imiss"
    echo "  Site missingness: missing_site.lmiss"
    
    if [[ -s "missing_indv.imiss" ]]; then
        echo "  Sample individual missingness:"
        head -3 missing_indv.imiss
    fi
else
    echo "FAIL: Missing data analysis failed"
fi

# Test 7: Hardy-Weinberg equilibrium
echo -e "\n9. HARDY-WEINBERG EQUILIBRIUM TEST"
echo "=================================="
echo "Testing Hardy-Weinberg equilibrium..."
$VCFTOOLS_CMD --vcf test_variants.vcf --hardy --out hwe_test

if [[ $? -eq 0 ]] && [[ -f "hwe_test.hwe" ]]; then
    echo "PASS: Hardy-Weinberg test successful"
    echo "  HWE results: hwe_test.hwe"
    
    if [[ -s "hwe_test.hwe" ]]; then
        echo "  Sample HWE results:"
        head -3 hwe_test.hwe
    fi
else
    echo "FAIL: Hardy-Weinberg test failed"
fi

# Test 8: Format conversion
echo -e "\n10. FORMAT CONVERSION TEST"
echo "========================="
echo "Converting VCF to other formats..."

# Convert to PLINK format
$VCFTOOLS_CMD --vcf test_variants.vcf --plink --out converted_plink

if [[ $? -eq 0 ]] && [[ -f "converted_plink.ped" ]]; then
    echo "PASS: PLINK conversion successful"
    echo "  Files: converted_plink.ped, converted_plink.map"
else
    echo "INFO: PLINK conversion may not be available in this VCFtools version"
fi

# Test 9: Chromosome/region filtering
echo -e "\n11. REGION FILTERING TEST"
echo "========================="
echo "Filtering by chromosome region..."
$VCFTOOLS_CMD --vcf test_variants.vcf --chr chr1 --recode --out chr1_only

if [[ $? -eq 0 ]] && [[ -f "chr1_only.recode.vcf" ]]; then
    echo "PASS: Chromosome filtering successful"
    
    chr1_vars=$(grep -v '^#' chr1_only.recode.vcf | wc -l)
    echo "  Chr1 variants: $chr1_vars"
else
    echo "FAIL: Chromosome filtering failed"
fi

# Test 10: Sample filtering
echo -e "\n12. SAMPLE FILTERING TEST"
echo "========================="
echo "Filtering specific samples..."

# Create sample list
echo -e "SAMPLE1\nSAMPLE3\nSAMPLE5" > keep_samples.txt

$VCFTOOLS_CMD --vcf test_variants.vcf --keep keep_samples.txt --recode --out samples_filtered

if [[ $? -eq 0 ]] && [[ -f "samples_filtered.recode.vcf" ]]; then
    echo "PASS: Sample filtering successful"
    
    orig_samples=$(grep -v '^#' test_variants.vcf | head -1 | cut -f10- | wc -w)
    filt_samples=$(grep -v '^#' samples_filtered.recode.vcf | head -1 | cut -f10- | wc -w)
    echo "  Samples before filtering: $orig_samples"
    echo "  Samples after filtering: $filt_samples"
else
    echo "FAIL: Sample filtering failed"
fi

# Performance summary
echo -e "\n13. PERFORMANCE SUMMARY"
echo "======================"
echo "Files generated:"
ls -la *.vcf *.frq *.idepth *.ldepth* *.imiss *.lmiss *.hwe *.ped *.map 2>/dev/null | wc -l | xargs echo "Total output files:"

echo -e "\nFile sizes:"
for file in *.vcf *.log; do
    if [[ -f "$file" ]]; then
        size=$(ls -lh "$file" | awk '{print $5}')
        echo "  $file: $size"
    fi
done

# Check for errors
echo -e "\n14. ERROR CHECK"
echo "==============="
error_count=0
for logfile in *.log out.log; do
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
echo -e "\n15. FINAL ASSESSMENT"
echo "==================="
total_tests=12
passed_tests=0

# Count successful outputs
[[ -f "freq_stats.frq" ]] && ((passed_tests++))
[[ -f "quality_filtered.recode.vcf" ]] && ((passed_tests++))
[[ -f "depth_stats.idepth" ]] && ((passed_tests++))
[[ -f "site_depth_stats.ldepth.mean" ]] && ((passed_tests++))
[[ -f "missing_indv.imiss" ]] && ((passed_tests++))
[[ -f "missing_site.lmiss" ]] && ((passed_tests++))
[[ -f "hwe_test.hwe" ]] && ((passed_tests++))
[[ -f "chr1_only.recode.vcf" ]] && ((passed_tests++))
[[ -f "samples_filtered.recode.vcf" ]] && ((passed_tests++))

echo "Test summary:"
echo "  Total tests: $total_tests"
echo "  Passed tests: $passed_tests"
echo "  Success rate: $(( passed_tests * 100 / total_tests ))%"

if [[ $passed_tests -eq $total_tests ]]; then
    echo "EXCELLENT: All VCFtools tests passed!"
    echo "VCFtools is fully functional for variant analysis"
elif [[ $passed_tests -gt $(( total_tests / 2 )) ]]; then
    echo "GOOD: Most VCFtools tests passed"
    echo "VCFtools core functionality is working"
else
    echo "ATTENTION: Several VCFtools tests failed"
    echo "Check installation and dependencies"
fi

echo -e "\n======================================"
echo "VCFtools test completed at: $(date)"
echo "Working directory: $(pwd)"
echo "======================================"
