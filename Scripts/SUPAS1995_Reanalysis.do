clear all
capture log close
// cd "/Users/mikey/Documents/Academic/MIT/Esther Indo/Mikey_Indo"
log using "Logs/SUPAS1995_Reanalysis.log", replace
// ssc install reghdfe
// ssc install ivreg2
// ssc install estout
// ssc install ftools
// ssc install avar
// ssc install weakivtest
// ssc install weakiv
// ssc install ranktest
// ssc install boottest 


* Redoing Duflo (2001)'s analysis of 1995 SUPAS

* Loading and clean data

use "RawData/original_Duflo_2001_inpres_data.dta", clear
merge m:1 birthpl using "RawData/regency_level_vars_Roodman.dta", keep(match master)
rename ch71 kids_in_birthpl
rename ch71new newkids_in_birthpl
rename nin schools_built
rename ninnew newschools_built
rename yeduc education
rename treat2b young
rename treat1b old
rename p504thn YOB
rename lwage ln_monthly_wage
rename lhwage ln_hourly_wage
rename recp treatment_village
rename birthpl birthpl
rename wsppc water_program
rename p504th birthyear_1950_last
keep kids_in_birthpl newkids_in_birthpl schools_built newschools_built education young old YOB ln_hourly_wage ln_monthly_wage treatment_village birthpl weight
drop if missing(ln_hourly_wage)
generate pooled_YOB = cond(YOB < 62, 100, YOB)
generate older = (YOB < 56)

qui xi i.young*schools_built i.young*newschools_built i.pooled_YOB*schools_built i.pooled_YOB*newschools_built i.YOB*kids_in_birthpl i.YOB*newkids_in_birthpl

xtset birthpl


local YOB_X_kids_in_birthpl = "_IYOBXkids*"
local YOB_X_newkids_in_birthpl = "_IYOBXnewk*"
local birthyr_FEs = "_IYOB_*"
local pooled_YOB_X_schools_built = "_IpooXsch*"
local pooled_YOB_X_newschools_built = "_IpooXnew*"
local young_X_schools_built = "_IyouXschoo_1"
local young_X_newschools_built = "_IyouXnewsc_1"


* Table 1

* I do Panel D first because Panels A, B, and C use a subset of the data, while Panel D uses the whole thing.

* Panel D: 2SLS using interaction of Year of Birth dummies (pooling all those born before 1962 into one dummy) and Schools Constructed


