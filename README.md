# HPC Biology Software Test Suite

A comprehensive, modular testing framework for biology and phylogenetics software on High Performance Computing (HPC) systems.

## Overview

This test suite provides automated testing for biology software installations on HPC clusters, with detailed reporting and easy extensibility. Perfect for system administrators, bioinformaticians, and researchers who need to validate software deployments.

## Features

- **Comprehensive Testing**: Tests multiple biology applications with detailed analysis
- **Modular Design**: Easy to add new applications without changing core code
- **SLURM Integration**: Automatic job submission with monitoring commands
- **GPU Support**: Specialized testing for GPU-accelerated applications like AlphaFold3
- **Intelligent Fallback**: Uses detailed tests when available, basic tests otherwise
- **Professional Reporting**: Timestamped results with pass/fail summaries
- **Container Support**: Tests containerized applications (Apptainer/Singularity)
- **No Dependencies**: Works with existing example data, no external downloads required

## Supported Applications

### Currently Tested
- **IQ-TREE** - Maximum likelihood phylogenetic inference
- **BEAST2** - Bayesian evolutionary analysis
- **PLINK** - Population genetics and GWAS
- **VCFtools** - Variant call format manipulation
- **Kraken2** - Taxonomic sequence classification
- **QIIME2** - Microbiome bioinformatics platform
- **AlphaFold3** - AI-powered protein structure prediction (GPU-accelerated)
- **R** - Statistical computing environment

### Easy to Add
The modular design makes it simple to add new applications - just create an `appname_test.sh` script and add one line to the main launcher.

## Installation

```bash
# Clone the repository
git clone https://github.com/yourusername/hpc-biology-test-suite.git
cd hpc-biology-test-suite

# Make scripts executable
chmod +x *.sh

# Run the main test suite
./bio_test_suite.sh

# Or run AlphaFold3 tests separately (requires GPU)
./alphafold3_launcher.sh
```

## Usage

### Quick Start
```bash
# Run the comprehensive test suite
./bio_test_suite.sh

# Follow the interactive menu to select:
# 1) Phylogenetics & Evolution Suite
# 2) Genomics & Bioinformatics Suite
# 3) Complete Test Suite (Recommended)
# 4) Custom Selection
```

### AlphaFold3 Testing (Separate Launcher)
```bash
# AlphaFold3 has its own launcher due to GPU requirements
./alphafold3_launcher.sh --help

# Quick usage examples:
./alphafold3_launcher.sh slurm          # Submit to GPU nodes via SLURM
./alphafold3_launcher.sh headnode       # Run head node tests only
./alphafold3_launcher.sh local          # Run all tests locally (on GPU nodes)
```

### Individual Tests
```bash
# Run specific application tests
sbatch iqtree_test.sh
sbatch beast_test.sh
sbatch plink_test.sh
sbatch vcftools_test.sh
sbatch kraken2_test.sh
sbatch qiime2_test.sh

# AlphaFold3 (use launcher for proper GPU handling)
./alphafold3_launcher.sh slurm
```

### Results
All results are saved in timestamped directories:
```
biology_test_results_YYYYMMDD_HHMMSS/
├── test_summary.txt      # Pass/fail summary for all applications
└── detailed_log.txt      # Full verbose output log

alphafold3_test_results_YYYYMMDD_HHMMSS/
├── alphafold3_test_report.txt    # Comprehensive AlphaFold3 report
├── logs/                         # Detailed execution logs
├── outputs/                      # Test predictions and results
└── sequences/                    # Test protein sequences
```

## Sample Output

```
APPLICATION     STATUS          DETAILS
----------------------------------------------------------------
IQ-TREE         PASS           Found in PATH, Detailed test available
BEAST2          PASS           Found as beast2, Detailed test available
PLINK           PASS           Found at direct path, Detailed test available
VCFtools        PASS           Found in PATH, Detailed test available
Kraken2         PASS           Found in PATH, Detailed test available
QIIME2          PASS           Environment + command test, Detailed test available
R               PASS           Found in PATH, Basic test only

SUMMARY STATISTICS:
==================
Total applications tested: 7
Successfully detected: 7
Failed detection: 0
Success rate: 100%
```

## System Requirements

- **Operating System**: Linux (tested on CentOS/RHEL)
- **Job Scheduler**: SLURM (optional - can run directly)
- **Applications**: Install target software in `/opt/sw/pub/apps/` or update paths
- **GPU Support**: NVIDIA GPUs required for AlphaFold3 testing
- **Container Runtime**: Apptainer/Singularity for containerized applications
- **Example Data**: Uses existing example files or generates test data

## File Structure

