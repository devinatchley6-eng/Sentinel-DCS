Sentinel-DCS
Preregistered Black-Box Behavioral Monitoring for Large Language Models
Sentinel-DCS is a reproducible monitoring framework for detecting behavioral drift, silent bifurcation, and integrity attacks in deployed large language model (LLM) systems using only prompt-response observations. No access to model weights, logits, or internal state is required.
The system implements a preregistered monitoring architecture with deterministic synthetic verification and explicit integrity safeguards.
Overview
Production LLM systems can change behavior over time due to:
model updates
distribution shift
adversarial prompting
infrastructure manipulation
monitoring pipeline tampering
Sentinel-DCS provides a black-box observability layer that detects statistically significant changes in tail-risk behavior and monitoring integrity.
It is designed for:
safety monitoring
governance and audit
compliance validation
model lifecycle surveillance
research on behavioral drift
Core Detection Capabilities
Sentinel-DCS monitors multiple failure modes simultaneously.
1. Gradual Behavioral Drift
Sequential accumulation of small rate changes using CUSUM detection.
2. Silent Bifurcation
Emergence of new behavioral modes without mean rate change, detected via density-ratio classification.
3. Oscillation-Based Evasion
Alternating high/low risk regimes detected using variance-ratio block tests.
4. Monitoring Infrastructure Tampering
Explicit detection of:
threshold modification
slice distribution manipulation
selective data omission
5. Multi-Tail Risk Monitoring
Simultaneous surveillance of multiple behavioral risk categories.
Detection Architecture
Sentinel-DCS integrates the following components:
Component
Purpose
Density-ratio tail classifier
Detects mode separation in embedding space
CUSUM sequential detector
Detects cumulative drift
Variance-ratio oscillation test
Detects alternating regimes
Dual-embedding invariance
Detects representation dependency
Integrity attack diagnostics
Detects monitoring manipulation
Multi-tail vector
Monitors multiple risk classes
Power analysis
Determines required monitoring window size
Reproducibility
Sentinel-DCS provides deterministic verification on synthetic data.
To reproduce the preregistered validation results:
Bash
Copy code
python scripts/run_full_verification.py --seed 42
Expected outputs include:
tail classifier AUC
CUSUM detection timing
oscillation detection results
embedding agreement
integrity attack detection
power analysis estimates
Results are written to:
Copy code

results/seed42_verification.json
Repository Structure
Copy code

sentinel-dcs/
├── preregistration/     # Manifest and preregistered specification
├── docs/                # Theory and system documentation
├── src/sentinel_dcs/    # Monitoring framework implementation
├── synthetic/           # Synthetic data generator
├── scripts/             # Reproducibility entry points
└── results/             # Deterministic verification outputs
Relationship to Conflict Validator
Sentinel-DCS extends prior work:
Conflict Validator
Devin Earl Atchley, Zenodo DOI:
https://doi.org/10.5281/zenodo.18654778�
Conflict Validator introduced directional conflict scoring as a statistical primitive for black-box behavioral inconsistency detection.
Sentinel-DCS generalizes this foundation by adding:
sequential drift detection
silent bifurcation monitoring
adversarial integrity modeling
multi-tail surveillance
preregistered monitoring governance
Conflict Validator may be viewed as a special case of Sentinel-DCS under single-metric static monitoring.
Scientific Status
Sentinel-DCS v1.1-hardened has been:
fully implemented
preregistered
verified on synthetic data
tested against simulated integrity attacks
Scope limitations:
validation currently limited to synthetic data
real-world LLM deployment evaluation pending
parameters require calibration per deployment context
This repository provides the reproducible monitoring framework, not a universal parameter configuration.
Installation
Python 3.10+ recommended.
Install dependencies:
Bash
Copy code
pip install -e .
Or:
Bash
Copy code
pip install -r requirements.txt
Intended Use
Sentinel-DCS is designed as:
a monitoring layer for deployed LLM systems
a research platform for behavioral surveillance methods
an auditable governance instrument
a preregistered detection framework
It is not an intervention or control system.
Citation
If you use Sentinel-DCS in academic work, please cite both:
Sentinel-DCS repository (Zenodo DOI pending release)
and
Atchley, Devin Earl (2026).
Conflict Validator. Zenodo.
https://doi.org/10.5281/zenodo.18654778�
Citation metadata is provided in CITATION.cff.
License
See LICENSE file for terms of use.
Author
Devin Earl Atchley
Independent Researcher
Project Status
Active research and development.
Upcoming priorities:
real LLM API validation
independent replication
adversarial red-team testing
production monitoring interface
