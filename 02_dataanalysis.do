*==============================================================================
* 02_dataanalysis.do
* Project : Co-occurrence of HIV and Hypertension in Four African Countries
* Purpose : Main multinomial logistic regression, predicted probabilities,
*           access-to-care gap tests, treatment analysis, and
*           observed/expected ratio secondary analysis
* Author  : Takhona Hlatshwako
* Date    : September 23, 2026
* Stata   : Version 19
* Requires: women_hiv_merged_analysis_v2.dta (produced by 01_dataexploration.do)
*           estout package: ssc install estout
*==============================================================================

clear all
cd "/Users/..."   // <- change me

use "women_hiv_merged_analysis_v2.dta", clear

codebook age hbp_measured hbp_diag morb_cat
tab hbp_diag country
tab hbp_measured hbp_diag

drop if missing(morb_cat)


*==============================================================================
* 1. SURVEY DESIGN DECLARATION
*==============================================================================

gen wt = v005 / 1000000
svyset v021 [pweight=wt], strata(v022)
svydescribe
svy: tab morb_cat


*==============================================================================
* 2. EXPLORATORY LOGIT MODELS (unweighted, by country)
*    Reported for comparison with prior literature (e.g., Egede et al.)
*==============================================================================

* Lesotho
logit hbp_diag     i.hiv03 if country == 1, or
logit hbp_measured i.hiv03 if country == 1, or

* Namibia
logit hbp_diag     i.hiv03 if country == 3, or
logit hbp_measured i.hiv03 if country == 3, or

* South Africa
logit hbp_diag     i.hiv03 if country == 4, or
logit hbp_measured i.hiv03 if country == 4, or


*==============================================================================
* 3. ACCESS TO CARE GAP: McNemar's TEST
*    Tests whether P(measured HBP) = P(self-reported diagnosis).
*    McNemar's test is appropriate here because hbp_measured and hbp_diag
*    are two binary measurements on the same women (paired proportions).
*==============================================================================

* Extract discordant cell counts
count if hbp_measured == 1 & hbp_diag == 0 & !missing(hbp_measured, hbp_diag)
scalar b_disc = r(N)   // measured HBP, never diagnosed

count if hbp_measured == 0 & hbp_diag == 1 & !missing(hbp_measured, hbp_diag)
scalar c_disc = r(N)   // self-reported diagnosis, BP below threshold

display _newline "--- Discordant pairs ---"
display "Measured HBP, not diagnosed (b):         " b_disc
display "Diagnosed without measured HBP (c):      " c_disc
display "Total discordant pairs (b + c):           " b_disc + c_disc

* McNemar's test statistic
scalar chi2_mc = (b_disc - c_disc)^2 / (b_disc + c_disc)
scalar p_mc    = chi2tail(1, chi2_mc)

display _newline "--- McNemar's Test (unweighted) ---"
display "chi2(1) = " %6.2f chi2_mc
display "p-value = " %8.6f p_mc

* Survey-weighted test: use this result in the paper
svy: mean hbp_measured hbp_diag
lincom hbp_measured - hbp_diag   // weighted difference, 95% CI, p-value

