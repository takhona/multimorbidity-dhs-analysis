*==============================================================================
* 00_dataextraction.do
* Project : Co-occurrence of HIV and Hypertension in Four African Countries
* Purpose : Merge women's recode, household BP, and HIV datasets for each
*           country; construct blood pressure and hypertension variables;
*           append into a single four-country dataset
* Author  : Takhona Hlatshwako
* Date    : September 23, 2026
* Stata   : Version 19
*==============================================================================

clear all
cd "/Users/..."   // <- change me


*==============================================================================
* 1. LESOTHO (2014)
*    BP averages (sbpaves, sbpaved) are pre-computed in the IR file
*==============================================================================

use "LSIR71FL.DTA", clear

gen clusterno = v001
gen lineno    = v003
gen hhnum     = v002
gen country   = 1

sort clusterno lineno hhnum

merge 1:1 clusterno lineno hhnum using "ls-hiv.dta"
tab _merge
drop _merge

drop if hiv03 == .
drop b* m*

* --- Measured hypertension (SBP >= 140 or DBP >= 90)
gen hbp_measured = .
replace hbp_measured = 1 if !missing(sbpaves, sbpaved) ///
    & (sbpaves >= 140 | sbpaved >= 90)
replace hbp_measured = 0 if !missing(sbpaves, sbpaved) ///
    & (sbpaves < 140 & sbpaved < 90)
codebook hbp_measured

* --- Self-reported hypertension diagnosis
gen hbp_diag = s1012h
label define hbp_diag_lab 0 "No" 1 "Yes"
label values hbp_diag hbp_diag_lab
tab hbp_diag

* --- Hypertension medication (recode 3 = not applicable to missing)
gen hbp_med = s1012ia
replace hbp_med = . if hbp_med == 3
label define hbp_med_lab 0 "No" 1 "Yes"
label values hbp_med hbp_med_lab
tab hbp_med

drop if caseid == ""

save "lesotho_merged.dta", replace


*==============================================================================
* 2. GHANA (2014)
*    Two BP readings available; average excluding implausible values (>= 995)
*==============================================================================

use "gh_wm_2014.dta", clear

gen clusterno = v001
gen lineno    = v003
gen hhnum     = v002
gen country   = 2

sort clusterno lineno hhnum

merge 1:1 clusterno lineno hhnum using "gh-hiv.dta"
tab _merge
drop _merge

drop if hiv03 == .
drop b* m*

* --- Average of two BP readings
gen sbp_avg = (s600ca + s1056a) / 2 ///
    if !missing(s600ca, s1056a) & s600ca < 995 & s1056a < 995
gen dbp_avg = (s600cb + s1056b) / 2 ///
    if !missing(s600cb, s1056b) & s600cb < 995 & s1056b < 995

gen hbp_measured = .
replace hbp_measured = 1 if !missing(sbp_avg, dbp_avg) ///
    & (sbp_avg >= 140 | dbp_avg >= 90)
replace hbp_measured = 0 if !missing(sbp_avg, dbp_avg) ///
    & (sbp_avg < 140 & dbp_avg < 90)
codebook hbp_measured

