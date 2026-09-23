*==============================================================================
* 01_dataexploration.do
* Project : Co-occurrence of HIV and Hypertension in Four African Countries
* Purpose : Sample restrictions, covariate construction, descriptive analysis,
*           access-to-care gap statistics (with McNemar's test), and
*           cascade of care figure
* Author  : Takhona Hlatshwako
* Date    : Septermber 23, 2026
* Stata   : Version 19
* Requires: four_hiv_merged.dta (produced by 00_dataextraction.do)
*           table1_mc package: ssc install table1_mc
*==============================================================================

clear all
cd "/Users/..."   // <- change me

use "four_hiv_merged.dta", clear

tab country
tab hiv03


*==============================================================================
* 1. COOKING FUEL (3-category energy ladder)
*==============================================================================

codebook v161
tab v161, nolab

gen cookfuel3 = .
replace cookfuel3 = 1 if v161 == 1                         // Electricity
replace cookfuel3 = 2 if inlist(v161, 2, 3, 4)             // Gas (clean)
replace cookfuel3 = 3 if inlist(v161, 5,6,7,8,9,10,11)    // Solid fuels
replace cookfuel3 = . if inlist(v161, 13, 14, 95, 96, 97)  // Exclude other

label define fuel3lbl 1 "Electricity" 2 "Gas" 3 "Solid fuels"
label values cookfuel3 fuel3lbl
label variable cookfuel3 "Cooking fuel (3-category energy ladder)"
codebook cookfuel3


*==============================================================================
* 2. ROOF MATERIAL (4-category housing quality)
*==============================================================================

tab v129, nolab

gen roof4 = .
replace roof4 = 1 if inlist(v129, 11,12,13,21,22,23,24,25,26)  // Natural
replace roof4 = 2 if v129 == 31                                  // Metal
replace roof4 = 3 if inlist(v129, 33, 37)                       // Asbestos/cement
replace roof4 = 4 if inlist(v129, 32,34,35,36,38)               // Finished/modern
replace roof4 = . if inlist(v129, 96, 97)

label define roof4lbl ///
    1 "Natural" 2 "Metal" 3 "Asbestos/Cement fiber" 4 "Finished/Modern"
label values roof4 roof4lbl
label variable roof4 "Roof material (4-category housing quality)"
codebook roof4


*==============================================================================
* 3. SAMPLE RESTRICTIONS
*==============================================================================

* Drop women not in the HIV subsample
drop if hiv03 == .

gen age = v012
codebook age

* Sample size checks before age restriction
count if age < 18 & country == 1   // Lesotho
count if age < 18 & country == 2   // Ghana
count if age < 18 & country == 3   // Namibia
count if age < 18 & country == 4   // South Africa

count if age > 49 & country == 1   // Lesotho (expected: 0)
count if age > 49 & country == 2   // Ghana (expected: 0)
count if age > 49 & country == 3   // Namibia (expected: ~780)
count if age > 49 & country == 4   // South Africa (expected: 0)

* Drop women aged 50+ (Namibia sample includes women outside 15-49 range)
drop if age > 49

* Drop invalid HIV test result codes
drop if hiv03 == 7
drop if hiv03 == 9

* Drop currently pregnant women
codebook v213
tab country v213
drop if v213 == 1

tab country   // final sample after all restrictions


*==============================================================================
* 4. HYPERTENSION: CLEANING AND CONSISTENCY CHECKS
*==============================================================================

tab hbp_measured hbp_diag, missing

* South Africa: restrict hbp_med to diagnosed women only
* (SA questionnaire does not route medication question through diagnosis)
* NOTE: verify whether this restriction is also needed for Ghana and Namibia
*       by checking the questionnaire routing in each country's survey instrument
codebook hbp_med if country == 4
replace hbp_med = . if hbp_diag == 0 & country == 4
codebook hbp_diag if country == 4

tab hbp_diag hbp_med


*==============================================================================
* 5. BIRTH YEAR AND 10-YEAR BIRTH COHORT
*    IMPORTANT: verify v010 contains 4-digit calendar years before proceeding.
*    Some DHS versions store v010 as century month codes (CMC).
*    Run: tab v010 (values should be ~1960-2001, not ~600-1450)
*==============================================================================

codebook v010
gen birth_year = v010

gen cohort10 = .
replace cohort10 = 1 if inrange(birth_year, 1960, 1969)
replace cohort10 = 2 if inrange(birth_year, 1970, 1979)
replace cohort10 = 3 if inrange(birth_year, 1980, 1989)
replace cohort10 = 4 if inrange(birth_year, 1990, 1999)
replace cohort10 = . if inrange(birth_year, 2000, 2001)  // very small cell

label define cohort10lbl ///
    1 "1960-1969" 2 "1970-1979" 3 "1980-1989" 4 "1990-1999"
label values cohort10 cohort10lbl
label variable cohort10 "Birth cohort (10-year groups)"

tab cohort10, missing
codebook cohort10


*==============================================================================
* 6. MORBIDITY OUTCOME VARIABLES
*==============================================================================

* --- comorbidity_count
* Guard against this by conditioning on non-missing for both inputs.
gen comorbidity_count = (hiv03 == 1) + (hbp_measured == 1) ///
    if !missing(hiv03) & !missing(hbp_measured)
codebook comorbidity_count

* --- Binary morbidity flag
gen morbidity = comorbidity_count
replace morbidity = 0 if comorbidity_count < 1
replace morbidity = 1 if comorbidity_count >= 1 & !missing(comorbidity_count)
label define m_lab 0 "No morbidity" 1 "Have morbidity"
label values morbidity m_lab
tab morbidity

* --- Four-category morbidity outcome (primary dependent variable)
gen morb_cat = .
replace morb_cat = 1 if hiv03 == 1 & hbp_measured == 0  // HIV only
replace morb_cat = 2 if hiv03 == 0 & hbp_measured == 1  // HBP only
replace morb_cat = 3 if hiv03 == 1 & hbp_measured == 1  // HIV-HBP comorbidity
replace morb_cat = 4 if hiv03 == 0 & hbp_measured == 0  // Neither

label define morblab 1 "HIV only" 2 "HBP only" 3 "HIV-HBP" 4 "Neither"
label values morb_cat morblab
codebook morb_cat
tab morb_cat cohort10

* --- HIV-HBP comorbidity flag (used in treatment analysis)
gen hiv_hbp = .
replace hiv_hbp = 1 if hiv03 == 1 & hbp_measured == 1
replace hiv_hbp = 0 if hiv03 == 0 & hbp_measured == 0
replace hiv_hbp = . if missing(hiv03) | missing(hbp_measured)
codebook hiv_hbp


*==============================================================================
* 7. COVARIATE RECODING
*==============================================================================

* --- Five-year age groups
gen age5year = .
replace age5year = 1 if inrange(age, 15, 19)
replace age5year = 2 if inrange(age, 20, 24)
replace age5year = 3 if inrange(age, 25, 29)
replace age5year = 4 if inrange(age, 30, 34)
replace age5year = 5 if inrange(age, 35, 39)
replace age5year = 6 if inrange(age, 40, 44)
replace age5year = 7 if inrange(age, 45, 49)

label define age5lab ///
    1 "15-19" 2 "20-24" 3 "25-29" 4 "30-34" ///
    5 "35-39" 6 "40-44" 7 "45-49"
label values age5year age5lab
codebook age5year

* --- Urban/rural
gen urban = .
replace urban = 1 if v025 == 1
replace urban = 0 if v025 == 2
label define urbanlab 0 "Rural" 1 "Urban"
label values urban urbanlab

* --- Marital status (collapsed to 3 categories)
gen marstat2 = .
replace marstat2 = 1 if v501 == 0
replace marstat2 = 2 if inlist(v501, 1, 2)
replace marstat2 = 3 if inlist(v501, 3, 4, 5)
label define marstat2_lab ///
    1 "Never married" 2 "Married/cohabiting" 3 "Previously married"
label values marstat2 marstat2_lab
codebook marstat2

* --- Education level (3-category; used in regression models)
* NOTE: educlvl3 is used throughout to ensure consistency with regression.
*       Do not substitute educlvl (4-category) in models.
gen educlvl3 = .
replace educlvl3 = 0 if v106 == 0
replace educlvl3 = 1 if v106 == 1
replace educlvl3 = 2 if inlist(v106, 2, 3)
label define educlvl3_lab ///
    0 "No education" 1 "Primary" 2 "Secondary or higher"
label values educlvl3 educlvl3_lab
codebook educlvl3

* --- Wealth quintile
gen wealthq = v190
label define wealthq_lab ///
    1 "Poorest" 2 "Poorer" 3 "Middle" 4 "Richer" 5 "Richest"
label values wealthq wealthq_lab
codebook wealthq

* --- Currently working
gen currwork = v714
label define currwork_lab 0 "Not working" 1 "Working"
label values currwork currwork_lab
codebook currwork

* --- Relationship to household head (5-category)

gen relhh5 = .
replace relhh5 = 1 if v150 == 1
replace relhh5 = 2 if v150 == 2
replace relhh5 = 3 if inlist(v150, 3, 5, 11)
replace relhh5 = 4 if inlist(v150, 4, 6, 7, 8, 10)
replace relhh5 = 5 if inlist(v150, 12, 13, 14, 15, 98)
label define relhh5_lbl ///
    1 "Head" 2 "Spouse" 3 "Child" ///
    4 "Extended family" 5 "Non-relative/other"
label values relhh5 relhh5_lbl

* --- Household composition
gen nolvchi = v218   // number of living children
gen under5  = v137   // children under 5 in household
gen nohhm   = v136   // total household members

* --- Age at first sex
codebook v525
gen afs = v525
replace afs = . if v525 > 49   // excludes union-only responses

* --- Survey weight and design declaration
gen wt = v005 / 1000000
svyset v021 [pweight=wt], strata(v022)


*==============================================================================
* 8. MISSING DATA CHECK
*    FIX: relhh corrected to relhh5 (the actual variable name)
*==============================================================================

misstable summarize country age age5year cohort10 relhh5 marstat2 educlvl3 ///
    wealthq currwork roof4 cookfuel3 under5 nohhm urban morb_cat


*==============================================================================
* 9. DESCRIPTIVE TABLE (TABLE 1)
*    FIX: relhh corrected to relhh5
*==============================================================================

table1_mc, vars( ///
    country   cat  \ ///
    age       conts \ ///
    age5year  cat  \ ///
    cohort10  cat  \ ///
    relhh5    cat  \ ///
    marstat2  cat  \ ///
    educlvl3  cat  \ ///
    wealthq   cat  \ ///
    currwork  cat  \ ///
    roof4     cat  \ ///
    cookfuel3 cat  \ ///
    nolvchi   conts \ ///
    under5    conts \ ///
    nohhm     conts \ ///
    urban     cat) ///
    by(morb_cat) saving("Table1_4countries_v2.xlsx", replace)


*==============================================================================
* 10. ACCESS TO CARE GAP: UNDIAGNOSED HYPERTENSION
*==============================================================================

* --- Generate undiagnosed hypertension variable
gen hbp_undiag = .
replace hbp_undiag = 1 if hbp_measured == 1 & hbp_diag == 0
replace hbp_undiag = 0 if hbp_measured == 1 & hbp_diag == 1

* --- Anchor scalar counts to confirm headline statistic
count if hbp_measured == 1 & hbp_diag == 0 & !missing(hbp_measured, hbp_diag)
scalar b_disc = r(N)
display "Measured HBP, not diagnosed (b):    " b_disc

count if hbp_measured == 0 & hbp_diag == 1 & !missing(hbp_measured, hbp_diag)
scalar c_disc = r(N)
display "Diagnosed without measured HBP (c): " c_disc

count if !missing(morb_cat)
scalar n_total = r(N)
display "Analytic sample (denominator):       " n_total

display "Undiagnosed HBP as % of analytic sample: " ///
    string(b_disc / n_total * 100, "%5.2f") "%"

* --- McNemar's Test: Is the diagnosis gap statistically significant?
* H0: P(measured HBP) = P(self-reported diagnosis)
* Uses discordant pairs only; appropriate for paired/repeated binary measurements
scalar chi2_mc = (b_disc - c_disc)^2 / (b_disc + c_disc)
scalar p_mc    = chi2tail(1, chi2_mc)
display _newline "--- McNemar's Test (unweighted) ---"
display "chi2(1) = " %6.2f chi2_mc
display "p-value = " %8.6f p_mc

* --- Survey-weighted difference test (use this in paper)
svy: mean hbp_measured hbp_diag
lincom hbp_measured - hbp_diag   // difference, 95% CI, p-value

* --- Country-stratified weighted test
foreach c in 1 2 3 4 {
    display _newline "--- Country `c' ---"
    quietly svy, subpop(if country == `c'): mean hbp_measured hbp_diag
    lincom hbp_measured - hbp_diag
}

* --- Treatment gap among diagnosed
count if hbp_diag == 1 & hbp_med == 0
scalar n_diag_unmed = r(N)
count if hbp_diag == 1 & !missing(hbp_med)
scalar n_diag_wmed = r(N)
display _newline "Diagnosed but not on treatment: " n_diag_unmed ///
    " (" string(n_diag_unmed / n_diag_wmed * 100, "%5.1f") "% of diagnosed)"

svy: tab country hbp_med if hbp_diag == 1, row   // weighted treatment by country

* --- HIV status among undiagnosed women
gen hiv_undiag = hiv03 if hbp_undiag == 1

tab hiv03 if hbp_undiag == 1 [aw=wt]
tab country hiv03 if hbp_undiag == 1 [aw=wt], row

* --- Appendix tables
tab hbp_undiag country, col
tab hiv_undiag country, col


*==============================================================================
* 11. PERCENTAGE VARIABLES FOR GRAPHING
*==============================================================================

gen hbp_measured_pct  = hbp_measured  * 100
gen hbp_diag_pct      = hbp_diag      * 100
gen hbp_med_pct       = hbp_med       * 100
gen hbp_undiag_pct    = hbp_undiag    * 100
gen hiv_undiag_pct    = hiv_undiag    * 100


*==============================================================================
* 12. FIGURES
*==============================================================================

* --- Figure 1: Measured vs Diagnosed Hypertension by Country
graph bar (mean) hbp_measured_pct hbp_diag_pct [aw=wt], over(country) ///
    ytitle("Percent (%)") ylabel(0(5)50) ///
    legend(label(1 "Measured") label(2 "Diagnosed")) ///
    title("Measured vs Diagnosed Hypertension by Country") ///
    blabel(bar, format(%4.1f))

* --- Figure 2: Diagnosed vs Treated Hypertension by Country
graph bar (mean) hbp_diag_pct hbp_med_pct [aw=wt], over(country) ///
    ytitle("Percent (%)") ylabel(0(5)50) ///
    legend(label(1 "Diagnosed") label(2 "On treatment")) ///
    title("Diagnosed and Treated Hypertension by Country") ///
    blabel(bar, format(%4.1f))

* --- Figure 3: Stacked care cascade (treated vs diagnosed-untreated)
gen hbp_diag_unmed_pct = hbp_diag_pct - hbp_med_pct

graph bar (mean) hbp_med_pct hbp_diag_unmed_pct [aw=wt], over(country) stack ///
    ytitle("Prevalence in total population (%)") ///
    legend(label(1 "Treated") label(2 "Diagnosed, untreated")) ///
    title("Hypertension Care Cascade by Country") ///
    blabel(bar, position(center) format(%4.1f))

* --- Figure 4: Estimated total hypertension burden (counts)
graph bar (sum) hbp_measured hbp_diag hbp_med [aw=wt], over(country) ///
    ytitle("Total number of women") ///
    ylabel(, format(%11.0fc)) ///
    legend(label(1 "Measured") label(2 "Diagnosed") label(3 "Treated")) ///
    title("Hypertension Burden by Country") ///
    subtitle("Estimated population totals") ///
    bar(1, color(navy)) bar(2, color(ebblue)) bar(3, color(ltblue))

* --- Figure 5: Age at first sex by birth cohort
graph bar (mean) afs, over(cohort10) ///
    ytitle("Mean age at first sex") ///
    title("Mean Age at First Sex by Birth Cohort") ///
    blabel(bar, format(%4.1f))


*==============================================================================
* 13. SURVEY-WEIGHTED CASCADE OF CARE FIGURE (BY COUNTRY)
*     Denominator: all women in each country's analytic sample
*     Each bar shows prevalence as a proportion of all women (not just measured)
*==============================================================================

* Population-level treatment: recode undiagnosed as not on treatment
* so that the denominator is consistent across all three cascade steps
gen hbp_med_pop = hbp_med
replace hbp_med_pop = 0 if hbp_diag == 0 & !missing(hbp_diag)
codebook hbp_med_pop

preserve

tempname mem
tempfile casc

postfile `mem' country_id                   ///
    pct_meas lo_meas hi_meas n_meas         ///
    pct_diag lo_diag hi_diag n_diag         ///
    pct_treat lo_treat hi_treat n_treat     ///
    using `casc'

forvalues c = 1/4 {
    quietly svy, subpop(if country == `c'): ///
        mean hbp_measured hbp_diag hbp_med_pop
    matrix rt = r(table)

    local pm  = rt[1,1] * 100
    local lom = rt[5,1] * 100
    local him = rt[6,1] * 100

    local pd  = rt[1,2] * 100
    local lod = rt[5,2] * 100
    local hid = rt[6,2] * 100

    local pt  = rt[1,3] * 100
    local lot = rt[5,3] * 100
    local hit = rt[6,3] * 100

    quietly count if country == `c' & hbp_measured == 1
    local n1 = r(N)
    quietly count if country == `c' & hbp_diag == 1
    local n2 = r(N)
    quietly count if country == `c' & hbp_med_pop == 1
    local n3 = r(N)

    post `mem' (`c')                        ///
        (`pm') (`lom') (`him') (`n1')       ///
        (`pd') (`lod') (`hid') (`n2')       ///
        (`pt') (`lot') (`hit') (`n3')
}

postclose `mem'
use `casc', clear

gen country_name = ""
replace country_name = "Lesotho"      if country_id == 1
replace country_name = "Ghana"        if country_id == 2
replace country_name = "Namibia"      if country_id == 3
replace country_name = "South Africa" if country_id == 4

* X-axis positions: 3 bars per country, 1-unit gap between groups
gen x_meas  = (country_id - 1) * 4 + 1
gen x_diag  = (country_id - 1) * 4 + 2
gen x_treat = (country_id - 1) * 4 + 3

gen id = _n
reshape long pct_ lo_ hi_ n_ x_, i(id country_id country_name) j(step) string

rename pct_ pct
rename lo_  lo
rename hi_  hi
rename n_   n_count
rename x_   xpos

gen step_n = 1 if step == "meas"
replace step_n = 2 if step == "diag"
replace step_n = 3 if step == "treat"
label define steplbl 1 "Measured HBP" 2 "Diagnosed HBP" 3 "On treatment"
label values step_n steplbl
sort country_id step_n

gen lbl = string(pct, "%4.1f") + "%"

* Print verification table before graphing
display _newline "=== HBP Cascade of Care: Weighted Prevalence by Country ==="
list country_name step pct lo hi n_count, noobs sep(3) ab(20)

twoway ///
    (bar pct xpos if step_n == 1, fcolor(navy)   lcolor(none) barwidth(0.75)) ///
    (bar pct xpos if step_n == 2, fcolor(ebblue) lcolor(none) barwidth(0.75)) ///
    (bar pct xpos if step_n == 3, fcolor(ltblue) lcolor(none) barwidth(0.75)) ///
    (rcap lo hi xpos, lcolor(gs4) lwidth(vthin) msize(tiny)) ///
    (scatter hi xpos, msymbol(none) mlabel(lbl) mlabpos(12) ///
        mlabsize(vsmall) mlabgap(2) mlabcolor(gs4)), ///
    xlabel( ///
        2  `" "Lesotho" "'      ///
        6  `" "Ghana" "'        ///
        10 `" "Namibia" "'      ///
        14 `" "South Africa" "', noticks nogrid) ///
    xtitle("") ///
    ytitle("Survey-weighted prevalence (%)") ///
    ylabel(0(5)35, angle(horizontal) grid glcolor(gs15)) ///
    xscale(range(0.25 15.75)) ///
    title("HBP Cascade of Care by Country", size(medium) margin(b=2)) ///
    subtitle("Women aged 15-49 years", size(small)) ///
    legend( ///
        order(1 "Measured HBP" 2 "Diagnosed HBP" 3 "On treatment") ///
        rows(1) pos(6) size(small) symxsize(5)) ///
    note("Survey-weighted proportions with 95% confidence intervals." ///
         "Denominator: all women in each country's analytic sample.", ///
         size(vsmall)) ///
    scheme(s2color) name(hbp_cascade, replace)

graph export "fig_hbp_cascade_care.png", replace width(2400) height(1600)

restore


*==============================================================================
* 14. SAVE FINAL ANALYTIC DATASET
*==============================================================================

save "women_hiv_merged_analysis_v2.dta", replace

display as result _newline "01_dataexploration.do completed successfully."