* Country-stratified weighted test
foreach c in 1 2 3 4 {
    display _newline "--- Country `c' ---"
    quietly svy, subpop(if country == `c'): mean hbp_measured hbp_diag
    lincom hbp_measured - hbp_diag
}


*==============================================================================
* 4. MAIN MULTINOMIAL LOGISTIC REGRESSION
*    Outcome: morb_cat (1=HIV only, 2=HBP only, 3=HIV-HBP, 4=Neither)
*    Base outcome: 4 (Neither)
*==============================================================================

* Unweighted model (sanity check / comparison)
mlogit morb_cat ib4.cohort10 i.country i.marstat2 i.educlvl3 i.wealthq ///
    i.currwork i.roof4 i.cookfuel3 i.urban, ///
    baseoutcome(4) vce(cluster v021) rrr

* Survey-weighted main model
svy: mlogit morb_cat ib4.cohort10 i.country i.marstat2 i.educlvl3 i.wealthq ///
    i.currwork i.roof4 i.cookfuel3 i.urban, ///
    baseoutcome(4) rrr


*==============================================================================
* 5. PREDICTED PROBABILITIES (MARGINAL EFFECTS)
*==============================================================================

* HIV-HBP comorbidity by birth cohort (outcome 3)
margins cohort10, predict(outcome(3))
marginsplot, ///
    ytitle("Predicted probability") xtitle("Birth cohort") ///
    title("Predicted Probability: HIV-HBP Comorbidity")

* HBP only (outcome 2)
margins cohort10, predict(outcome(2))

* HIV only (outcome 1)
margins cohort10, predict(outcome(1))
marginsplot

* All four outcomes simultaneously
margins cohort10, ///
    predict(outcome(1)) ///
    predict(outcome(2)) ///
    predict(outcome(3)) ///
    predict(outcome(4))

marginsplot, ///
    ytitle("Predicted probability") ///
    xtitle("Birth cohort") ///
    legend(order(1 "HIV only" 2 "HBP only" 3 "HIV-HBP" 4 "Neither")) ///
    title("Predicted Probabilities by Morbidity Category and Birth Cohort")


*==============================================================================
* 6. EXPORT RESULTS TABLE
*==============================================================================

svy: mlogit morb_cat ib4.cohort10 i.country i.marstat2 i.educlvl3 i.wealthq ///
    i.currwork i.roof4 i.cookfuel3 i.urban, ///
    baseoutcome(4) rrr

esttab using "Results_Table.rtf", replace   ///
    eform                                   ///
    cells("b(star fmt(2)) ci(fmt(2) par())") ///
    star(* 0.05 ** 0.01 *** 0.001)          ///
    mtitle("Multinomial Model")             ///
    collabels("RRR" "95% CI")               ///
    label nogaps compress                   ///
    addnotes(                               ///
        "Results are reported as Relative Risk Ratios (RRRs)." ///
        "Base outcome: Neither HIV nor Hypertension."          ///
        "* p<0.05  ** p<0.01  *** p<0.001")


*==============================================================================
* 7. HYPERTENSION TREATMENT ANALYSIS
*    Tests whether treatment uptake differs by country and by HIV status
*    among women who have been diagnosed with hypertension.
*
*    NOTE: Check unweighted cell sizes before reporting Ghana's estimate.
*    With only ~224 HIV-positive diagnosed women across all countries,
*    country-level cells may be too small to report reliably (< 25 obs).
*    Per DHS guidelines, flag estimates based on < 25 unweighted observations.
*==============================================================================

* Check unweighted cell sizes first
tab country hbp_med if hiv03 == 1 & hbp_diag == 1, missing
tab country hbp_med if hiv03 == 0 & hbp_diag == 1, missing

* Treatment among HIV-positive women with hypertension diagnosis
svy, subpop(if hiv03 == 1 & hbp_diag == 1): ///
    tabulate country hbp_med, row percent format(%9.1f)

* Treatment among HIV-negative women with hypertension diagnosis
svy, subpop(if hiv03 == 0 & hbp_diag == 1): ///
    tabulate country hbp_med, row percent format(%9.1f)

* Logistic regression: Does HIV status predict treatment uptake?
* Adjusts for country-level differences in both HIV prevalence and treatment rates
svy, subpop(if hbp_diag == 1): ///
    logit hbp_med i.hiv03 i.country, or

margins hiv03, predict(pr)
marginsplot, ///
    ytitle("Predicted probability of treatment") ///
    xtitle("HIV status") ///
    xlabel(0 "HIV negative" 1 "HIV positive") ///
    title("Predicted HBP Treatment Probability by HIV Status")

testparm i.hiv03   // formal test of whether HIV status is significant


*==============================================================================
* 8. SECONDARY ANALYSIS: OBSERVED/EXPECTED (O/E) RATIO
*    Tests whether HIV-HBP co-occurrence is more common than expected
*    if HIV and HBP were statistically independent
*==============================================================================

svy: mlogit morb_cat ib4.cohort10 i.country i.marstat2 i.educlvl3 i.wealthq ///
    i.currwork i.roof4 i.cookfuel3 i.urban, ///
    baseoutcome(4) rrr

gen has_hiv  = (morb_cat == 1 | morb_cat == 3)  // HIV only or HIV-HBP
gen has_htn  = (morb_cat == 2 | morb_cat == 3)  // HBP only or HIV-HBP
gen has_both = (morb_cat == 3)                   // HIV-HBP comorbidity

* Overall O/E ratio
svy: mean has_hiv has_htn has_both

scalar p_hiv = _b[has_hiv]
scalar p_htn = _b[has_htn]
scalar p_obs = _b[has_both]
scalar p_exp = p_hiv * p_htn

display _newline "--- Overall O/E Ratio ---"
display "Observed (HIV-HBP):         " p_obs
display "Expected (independence):    " p_exp
display "O/E Ratio:                  " p_obs / p_exp

* O/E ratio by birth cohort
levelsof cohort10, local(levels)
foreach l of local levels {
    display _newline "--- Birth Cohort: `l' ---"
    quietly svy, subpop(if cohort10 == `l'): mean has_hiv has_htn has_both
    matrix b    = e(b)
    scalar obs   = b[1,3]
    scalar exp_c = b[1,1] * b[1,2]
    scalar ratio = obs / exp_c
    display "Observed: " obs "  |  Expected: " exp_c "  |  O/E Ratio: " ratio
}

* Test for non-independence of HIV and HBP by country
svy: tabulate has_hiv has_htn, count format(%9.0f) pearson


*==============================================================================
* 9. COUNTRY-STRATIFIED MULTINOMIAL MODELS
*==============================================================================

forvalues c = 1/4 {
    display _newline "=========================================="
    display "Country: " `c'
    display "=========================================="

    quietly svy, subpop(if country == `c'): ///
        mlogit morb_cat ib4.cohort10 i.marstat2 i.educlvl3 i.wealthq ///
        i.currwork i.roof4 i.cookfuel3 i.urban, ///
        baseoutcome(4) rrr

    margins cohort10, predict(outcome(3))
    marginsplot, ///
        title("Country `c': HIV-HBP Comorbidity by Birth Cohort") ///
        ytitle("Predicted probability") ///
        name(marg_c`c', replace)
}

display as result _newline "02_dataanalysis.do completed successfully."
