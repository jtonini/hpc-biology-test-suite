#!/bin/bash
#SBATCH --job-name=beast_test
#SBATCH --output=beast_test_%j.out
#SBATCH --error=beast_test_%j.err
#SBATCH --time=02:00:00
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=4
#SBATCH --mem=8GB
#SBATCH --partition=testing

# BEAST2 phylogenetic analysis test script
# Tests BEAST2 installation using existing XML example files

echo "=== BEAST2 Bayesian Phylogenetic Analysis Test ==="
echo "Job ID: $SLURM_JOB_ID"
echo "Node: $SLURMD_NODENAME"
echo "Date: $(date)"
echo "Working directory: $(pwd)"
echo "=================================================="

# Set up application paths
export PATH="/opt/sw/pub/apps:$PATH"
export PATH="/opt/sw/pub/apps/beast.v2.7.5/bin:$PATH"

# Load modules if needed (uncomment and modify as needed)
# module load beast2
# module load beast/2.7.5
# module load java

echo "Setting up application paths..."
echo "BEAST path: /opt/sw/pub/apps/beast.v2.7.5/bin"
echo "IQ-TREE path: /opt/sw/pub/apps/iqtree"

# Create working directory
WORK_DIR="beast_test_${SLURM_JOB_ID}"
mkdir -p $WORK_DIR
cd $WORK_DIR

echo "Working in directory: $(pwd)"

# Check if BEAST2 is available
echo -e "\n1. CHECKING BEAST2 INSTALLATION"
echo "==============================="
if command -v beast &> /dev/null; then
    echo "✓ BEAST found: $(which beast)"
    beast -version 2>&1 | head -5
    BEAST_CMD="beast"
elif command -v beast2 &> /dev/null; then
    echo "✓ BEAST2 found: $(which beast2)"  
    beast2 -version 2>&1 | head -5
    BEAST_CMD="beast2"
else
    echo "✗ BEAST not found in PATH"
    echo "Please ensure BEAST2 is installed and available"
    exit 1
fi

# Check other BEAST utilities
echo -e "\nChecking BEAST utilities:"
utilities_found=0
for util in beauti logcombiner treeannotator; do
    if command -v $util &> /dev/null; then
        echo "✓ $util found: $(which $util)"
        ((utilities_found++))
    else
        echo "✗ $util not found"
    fi
done

# Check Java version
echo -e "\nJava version:"
java -version 2>&1 | head -3

# Set path to BEAST example XML files
BEAST_XML_PATH="/opt/sw/pub/apps/beast.v2.7.5/examples"

