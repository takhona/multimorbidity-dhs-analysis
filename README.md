# Replication Package: Co-occurrence of HIV and Hypertension in Four African Countries

## Overview

This repository contains the Stata replication code for the study:

> **"Co-occurrence of HIV and Hypertension Among Women of Reproductive Age in Four Sub-Saharan African Countries: Evidence from Demographic and Health Surveys"**
>
> Takhona G. Hlatshwako, Leah Frerichs, Larissa Jennings Mayo-Wilson, Tara Templin
> DOI: [to be added upon publication]

This study examines the co-occurrence of HIV and hypertension (high blood pressure) among women of reproductive age (15–49 years) in Lesotho, Ghana, Namibia, and South Africa using nationally representative Demographic and Health Surveys (DHS). Birth year is stratified into 10-year cohorts as the primary independent variable. A multinomial logistic regression model estimates the relative risk of four morbidity categories — HIV only, HBP only, HIV–HBP, and neither — by birth cohort, adjusting for sociodemographic covariates.

---

## Data Availability

**The data used in this study are not included in this repository.** DHS data are publicly available but require registration and approval from the DHS Program.

### Accessing the Data

1. Visit the DHS Program website: [https://dhsprogram.com](https://dhsprogram.com)
2. Register for a free account
3. Submit a data request and specify each survey listed in the table below
4. Download the Stata-format (`.DTA`) files and place them in your working directory

### Required Datasets

| Country | Survey Year | Files Required |
|---------|-------------|----------------|
| Lesotho | 2014 | `LSIR71FL.DTA` (Women's Recode), `ls-hiv.dta` (HIV Recode) |
| Ghana | 2014 | `gh_wm_2014.dta` (Women's Recode), `gh-hiv.dta` (HIV Recode) |
| Namibia | 2013 | `nam_wm_2013.dta` (Women's Recode), `nam_hh_2013.dta` (Household Recode), `nm-hiv.dta` (HIV Recode) |
| South Africa | 2016 | `sa_wm_2016.dta` (Women's Recode), `sa_hh_2016.dta` (Household Recode), `sa-hiv.dta` (HIV Recode) |

For Namibia and South Africa, blood pressure measurements are stored in the household recode file and must be reshaped before merging with the women's recode. This is handled in `00_dataextraction.do`.

---

## Software Requirements

- **Stata** version 19 or higher
- Required user-written Stata packages (install before running):

```stata
ssc install table1_mc    // for Table 1
ssc install estout       // for esttab results export
```

---

## Repository Structure

```
.
├── README.md
├── 00_dataextraction.do      # Data merging, BP variable construction, country append
├── 01_dataexploration.do     # Descriptive analysis, access-to-care gap, cascade figure
└── 02_dataanalysis.do        # Regression models, margins, secondary analyses, export
```

---

## How to Run

Run the do files **strictly in order**. Each file saves an intermediate dataset used by the next.

1. **Update the working directory**: Open each do file and change the `cd` path at the top to your local folder containing all DHS files.
2. Run `00_dataextraction.do` → produces `four_hiv_merged.dta`
3. Run `01_dataexploration.do` → produces `women_hiv_merged_analysis_v2.dta` and descriptive figures
4. Run `02_dataanalysis.do` → produces regression tables and analytical figures

---

## Output Files

| File | Description | Produced by |
|------|-------------|-------------|
| `four_hiv_merged.dta` | Appended four-country dataset | 00_dataextraction.do |
| `women_hiv_merged_analysis_v2.dta` | Cleaned analytic dataset | 01_dataexploration.do |
| `Table1_4countries_v2.xlsx` | Descriptive characteristics table | 01_dataexploration.do |
| `fig_hbp_cascade_care.png` | HBP cascade of care figure | 01_dataexploration.do |
| `Results_Table.rtf` | Main multinomial regression results | 02_dataanalysis.do |

---

## Analytic Sample

After applying all inclusion/exclusion criteria, the final analytic sample consists of women aged 15–49 years with valid HIV biomarker results who were not pregnant at the time of interview. Women aged 50 and above present in the Namibia sample (n = 780) were excluded. See `01_dataexploration.do` for the full sample restriction sequence.

---

## Key Constructed Variables

| Variable | Description | Values |
|----------|-------------|--------|
| `country` | Country identifier | 1 = Lesotho, 2 = Ghana, 3 = Namibia, 4 = South Africa |
| `hbp_measured` | Objectively measured hypertension (SBP ≥ 140 or DBP ≥ 90 mmHg) | 0 = No, 1 = Yes |
| `hbp_diag` | Self-reported prior hypertension diagnosis | 0 = No, 1 = Yes |
| `hbp_med` | Currently taking hypertension medication | 0 = No, 1 = Yes |
| `hiv03` | HIV status from biomarker testing | 0 = Negative, 1 = Positive |
| `cohort10` | Birth cohort in 10-year groups | 1 = 1960–1969, 2 = 1970–1979, 3 = 1980–1989, 4 = 1990–1999 |
| `morb_cat` | Four-category morbidity outcome (main dependent variable) | 1 = HIV only, 2 = HBP only, 3 = HIV–HBP, 4 = Neither |
| `educlvl3` | Education level (3-category) | 0 = None, 1 = Primary, 2 = Secondary or higher |
| `marstat2` | Marital status (3-category) | 1 = Never married, 2 = Married/cohabiting, 3 = Previously married |
| `wt` | Survey weight (v005 / 1,000,000) | Continuous |

---

## Survey Design

All weighted analyses use Stata's `svy` prefix with the following design declaration:

```stata
svyset v021 [pweight=wt], strata(v022)
```

where `v021` is the primary sampling unit (cluster), `wt` is the normalized sampling weight, and `v022` is the stratification variable.

---

## Ethics

This is a secondary analysis of de-identified, publicly available data. No additional institutional ethics approval was required.

---

## Citation

If you use this code or data, please cite both the paper and the original DHS surveys:

> [Full paper citation — to be added upon publication]

> DHS Program. *Demographic and Health Surveys*. ICF, Rockville, Maryland, USA. Available at: [https://dhsprogram.com](https://dhsprogram.com)

---

## Contact

For questions about this replication package, please contact: Takhona Hlatshwako ( takhona [at] live [dot] unc [dot] edu )