```
hpc-biology-test-suite/
├── README.md                    # This file
├── bio_test_suite.sh            # Main comprehensive launcher
├── iqtree_test.sh               # Detailed IQ-TREE testing
├── beast_test.sh                # Detailed BEAST2 testing
├── plink_test.sh                # Detailed PLINK testing
├── vcftools_test.sh             # Detailed VCFtools testing
├── kraken2_test.sh              # Detailed Kraken2 testing
├── qiime2_test.sh               # Detailed QIIME2 testing
├── alphafold3_launcher.sh       # AlphaFold3 test launcher (SLURM integration)
├── alphafold3_test.sh           # Detailed AlphaFold3 testing
├── phylo_test_launcher.sh       # Simple phylogenetics launcher
└── examples/                    # Example outputs and configurations
```

## Adding New Applications

Adding a new application is extremely simple:

### 1. Create Test Script
```bash
# Create detailed test script
nano myapp_test.sh
chmod +x myapp_test.sh
```

### 2. Update Main Launcher
Add these 4 lines to `bio_test_suite.sh`:
```bash
apps["myapp"]="MyApplication"
app_paths["myapp"]="/opt/sw/pub/apps/myapp"
app_categories["myapp"]="genomics"
app_descriptions["myapp"]="Description of what MyApp does"
```

That's it! The launcher automatically detects and uses your detailed script.

### 3. For GPU Applications (Optional)
For applications requiring specialized hardware (like GPUs), consider creating a separate launcher following the `alphafold3_launcher.sh` pattern.

## Configuration

### Custom Application Paths
Edit the path variables in scripts to match your installation:
```bash
# Example: Update paths in bio_test_suite.sh
export PATH="/your/custom/path:$PATH"
```

### SLURM Parameters
Adjust job parameters in individual test scripts:
```bash
#SBATCH --time=02:00:00
#SBATCH --mem=8GB
#SBATCH --cpus-per-task=4
#SBATCH --gres=gpu:1              # For GPU applications
```

## Test Details

### IQ-TREE Tests
- Model selection with ModelFinder
- Maximum likelihood tree reconstruction
- Bootstrap analysis (1000 replicates)
- SH-aLRT branch support
- Partition analysis

### BEAST2 Tests
- XML configuration validation
- Bayesian MCMC analysis
- Log file analysis
- Tree file validation
- Utility testing (LogCombiner, TreeAnnotator)

### PLINK Tests
- File format conversion (PED/MAP to binary)
- Allele frequency calculation
- Quality control filtering
- Hardy-Weinberg equilibrium testing
- Linkage disequilibrium analysis
- Association analysis

### VCFtools Tests
- VCF format validation
- Variant filtering by quality
- Depth statistics calculation
- Missing data analysis
- Format conversion testing

### Kraken2 Tests
- Installation verification
- Database detection
- Sequence classification
- Output format validation
- Performance metrics

### QIIME2 Tests
- Conda environment validation
- Data import functionality (BIOM, FASTA, metadata)
- Core analysis workflow (diversity, filtering, summarization)
- Plugin functionality testing
- Export capabilities

### AlphaFold3 Tests
- Container accessibility and execution
- GPU availability and CUDA functionality
- Database connectivity and validation
- Module loading (with fallback to manual paths)
- Functional prediction testing with small proteins
- Existing test script execution (`run_alphafold_test.py`, `run_alphafold_data_test.py`)

## Contributing

We welcome contributions! Here's how you can help:

1. **Add New Applications**: Create test scripts for additional biology software
2. **Improve Tests**: Enhance existing test coverage
3. **Bug Fixes**: Report and fix issues
4. **Documentation**: Improve this README or add examples

### Development Guidelines
- Follow the existing script structure
- Include comprehensive error handling
- Add progress reporting with PASS/FAIL indicators
- For GPU applications, consider separate launchers with proper SLURM integration
- Test on multiple systems before submitting

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Authors

- **João Tonini** - [GitHub](https://github.com/jtonini)

## Acknowledgments

- BEAST team for providing excellent example datasets
- IQ-TREE developers for comprehensive phylogenetic analysis tools
- DeepMind for AlphaFold3 and associated test scripts
- QIIME2 development team for microbiome analysis tools
- HPC community for testing and feedback

## Support

- **Issues**: [GitHub Issues](https://github.com/yourusername/hpc-biology-test-suite/issues)
- **Discussions**: [GitHub Discussions](https://github.com/yourusername/hpc-biology-test-suite/discussions)
- **Email**: jtonini@richmond.edu

## Version History

- **v1.0.0** - Initial release with 6 biology applications
- **v1.1.0** - Added modular design and comprehensive reporting
- **v1.2.0** - Enhanced SLURM integration and error handling
- **v1.3.0** - Added QIIME2 microbiome analysis testing
- **v1.4.0** - Added AlphaFold3 GPU-accelerated testing with specialized launcher

---

*Happy testing!*