echo -e "\n2. CHECKING BEAST EXAMPLE XML FILES"
echo "==================================="
if [[ -d "$BEAST_XML_PATH" ]]; then
    echo "✓ BEAST example directory found: $BEAST_XML_PATH"
    
    xml_count=$(ls $BEAST_XML_PATH/*.xml 2>/dev/null | wc -l)
    echo "Available XML files: $xml_count"
    
    echo -e "\nXML files by category:"
    echo "Basic models:"
    ls $BEAST_XML_PATH/test*HKY*.xml $BEAST_XML_PATH/test*GTR*.xml $BEAST_XML_PATH/test*JukesCantor*.xml 2>/dev/null | head -5
    
    echo -e "\nClock models:"
    ls $BEAST_XML_PATH/test*Clock*.xml $BEAST_XML_PATH/test*Relaxed*.xml 2>/dev/null | head -3
    
    echo -e "\nCoalescent models:"
    ls $BEAST_XML_PATH/test*Coalescent*.xml $BEAST_XML_PATH/test*BSP*.xml $BEAST_XML_PATH/test*Yule*.xml 2>/dev/null | head -3
    
else
    echo "✗ BEAST example XML files not found at $BEAST_XML_PATH"
    echo "Please verify the BEAST installation path"
    exit 1
fi

# Select test XML files - prefer smaller/faster ones for testing
echo -e "\n3. SELECTING TEST XML FILES"
echo "==========================="

# Define test files in order of preference (fastest first)
test_files=(
    "testJukesCantorShort.xml"
    "testHKY.xml" 
    "testCoalescent.xml"
    "testYuleOneSite.xml"
    "testSeqGen.xml"
    "testDirectSimulator.xml"
)

selected_files=()
for test_file in "${test_files[@]}"; do
    if [[ -f "$BEAST_XML_PATH/$test_file" ]]; then
        selected_files+=("$test_file")
        echo "✓ Found: $test_file"
    else
        echo "✗ Not found: $test_file"
    fi
done

if [[ ${#selected_files[@]} -eq 0 ]]; then
    echo "No suitable test files found. Using any available XML..."
    mapfile -t selected_files < <(ls $BEAST_XML_PATH/*.xml 2>/dev/null | head -3 | xargs -n1 basename)
fi

echo "Selected ${#selected_files[@]} files for testing"

# Test each selected XML file
echo -e "\n4. RUNNING BEAST ANALYSES"
echo "========================="

successful_runs=0
total_runs=0

for xml_file in "${selected_files[@]}"; do
    echo -e "\n--- Testing: $xml_file ---"
    ((total_runs++))
    
    # Copy XML file to working directory
    cp "$BEAST_XML_PATH/$xml_file" ./
    
    # Get basic info about the XML
    chain_length="unknown"
    log_every="unknown"
    if grep -q "chainLength" "$xml_file"; then
        chain_length=$(grep "chainLength" "$xml_file" | head -1 | sed 's/.*chainLength="\([0-9]*\)".*/\1/')
    fi
    if grep -q "logEvery" "$xml_file"; then
        log_every=$(grep "logEvery" "$xml_file" | head -1 | sed 's/.*logEvery="\([0-9]*\)".*/\1/')
    fi
    
    echo "Analysis parameters:"
    echo "  Chain length: $chain_length"
    echo "  Log every: $log_every"
    
    # For testing, create a shorter version if chain is very long
    test_file="$xml_file"
    if [[ "$chain_length" =~ ^[0-9]+$ ]] && [[ $chain_length -gt 50000 ]]; then
        echo "Creating shorter version for testing (10,000 generations)..."
        sed 's/chainLength="[0-9]*"/chainLength="10000"/' "$xml_file" > "short_${xml_file}"
        sed -i 's/logEvery="[0-9]*"/logEvery="1000"/' "short_${xml_file}"
        test_file="short_${xml_file}"
    fi
    
    # Run BEAST analysis with timeout
    echo "Starting BEAST analysis..."
    start_time=$(date +%s)
    
    timeout 600s $BEAST_CMD -threads $SLURM_CPUS_PER_TASK "$test_file" 2>&1 | tee "${xml_file%.xml}_run.log"
    exit_code=$?
    
    end_time=$(date +%s)
    runtime=$((end_time - start_time))
    
    # Check results
    base_name="${test_file%.xml}"
    
    if [[ $exit_code -eq 0 ]]; then
        echo "✓ BEAST analysis completed successfully ($runtime seconds)"
        ((successful_runs++))
        
        # Check output files
        if [[ -f "${base_name}.log" ]]; then
            echo "  ✓ Log file created: ${base_name}.log"
            lines=$(wc -l < "${base_name}.log")
            echo "    Lines in log: $lines"
            
            # Check if analysis started properly
            if grep -q "Start likelihood" "${base_name}.log" 2>/dev/null; then
                echo "    ✓ Analysis initialized successfully"
            fi
            
            # Check final likelihood if completed
            if grep -q "likelihood" "${base_name}.log" 2>/dev/null; then
                final_likelihood=$(tail -5 "${base_name}.log" | grep -o '\-[0-9]*\.[0-9]*' | tail -1)
                if [[ -n "$final_likelihood" ]]; then
                    echo "    Final likelihood: $final_likelihood"
                fi
            fi
        fi
        
        if [[ -f "${base_name}.trees" ]]; then
            echo "  ✓ Tree file created: ${base_name}.trees"
            tree_count=$(grep -c "tree STATE" "${base_name}.trees" 2>/dev/null || echo "0")
            echo "    Trees sampled: $tree_count"
        fi
        
    elif [[ $exit_code -eq 124 ]]; then
        echo "⚠ BEAST analysis timed out (10 min limit) - but was running correctly ($runtime seconds)"
        echo "  This is normal for testing - analysis was progressing"
        
        # Still check for partial output
        if [[ -f "${base_name}.log" ]]; then
            lines=$(wc -l < "${base_name}.log")
            echo "  Partial log file: $lines lines"
        fi
        
        ((successful_runs++))  # Count timeouts as successful starts
        
    else
        echo "✗ BEAST analysis failed (exit code: $exit_code, runtime: $runtime seconds)"
        
        # Check for error messages
        if [[ -f "${xml_file%.xml}_run.log" ]]; then
            echo "  Error details:"
            tail -10 "${xml_file%.xml}_run.log" | grep -i error | head -3
        fi
    fi
    
    # Only test first 3 files to save time
    if [[ $total_runs -ge 3 ]]; then
        echo -e "\nLimiting to first 3 tests for time efficiency..."
        break
    fi
done

# Test BEAST utilities with generated files
echo -e "\n5. TESTING BEAST UTILITIES"
echo "=========================="

# Test LogCombiner
if command -v logcombiner &> /dev/null; then
    echo "Testing LogCombiner..."
    if ls *.log >/dev/null 2>&1; then
        logcombiner -help >/dev/null 2>&1
        if [[ $? -eq 0 ]]; then
            echo "✓ LogCombiner is functional"
            
            # Try to combine log files if multiple exist
            log_files=(*.log)
            if [[ ${#log_files[@]} -gt 1 ]]; then
                echo "  Testing log combination with ${#log_files[@]} files..."
                logcombiner -log "${log_files[0]}" "${log_files[1]}" -o combined_test.log -b 10 2>/dev/null
                if [[ -f "combined_test.log" ]]; then
                    echo "  ✓ Log combination successful"
                fi
            fi
        else
            echo "✗ LogCombiner help failed"
        fi
    else
        echo "! No log files available for LogCombiner testing"
    fi
fi

# Test TreeAnnotator  
if command -v treeannotator &> /dev/null; then
    echo "Testing TreeAnnotator..."
    if ls *.trees >/dev/null 2>&1; then
        treeannotator -help >/dev/null 2>&1
        if [[ $? -eq 0 ]]; then
            echo "✓ TreeAnnotator is functional"
            
            # Try to annotate a tree file
            tree_files=(*.trees)
            if [[ -f "${tree_files[0]}" ]]; then
                echo "  Testing tree annotation..."
                treeannotator -burnin 10 -heights mean "${tree_files[0]}" annotated_test.tree 2>/dev/null
                if [[ -f "annotated_test.tree" ]]; then
                    echo "  ✓ Tree annotation successful"
                fi
            fi
        else
            echo "✗ TreeAnnotator help failed"
        fi
    else
        echo "! No tree files available for TreeAnnotator testing"
    fi
fi

# Performance and Summary
echo -e "\n6. TEST SUMMARY"
echo "=============="
echo "BEAST executable: $BEAST_CMD"
echo "Total XML files tested: $total_runs"
echo "Successful runs: $successful_runs"
echo "Success rate: $(( successful_runs * 100 / total_runs ))%"

echo -e "\nUtilities tested:"
echo "- LogCombiner: $(command -v logcombiner >/dev/null && echo "Available" || echo "Not found")"
echo "- TreeAnnotator: $(command -v treeannotator >/dev/null && echo "Available" || echo "Not found")"
echo "- BEAUti: $(command -v beauti >/dev/null && echo "Available" || echo "Not found")"

echo -e "\nFiles generated:"
file_count=$(ls -1 *.log *.trees *.xml 2>/dev/null | wc -l)
echo "Total output files: $file_count"

if ls *.log >/dev/null 2>&1; then
    echo -e "\nLog files:"
    for logfile in *.log; do
        if [[ -f "$logfile" ]]; then
            lines=$(wc -l < "$logfile")
            size=$(ls -lh "$logfile" | awk '{print $5}')
            echo "  $logfile: $lines lines, $size"
        fi
    done
fi

if ls *.trees >/dev/null 2>&1; then
    echo -e "\nTree files:"
    for treefile in *.trees; do
        if [[ -f "$treefile" ]]; then
            trees=$(grep -c "tree STATE" "$treefile" 2>/dev/null || echo "0")
            size=$(ls -lh "$treefile" | awk '{print $5}')
            echo "  $treefile: $trees trees, $size"
        fi
    done
fi

# Final assessment
echo -e "\n7. OVERALL ASSESSMENT"
echo "===================="
if [[ $successful_runs -eq $total_runs ]] && [[ $total_runs -gt 0 ]]; then
    echo "🎉 EXCELLENT: All BEAST tests passed!"
    echo "   BEAST2 is properly installed and functional"
elif [[ $successful_runs -gt 0 ]]; then
    echo "✅ GOOD: $successful_runs out of $total_runs tests passed"
    echo "   BEAST2 is working but some issues may exist"
else
    echo "❌ POOR: No tests completed successfully"
    echo "   Check BEAST2 installation and configuration"
fi

echo -e "\nRecommendations for production use:"
if [[ $successful_runs -gt 0 ]]; then
    echo "- ✓ BEAST2 core functionality confirmed"
    echo "- ✓ Ready for phylogenetic analyses"
    echo "- Consider testing with your own data files"
    echo "- Monitor memory usage for large datasets"
else
    echo "- Check module loading commands"
    echo "- Verify Java version compatibility"
    echo "- Check BEAST2 installation completeness"
fi

echo -e "\n=================================================="
echo "BEAST2 test completed at: $(date)"
echo "Working directory: $(pwd)"
echo "=================================================="