eststo, title("Esther"): qui xtivreg2 ln_hourly_wage (education = `pooled_YOB_X_schools_built') `birthyr_FEs' `YOB_X_kids_in_birthpl', partial(`birthyr_FEs' `YOB_X_kids_in_birthpl') small fe
boottest, ar reps(9999)
qui ivreg2 ln_hourly_wage (education = `pooled_YOB_X_schools_built') `birthyr_FEs' `YOB_X_kids_in_birthpl' i.birthpl, partial(`birthyr_FEs' `YOB_X_kids_in_birthpl' i.birthpl) small
weakivtest

eststo, title("Cluster"): qui xtivreg2 ln_hourly_wage (education = `pooled_YOB_X_schools_built') `birthyr_FEs' `YOB_X_kids_in_birthpl', partial(`birthyr_FEs' `YOB_X_kids_in_birthpl') cluster(birthpl) small fe
boottest, ar reps(9999)
qui ivreg2 ln_hourly_wage (education = `pooled_YOB_X_schools_built') `birthyr_FEs' `YOB_X_kids_in_birthpl' i.birthpl, partial(`birthyr_FEs' `YOB_X_kids_in_birthpl' i.birthpl) cluster(birthpl) small
weakivtest

eststo, title("Typos"): qui xtivreg2 ln_hourly_wage (education = `pooled_YOB_X_newschools_built') `birthyr_FEs' `YOB_X_newkids_in_birthpl', partial(`birthyr_FEs' `YOB_X_newkids_in_birthpl') cluster(birthpl) small fe
boottest, ar reps(9999)
qui ivreg2 ln_hourly_wage (education = `pooled_YOB_X_newschools_built') `birthyr_FEs' `YOB_X_newkids_in_birthpl' i.birthpl, partial(`birthyr_FEs' `YOB_X_newkids_in_birthpl' i.birthpl) cluster(birthpl) small
weakivtest

eststo, title("Weights"): qui xtivreg2 ln_hourly_wage (education = `pooled_YOB_X_newschools_built') `birthyr_FEs' `YOB_X_newkids_in_birthpl' [aw=weight], partial(`birthyr_FEs' `YOB_X_newkids_in_birthpl') cluster(birthpl) small fe
boottest, ar reps(9999)
qui ivreg2 ln_hourly_wage (education = `pooled_YOB_X_newschools_built') `birthyr_FEs' `YOB_X_newkids_in_birthpl' i.birthpl [aw=weight], partial(`birthyr_FEs' `YOB_X_newkids_in_birthpl' i.birthpl) cluster(birthpl) small
weakivtest

esttab, b(%6.3f) se(%6.3f) title("Table 1D: 2SLS using interaction of YOB Dummies with Schools Constructed") mtitles noconstant nonumbers /*noobs*/ nonotes nolabel keep(education) varwidth(13) coeflabels(education "ln(Hour Wage)")



* Panels A, B, and C restrict analysis to those in the Old and Young cohorts.

keep if (young == 1 | old == 1)

* Panel A: First Stage

quietly eststo clear
eststo, title("Duflo"): quietly reghdfe education young##c.schools_built YOB#c.kids_in_birthpl, absorb(birthpl YOB)
eststo, title("Cluster"): quietly reghdfe education young##c.schools_built YOB#c.kids_in_birthpl, absorb(birthpl YOB) vce(cluster birthpl)
eststo, title("Typos"): quietly reghdfe education young##c.newschools_built YOB#c.newkids_in_birthpl, absorb(birthpl YOB) vce(cluster birthpl)
eststo, title("Weights"): quietly reghdfe education young##c.newschools_built YOB#c.newkids_in_birthpl [aw = weight], absorb(birthpl YOB) vce(cluster birthpl)
esttab, b(%6.3f) se(%6.3f) title("Table 1A: First Stage (Years of Schooling)") mtitles noconstant nonumbers noobs nonotes nolabel varwidth(12) keep(1.young*#c.schools_built*) coeflabels(1.young#c.schools_built "Education" 1.young#c.newschools_built "Education")


* Panel B: Reduced Form

eststo clear
eststo, title("Duflo"): quietly reghdfe ln_hourly_wage young##c.schools_built YOB#c.kids_in_birthpl, absorb(birthpl YOB)
eststo, title("Cluster"): quietly reghdfe ln_hourly_wage young##c.schools_built YOB#c.kids_in_birthpl, absorb(birthpl YOB) vce(cluster birthpl)
eststo, title("Typos"): quietly reghdfe ln_hourly_wage young##c.newschools_built YOB#c.newkids_in_birthpl, absorb(birthpl YOB) vce(cluster birthpl)
eststo, title("Weights"): quietly reghdfe ln_hourly_wage young##c.newschools_built YOB#c.newkids_in_birthpl [aw = weight], absorb(birthpl YOB) vce(cluster birthpl)
esttab, b(%6.3f) se(%6.3f) title("Table 1B: Reduced Form (log Hourly Wage)") mtitles noconstant nonumbers noobs nonotes nolabel varwidth(13) keep(1.young*#c.schools_built*) coeflabels(1.young#c.schools_built "ln(Hour Wage)" 1.young#c.newschools_built "ln(Hour Wage)")


* Panel C: 2SLS using interaction of Young Dummy with Schools Constructed as instrument, subset to only Young and Old cohorts

eststo clear
eststo, title("Esther"): qui xtivreg2 ln_hourly_wage (education = `young_X_schools_built') `birthyr_FEs' `YOB_X_kids_in_birthpl', partial(`birthyr_FEs' `YOB_X_kids_in_birthpl') small fe
boottest, ar reps(9999)
qui ivreg2 ln_hourly_wage (education = `young_X_schools_built') `birthyr_FEs' `YOB_X_kids_in_birthpl' i.birthpl, partial(`birthyr_FEs' `YOB_X_kids_in_birthpl' i.birthpl) small
weakivtest

eststo, title("Cluster"): qui xtivreg2 ln_hourly_wage (education = `young_X_schools_built') `birthyr_FEs' `YOB_X_kids_in_birthpl', partial(`birthyr_FEs' `YOB_X_kids_in_birthpl') cluster(birthpl) small fe
boottest, ar reps(9999)
qui ivreg2 ln_hourly_wage (education = `young_X_schools_built') `birthyr_FEs' `YOB_X_kids_in_birthpl' i.birthpl, partial(`birthyr_FEs' `YOB_X_kids_in_birthpl' i.birthpl) cluster(birthpl) small
weakivtest

eststo, title("Typos"): qui xtivreg2 ln_hourly_wage (education = `young_X_newschools_built') `birthyr_FEs' `YOB_X_newkids_in_birthpl', partial(`birthyr_FEs' `YOB_X_newkids_in_birthpl') cluster(birthpl) small fe
boottest, ar reps(9999)
qui ivreg2 ln_hourly_wage (education = `young_X_newschools_built') `birthyr_FEs' `YOB_X_newkids_in_birthpl' i.birthpl, partial(`birthyr_FEs' `YOB_X_newkids_in_birthpl' i.birthpl) cluster(birthpl) small
weakivtest

eststo, title("Weights"): qui xtivreg2 ln_hourly_wage (education = `young_X_newschools_built') `birthyr_FEs' `YOB_X_newkids_in_birthpl' [aw=weight], partial(`birthyr_FEs' `YOB_X_newkids_in_birthpl') cluster(birthpl) small fe
boottest, ar reps(9999)
qui ivreg2 ln_hourly_wage (education = `young_X_newschools_built') `birthyr_FEs' `YOB_X_newkids_in_birthpl' i.birthpl [aw=weight], partial(`birthyr_FEs' `YOB_X_newkids_in_birthpl' i.birthpl) cluster(birthpl) small
weakivtest


esttab, b(%6.3f) se(%6.3f) title("Table 1C: 2SLS using interaction of Young Dummy with Schools Constructed") mtitles noconstant nonumbers /*noobs*/ nonotes nolabel keep(education) varwidth(13) coeflabels(education "ln(Hour Wage)")

log close