* --- Self-reported diagnosis (recode 8 = don't know to missing)
gen hbp_diag = s1033
replace hbp_diag = . if hbp_diag == 8
label define hbp_diag_lab 0 "No" 1 "Yes"
label values hbp_diag hbp_diag_lab
tab hbp_diag

* --- Hypertension medication
gen hbp_med = s1035a
replace hbp_med = . if hbp_med == 3
label define hbp_med_lab 0 "No" 1 "Yes"
label values hbp_med hbp_med_lab
tab hbp_med

drop if caseid == ""

save "ghana_merged.dta", replace


*==============================================================================
* 3. NAMIBIA (2013)
*    BP and diagnosis variables are in the household recode (wide format).
*    Reshape to long, assign per-individual values by line number,
*    then merge with women's recode and HIV data.
*==============================================================================

* --- Step 3a: Reshape household BP file to long format
use "nam_hh_2013.dta", clear

gen clusterno = hv001
gen hhnum     = hv002

reshape long sh324a_ sh324b_ sh334a_ sh334b_, ///
    i(clusterno hhnum) j(lineno)

drop if missing(sh324a_) & missing(sh334a_) ///
      & missing(sh324b_) & missing(sh334b_)

* Recode implausible values to missing
foreach var in sh324a_ sh324b_ sh334a_ sh334b_ {
    replace `var' = . if `var' >= 994
}

* Average of two BP readings per individual
egen sbp_avg = rowmean(sh324a_ sh334a_)
egen dbp_avg = rowmean(sh324b_ sh334b_)

gen hbp_measured = .
replace hbp_measured = 1 if !missing(sbp_avg, dbp_avg) ///
    & (sbp_avg >= 140 | dbp_avg >= 90)
replace hbp_measured = 0 if !missing(sbp_avg, dbp_avg) ///
    & (sbp_avg < 140 & dbp_avg < 90)

* --- Per-individual diagnosis and medication (by line number)
* NOTE: capture allows the loop to skip line numbers with no corresponding
*       variable in the data (e.g., if max household size < 30)
gen hbp_diag = .
forvalues i = 1/30 {
    capture replace hbp_diag = sh318_`i' if lineno == `i'
}
label define hbp_diag_lab 0 "No" 1 "Yes"
label values hbp_diag hbp_diag_lab
tab hbp_diag

gen hbp_med = .
forvalues i = 1/30 {
    capture replace hbp_med = sh319a_`i' if lineno == `i'
}
label define hbp_med_lab 0 "No" 1 "Yes"
label values hbp_med hbp_med_lab
tab hbp_med

keep clusterno hhnum lineno sbp_avg dbp_avg hbp_measured hbp_diag hbp_med
sort clusterno hhnum lineno
save "nm_bp_long.dta", replace

* --- Step 3b: Prepare women's recode
use "nam_wm_2013.dta", clear
gen clusterno = v001
gen lineno    = v003
gen hhnum     = v002
sort clusterno lineno hhnum
save "nam_wm_2013-v2.dta", replace

* --- Step 3c: Merge women + BP + HIV
use "nam_wm_2013-v2.dta", clear

merge 1:1 clusterno hhnum lineno using "nm_bp_long.dta"
tab _merge
drop _merge

merge 1:1 clusterno lineno hhnum using "nm-hiv.dta"
tab _merge
drop _merge

drop if caseid == ""
drop if hiv03 == .
codebook hbp_measured
drop b* m* h1* h2* h3*

gen country = 3

save "nam_merged.dta", replace


*==============================================================================
* 4. SOUTH AFRICA (2016)
*    Same structure as Namibia: BP is in the household recode (wide format).
*    Household line numbers are stored as strings; destring before matching.
*==============================================================================

* --- Step 4a: Reshape household BP file to long format
clear mata
set maxvar 9000
use "sa_hh_2016.dta", clear

gen clusterno = hv001
gen hhnum     = hv002

reshape long sh228a_ sh228b_ sh232a_ sh232b_, ///
    i(clusterno hhnum) j(lineno, string)

drop if missing(sh228a_) & missing(sh232a_) ///
      & missing(sh228b_) & missing(sh232b_)

foreach var in sh228a_ sh232a_ sh228b_ sh232b_ {
    replace `var' = . if `var' >= 994
}

egen sbp_avg = rowmean(sh228a_ sh232a_)
egen dbp_avg = rowmean(sh228b_ sh232b_)

gen hbp_measured = .
replace hbp_measured = 1 if !missing(sbp_avg, dbp_avg) ///
    & (sbp_avg >= 140 | dbp_avg >= 90)
replace hbp_measured = 0 if !missing(sbp_avg, dbp_avg) ///
    & (sbp_avg < 140 & dbp_avg < 90)

destring lineno, replace

* --- Per-individual diagnosis and medication
gen hbp_diag = .
forvalues i = 1/10 {
    local j : display %02.0f `i'
    replace hbp_diag = sh223_`j' if lineno == `i'
}
replace hbp_diag = . if missing(hbp_diag)
label define hbp_diag_lab 0 "No" 1 "Yes"
label values hbp_diag hbp_diag_lab

gen hbp_med = .
forvalues i = 1/10 {
    local j : display %02.0f `i'
    replace hbp_med = sh224_`j' if lineno == `i'
}
replace hbp_med = . if missing(hbp_med)
* FIX: label name (hbp_med_lab) must differ from variable name (hbp_med)
label define hbp_med_lab 0 "No" 1 "Yes"
label values hbp_med hbp_med_lab

keep clusterno hhnum lineno sbp_avg dbp_avg hbp_measured hbp_diag hbp_med
sort clusterno hhnum lineno
save "sa_bp_long.dta", replace

* --- Step 4b: Prepare women's recode
use "sa_wm_2016.dta", clear
gen clusterno = v001
gen lineno    = v003
gen hhnum     = v002
sort clusterno lineno hhnum
save "sa_wm_2016-v2.dta", replace

* --- Step 4c: Merge women + BP + HIV
use "sa_wm_2016-v2.dta", clear

merge 1:1 clusterno hhnum lineno using "sa_bp_long.dta"
tab _merge
drop _merge

merge 1:1 clusterno lineno hhnum using "sa-hiv.dta"
tab _merge
drop _merge

drop if caseid == ""
drop if hiv03 == .
codebook hbp_measured
drop b* m* h1* h2* h3* h4* hw*

gen country = 4

save "sa_merged.dta", replace


*==============================================================================
* 5. APPEND ALL COUNTRIES INTO ONE DATASET
*==============================================================================

use "ghana_merged.dta", clear
append using "lesotho_merged.dta"
append using "nam_merged.dta"
append using "sa_merged.dta", force

drop if country == .

label define countrylbl ///
    1 "Lesotho"       ///
    2 "Ghana"         ///
    3 "Namibia"       ///
    4 "South Africa"
label values country countrylbl

tab country
codebook country

save "four_hiv_merged.dta", replace

display as result _newline "00_dataextraction.do completed successfully."
