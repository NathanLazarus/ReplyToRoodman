*** This creates the tables in the paper that walk through how we get fromm Roodman and Hsiao's specification to our preferred one

// ssc install reghdfe
// ssc install ivreg2
// ssc install avar
// ssc install weakivtest
// ssc install boottest 


cap log close
log using Logs/CompareToRoodmanAndHsiao.log, replace

cap program drop do_analysis
program define do_analysis
	args education regencies inflation omitSelfEmployed years survey_year_FEs weights regency_vars specification heads_of_household_only restrict_to_employed use_primary_for_education data_source

	use "CleanData/CompareToRoodmanPreppedData_`data_source'.dta", clear

		

	// adjust for inflation, 2013/14->1995 https://data.worldbank.org/indicator/FP.CPI.TOTL?end=2013&locations=US%E2%89%A4%2FSEURLD-ID&start=1995
	// NL: added 2011 and 2012, fixed typo of 2103 that was intended to say 2013

	if "`inflation'" == "ours" {
		replace B5R29 = B5R29 * (.194 / 1.054) if year == 2011  
		replace B5R29 = B5R29 * (.194 / 1.099) if year == 2012  
		replace B5R29 = B5R29 * (.194 / 1.169) if year == 2013  
		replace B5R29 = B5R29 * (.194 / 1.244) if year == 2014  
	}
	else if "`inflation'" == "Roodman" {
		replace B5R29 = B5R29 * (.194 / 1.244)
	}
	else if "`inflation'" == "Hsiao" {
	}
	else {
		di as error "argument: inflation not correctly specified"
		exit
	}


	if "`regencies'" == "ours" | "`regencies'" == "ours_with_imputation_weights" {
		recode birthpl (1472=1403) (1804=1803) (3275=3219) /*Unclear why Roodman assigns 3671 (Tangerang City) -> 3275 (Bekasi) -> 3219 (Tangerang), but the result is correct*/ ///
		(5171=5103) (5271=5201) (7173=7103) (7271=7203) (8271=8203) (8104=8103) (6473=6404) // group new child regencies with parents
		// NL: This is the same as Roodman's code because his regency-level vars manually duplicated observations for
		// each of these child regencies to be the same as their 71 parents
		// Here we just explictly map them to their 71 parents before merging
		// Roodman correctly points out that 7271 is a child of 7203 (not 7204) and 5171 is a child of 5103 (not 5101),
		// it's not clear why in merging Regency-level vars he uses those mistaken codings
		// Roodman has 6473 mapped to 6473 in his crosswalk but then no observation for it in Regency-level vars,
		// so we add it to the child regencies.

		replace birthpl = 8209 if birthpl_SUSENAS == 9427 // We think this is an error in Roodman's crosswalk

		// These are missed by Roodman's crosswalks and are therefore dropped in his analysis for missing birthpl, 9109 and 9428 have samples of about 1000 men, which is not negligible.
		replace birthpl = 1803 if birthpl_SUSENAS == 1813
		replace birthpl = 3209 if birthpl_SUSENAS == 3218
		replace birthpl = 8206 if birthpl_SUSENAS == 9109
		replace birthpl = 8203 if birthpl_SUSENAS == 9428
		replace birthpl_imputation_wt = 1 if inlist(birthpl_SUSENAS,1813,3218,9109,9428)

		gen birthplnew = birthpl
	}
	else if "`regencies'" == "Roodman" {
		
		recode birthpl (1472=1403) (1804=1803) (3275=3219) (5171=5103) (5271=5201) (7173=7103) (7271=7203) (8271=8203) (8104=8103), gen(birthplnew) // group new child regencies with parents
		replace birthpl = 7204 if birthpl==7271  // Duflo recoding

	}
	else if "`regencies'" == "Hsiao" {
		// This runs on the data file Hsiao sent us
		// use "HsiaoCodeAndData/susenas.dta", clear
		// merge m:1 kab_birth71 using "HsiaoCodeAndData/birth_districts.dta", nogen
		// gen birthpl_imputation_wt = 1
		// rename income_month B5R29
		// rename years_school years_schooling_Hsiao
		// rename age_1974 age74
		// rename hoh relate
		// gen birthyr = 1974 - age74
		// gen int dum = cond(birthyr<1962, 1900+100, birthyr)
		// gen young = 1 if inrange(age74, 2, 6)
		// replace young = 0 if inrange(age74, 12, 17)
		// gen birthplnew = birthpl
		

		keep if birthpl_imputation_wt > 0.5

		merge m:1 birthpl_SUSENAS using "Concordances/concordance_hsiao.dta", nogen
		cap drop birthpl_imputation_wt
		gen birthpl_imputation_wt = 1
		drop birthpl // This is our version of the concordance from the concordance_hsiao file
		rename birthpl_hsiao birthpl
		
		gen birthplnew = birthpl
	}
	else {
		di "argument: regencies not correctly specified"
		exit
	}

	if "`regency_vars'" == "Roodman" {
		qui merge m:1 birthpl using "RawData/regency_level_vars_Roodman", nogen update
	}
	else if "`regency_vars'" == "Hsiao" {
		merge m:1 birthpl using "RawData/hsiao_inpres_with_numeric_birthpl.dta"
		gen ninnew = nin
		gen ch71new = ch71
		gen en71new = en71
	}
	else {
		di "argument: regency_vars not correctly specified"
		exit
	}
	


	if "`education'" == "ours" {
		gen yeduc = years_schooling_correct
	}
	else if "`education'" == "Roodman" {
		gen yeduc = years_schooling_Roodman
	}
	else if "`education'" == "Hsiao" {
		gen yeduc = years_schooling_Hsiao
	}
	else {
		di as error "argument: education not correctly specified"
		exit
	}
	gen byte primary = yeduc>=6  // completed primary school
	if "`use_primary_for_education'" == "True" {
		replace yeduc = primary
	}


	if "`regencies'" == "Roodman" | "`regencies'" == "ours_with_imputation_weights" | "`regencies'" == "Hsiao" {
		local birthpl_imputation_wt_restrict = ""
	}
	else if "`regencies'" == "ours" {
		local birthpl_imputation_wt_restrict = "& birthpl_imputation_wt > 0.5"
	}
	else {
		di as error "argument: regencies not correctly specified"
		exit
	}

	if "`survey_year_FEs'" == "True" {
		local survey_year_FE_expression = "_Iyear_*"
	}
	else if "`survey_year_FEs'" == "False" {
		local survey_year_FE_expression = ""
	}
	else {
		di as error "argument: survey_year_FEs not correctly specified"
		exit
	}


	if "`omitSelfEmployed'" == "True" {
		local self_employed_restriction = "& self_employed == 0"
	}
	else if "`omitSelfEmployed'" == "False" {
		local self_employed_restriction = ""
	}
	else {
		di as error "argument: omitSelfEmployed not correctly specified"
		exit
	}


	if "`weights'" == "True" {
		if "`regencies'" == "ours_with_imputation_weights" {
			replace wt = wt * birthpl_imputation_wt
		}
		local weight_statement = "[pw=wt]"
		local weight_statement_ivreg2 = "[aw=wt]"
	}
	else if "`weights'" == "False" {
		if "`regencies'" == "ours_with_imputation_weights" {
			local weight_statement = "[pw=birthpl_imputation_wt]"
			local weight_statement_ivreg2 = "[aw=birthpl_imputation_wt]"
		}
		else {
			local weight_statement = ""
		}
	}
	else {
		di as error "argument: weights not correctly specified"
		exit
	}
		
	if "`specification'" == "Hsiao" {
		local additional_controls = "_IyouXch71n_1 _IyouXen71n_1 _IyouXwsppc_1"
		local additional_controls_manyIV = "_IbirXch7* _IbirXen7* _IbirXwsp*"
	}
	else if "`specification'" == "Roodman" {
		local additional_controls = "_IbirXch7*"
		local additional_controls_manyIV = "_IbirXch7*"
	}
	else {
		di as error "argument: specification not correctly specified"
		exit
	}



	if "`heads_of_household_only'" == "True" {
		local hoh_restriction = "& relate == 1"
	}
	else if "`heads_of_household_only'" == "False" {
		local hoh_restriction = ""
	}
	else {
		di as error "argument: heads_of_household_only not correctly specified"
		exit
	}
	
	if "`restrict_to_employed'" == "True" {
		local employed_restriction = "& employed == 1"
	}
	else if "`restrict_to_employed'" == "False" {
		local employed_restriction = ""
	}
	else {
		di as error "argument: restrict_to_employed not correctly specified"
		exit
	}

	

	gen lwage = ln(B5R29)
	xtset birthplnew



	qui xi i.young|ninnew i.dum|ninnew i.birthyr*ch71new i.birthyr*en71new i.birthyr*wsppc i.year i.young|ch71new i.young|en71new  i.young|wsppc
	set seed 230498257
	


	// First stage (young) including non-wage earners
	di "First stage (young) including non-wage earners"
	di "education: `education'; regencies: `regencies'; inflation: `inflation'; omitSelfEmployed: `omitSelfEmployed'; years: `years'; survey_year_FEs: `survey_year_FEs'; weights: `weights'; regency_vars: `regency_vars'; specification: `specification'; heads_of_household_only: `heads_of_household_only'; use_primary_for_education: `use_primary_for_education'; data_source: `data_source'"
	reghdfe yeduc _IyouXninne_1 _Ibirthyr_* `additional_controls' `survey_year_FE_expression' `weight_statement' if !missing(yeduc) & inlist(year,`years') `hoh_restriction' `birthpl_imputation_wt_restrict', cluster(birthplnew) absorb(birthplnew)


	// First stage (young)
	di "First stage (young)"
	di "education: `education'; regencies: `regencies'; inflation: `inflation'; omitSelfEmployed: `omitSelfEmployed'; years: `years'; survey_year_FEs: `survey_year_FEs'; weights: `weights'; regency_vars: `regency_vars'; specification: `specification'; heads_of_household_only: `heads_of_household_only'; use_primary_for_education: `use_primary_for_education'; data_source: `data_source'"
	reghdfe yeduc _IyouXninne_1 _Ibirthyr_* `additional_controls' `survey_year_FE_expression' `weight_statement' if !missing(lwage) & !missing(yeduc) & inlist(year,`years') `hoh_restriction' `birthpl_imputation_wt_restrict' `self_employed_restriction' `employed_restriction', cluster(birthplnew) absorb(birthplnew)

	// Reduced form (young)
	di "Reduced form (young)"
	di "education: `education'; regencies: `regencies'; inflation: `inflation'; omitSelfEmployed: `omitSelfEmployed'; years: `years'; survey_year_FEs: `survey_year_FEs'; weights: `weights'; regency_vars: `regency_vars'; specification: `specification'; heads_of_household_only: `heads_of_household_only'; use_primary_for_education: `use_primary_for_education'; data_source: `data_source'"
	reghdfe lwage _IyouXninne_1 _Ibirthyr_* `additional_controls' `survey_year_FE_expression' `weight_statement' if !missing(lwage) & !missing(yeduc) & inlist(year,`years') `hoh_restriction' `birthpl_imputation_wt_restrict' `self_employed_restriction' `employed_restriction', cluster(birthplnew) absorb(birthplnew)


	// Single IV (young)
	di "Single IV (young) xtivreg"
	di "education: `education'; regencies: `regencies'; inflation: `inflation'; omitSelfEmployed: `omitSelfEmployed'; years: `years'; survey_year_FEs: `survey_year_FEs'; weights: `weights'; regency_vars: `regency_vars'; specification: `specification'; heads_of_household_only: `heads_of_household_only'; use_primary_for_education: `use_primary_for_education'; data_source: `data_source'"
	xtivreg2 lwage (yeduc = _IyouXninne_1) _Ibirthyr_* `additional_controls' `survey_year_FE_expression' `weight_statement' if inlist(year,`years') `hoh_restriction' `birthpl_imputation_wt_restrict' `self_employed_restriction' `employed_restriction', cluster(birthplnew) partial(_Ibirthyr_* `additional_controls' `survey_year_FE_expression') small fe
	boottest, ar reps(99999)

	di "Single IV (young) weakivtest"
	di "education: `education'; regencies: `regencies'; inflation: `inflation'; omitSelfEmployed: `omitSelfEmployed'; years: `years'; survey_year_FEs: `survey_year_FEs'; weights: `weights'; regency_vars: `regency_vars'; specification: `specification'; heads_of_household_only: `heads_of_household_only'; use_primary_for_education: `use_primary_for_education'; data_source: `data_source'"
	qui ivreg2 lwage (yeduc = _IyouXninne_1) _Ibirthyr_* `additional_controls' `survey_year_FE_expression' i.birthplnew `weight_statement_ivreg2' if inlist(year,`years') `hoh_restriction' `birthpl_imputation_wt_restrict' `self_employed_restriction' `employed_restriction', partial(_Ibirthyr_* `additional_controls' `survey_year_FE_expression' i.birthplnew) cluster(birthplnew) small
	weakivtest



	// Many IV (birthyr)

	di "Many IV (birthyr) xtivreg"
	di "education: `education'; regencies: `regencies'; inflation: `inflation'; omitSelfEmployed: `omitSelfEmployed'; years: `years'; survey_year_FEs: `survey_year_FEs'; weights: `weights'; regency_vars: `regency_vars'; specification: `specification'; heads_of_household_only: `heads_of_household_only'; use_primary_for_education: `use_primary_for_education'; data_source: `data_source'"
	xtivreg2 lwage (yeduc = _IdumXnin*) _Ibirthyr_* `additional_controls_manyIV' `survey_year_FE_expression' `weight_statement' if inlist(year,`years') `hoh_restriction' `birthpl_imputation_wt_restrict' `self_employed_restriction' `employed_restriction', cluster(birthplnew) partial(_Ibirthyr_* `additional_controls_manyIV' `survey_year_FE_expression') small fe
	boottest, ar reps(99999)

	di "Many IV (birthyr) weakivtest"
	di "education: `education'; regencies: `regencies'; inflation: `inflation'; omitSelfEmployed: `omitSelfEmployed'; years: `years'; survey_year_FEs: `survey_year_FEs'; weights: `weights'; regency_vars: `regency_vars'; specification: `specification'; heads_of_household_only: `heads_of_household_only'; use_primary_for_education: `use_primary_for_education'; data_source: `data_source'"
	qui ivreg2 lwage (yeduc = _IdumXnin*) _Ibirthyr_* `additional_controls_manyIV' `survey_year_FE_expression' i.birthplnew `weight_statement_ivreg2' if inlist(year,`years') `hoh_restriction' `birthpl_imputation_wt_restrict' `self_employed_restriction' `employed_restriction', partial(_Ibirthyr_* `additional_controls_manyIV' `survey_year_FE_expression' i.birthplnew) cluster(birthplnew) small
	weakivtest


end


// Starting from Hsiao

local education = "Hsiao" // "Roodman", "Hsiao" or "ours"
local regencies = "Hsiao" // "Roodman", "Hsiao", "ours", or "ours_with_imputation_weights"
local inflation = "Hsiao" // "Roodman", "Hsiao" or "ours"
local omitSelfEmployed = "True" // "False" or "True"
local years = "2011,2012,2013,2014" // "2013,2014" or "2011,2012,2013,2014"
local survey_year_FEs = "True" // "False" or "True"
local weights = "False" // "False" or "True"
local regency_vars = "Hsiao" // "Roodman" or "Hsiao"
local specification = "Hsiao" // "Roodman" or "Hsiao"
local heads_of_household_only = "True" // "False" or "True"
local restrict_to_employed = "True" // "False" or "True"
local use_primary_for_education = "False" // "False" or "True"
local data_source = "HarvardLibrary" // "FullFour" or "HarvardLibrary"


do_analysis `education' `regencies' `inflation' `omitSelfEmployed' `years' `survey_year_FEs' `weights' `regency_vars' `specification' `heads_of_household_only' `restrict_to_employed' `use_primary_for_education' `data_source'

local regency_vars = "Roodman" // Corrects Esther typos (there are also a few ninpres values where Hsiao disagrees with both Esther and Roodman, unclear)

do_analysis `education' `regencies' `inflation' `omitSelfEmployed' `years' `survey_year_FEs' `weights' `regency_vars' `specification' `heads_of_household_only' `restrict_to_employed' `use_primary_for_education' `data_source'

local inflation = "ours" // Hsiao doesn't correct for inflation
local regencies = "ours" // This uses our regency definitions

do_analysis `education' `regencies' `inflation' `omitSelfEmployed' `years' `survey_year_FEs' `weights' `regency_vars' `specification' `heads_of_household_only' `restrict_to_employed' `use_primary_for_education' `data_source'

local education = "ours"

do_analysis `education' `regencies' `inflation' `omitSelfEmployed' `years' `survey_year_FEs' `weights' `regency_vars' `specification' `heads_of_household_only' `restrict_to_employed' `use_primary_for_education' `data_source'

local data_source = "FullFour"

do_analysis `education' `regencies' `inflation' `omitSelfEmployed' `years' `survey_year_FEs' `weights' `regency_vars' `specification' `heads_of_household_only' `restrict_to_employed' `use_primary_for_education' `data_source'

local heads_of_household_only = "False"
local restrict_to_employed = "False"

do_analysis `education' `regencies' `inflation' `omitSelfEmployed' `years' `survey_year_FEs' `weights' `regency_vars' `specification' `heads_of_household_only' `restrict_to_employed' `use_primary_for_education' `data_source'

local specification = "Roodman" // This runs the regressions with Roodman's controls (birth year*children in district) instead of Hsiao's (young*children in district, young*number of enrolled children, young*water and sanitation spending)
local survey_year_FEs = "False" // Hsiao also includes survey year fixed effects

do_analysis `education' `regencies' `inflation' `omitSelfEmployed' `years' `survey_year_FEs' `weights' `regency_vars' `specification' `heads_of_household_only' `restrict_to_employed' `use_primary_for_education' `data_source'


// Starting from Roodman

local education = "Roodman" // "Roodman", "Hsiao" or "ours"
local regencies = "Roodman" // "Roodman", "Hsiao", "ours", or "ours_with_imputation_weights"
local inflation = "Roodman" // "Roodman", "Hsiao" or "ours"
local omitSelfEmployed = "False" // "False" or "True"
local years = "2013,2014" // "2013,2014" or "2011,2012,2013,2014"
local survey_year_FEs = "False" // "False" or "True"
local weights = "False" // "False" or "True"
local regency_vars = "Roodman" // "Roodman" or "Hsiao"
local specification = "Roodman" // "Roodman" or "Hsiao"
local heads_of_household_only = "False" // "False" or "True"
local restrict_to_employed = "False" // "False" or "True"
local use_primary_for_education = "False" // "False" or "True"
local data_source = "FullFour" // "FullFour" or "HarvardLibrary"

// Roodman's numbers
do_analysis `education' `regencies' `inflation' `omitSelfEmployed' `years' `survey_year_FEs' `weights' `regency_vars' `specification' `heads_of_household_only' `restrict_to_employed' `use_primary_for_education' `data_source'

local education = "ours"

do_analysis `education' `regencies' `inflation' `omitSelfEmployed' `years' `survey_year_FEs' `weights' `regency_vars' `specification' `heads_of_household_only' `restrict_to_employed' `use_primary_for_education' `data_source'

local regencies = "ours"
local inflation = "ours"

do_analysis `education' `regencies' `inflation' `omitSelfEmployed' `years' `survey_year_FEs' `weights' `regency_vars' `specification' `heads_of_household_only' `restrict_to_employed' `use_primary_for_education' `data_source'

local omitSelfEmployed = "True"

do_analysis `education' `regencies' `inflation' `omitSelfEmployed' `years' `survey_year_FEs' `weights' `regency_vars' `specification' `heads_of_household_only' `restrict_to_employed' `use_primary_for_education' `data_source'

local years = "2011,2012"

do_analysis `education' `regencies' `inflation' `omitSelfEmployed' `years' `survey_year_FEs' `weights' `regency_vars' `specification' `heads_of_household_only' `restrict_to_employed' `use_primary_for_education' `data_source'

local years = "2011,2012,2013,2014"

// Mikey's numbers
do_analysis `education' `regencies' `inflation' `omitSelfEmployed' `years' `survey_year_FEs' `weights' `regency_vars' `specification' `heads_of_household_only' `restrict_to_employed' `use_primary_for_education' `data_source'

local weights = "True"

do_analysis `education' `regencies' `inflation' `omitSelfEmployed' `years' `survey_year_FEs' `weights' `regency_vars' `specification' `heads_of_household_only' `restrict_to_employed' `use_primary_for_education' `data_source'




// Starting from Roodman (primary for education)

local education = "Roodman" // "Roodman", "Hsiao" or "ours"
local regencies = "Roodman" // "Roodman", "Hsiao", "ours", or "ours_with_imputation_weights"
local inflation = "Roodman" // "Roodman", "Hsiao" or "ours"
local omitSelfEmployed = "False" // "False" or "True"
local years = "2013,2014" // "2013,2014" or "2011,2012,2013,2014"
local survey_year_FEs = "False" // "False" or "True"
local weights = "False" // "False" or "True"
local regency_vars = "Roodman" // "Roodman" or "Hsiao"
local specification = "Roodman" // "Roodman" or "Hsiao"
local heads_of_household_only = "False" // "False" or "True"
local restrict_to_employed = "False" // "False" or "True"
local use_primary_for_education = "True" // "False" or "True"
local data_source = "FullFour" // "FullFour" or "HarvardLibrary"

// Roodman's numbers
do_analysis `education' `regencies' `inflation' `omitSelfEmployed' `years' `survey_year_FEs' `weights' `regency_vars' `specification' `heads_of_household_only' `restrict_to_employed' `use_primary_for_education' `data_source'

local education = "ours"

do_analysis `education' `regencies' `inflation' `omitSelfEmployed' `years' `survey_year_FEs' `weights' `regency_vars' `specification' `heads_of_household_only' `restrict_to_employed' `use_primary_for_education' `data_source'

local regencies = "ours"
local inflation = "ours"

do_analysis `education' `regencies' `inflation' `omitSelfEmployed' `years' `survey_year_FEs' `weights' `regency_vars' `specification' `heads_of_household_only' `restrict_to_employed' `use_primary_for_education' `data_source'

local omitSelfEmployed = "True"

do_analysis `education' `regencies' `inflation' `omitSelfEmployed' `years' `survey_year_FEs' `weights' `regency_vars' `specification' `heads_of_household_only' `restrict_to_employed' `use_primary_for_education' `data_source'

local years = "2011,2012"

do_analysis `education' `regencies' `inflation' `omitSelfEmployed' `years' `survey_year_FEs' `weights' `regency_vars' `specification' `heads_of_household_only' `restrict_to_employed' `use_primary_for_education' `data_source'

local years = "2011,2012,2013,2014"

// Mikey's numbers
do_analysis `education' `regencies' `inflation' `omitSelfEmployed' `years' `survey_year_FEs' `weights' `regency_vars' `specification' `heads_of_household_only' `restrict_to_employed' `use_primary_for_education' `data_source'

local weights = "True"

do_analysis `education' `regencies' `inflation' `omitSelfEmployed' `years' `survey_year_FEs' `weights' `regency_vars' `specification' `heads_of_household_only' `restrict_to_employed' `use_primary_for_education' `data_source'














// Year by year




// Roodman

local education = "Roodman" // "Roodman", "Hsiao" or "ours"
local regencies = "Roodman" // "Roodman", "Hsiao", "ours", or "ours_with_imputation_weights"
local inflation = "Roodman" // "Roodman", "Hsiao" or "ours"
local omitSelfEmployed = "False" // "False" or "True"
// local years = "2013,2014" // "2013,2014" or "2011,2012,2013,2014"
local survey_year_FEs = "False" // "False" or "True"
local weights = "False" // "False" or "True"
local regency_vars = "Roodman" // "Roodman" or "Hsiao"
local specification = "Roodman" // "Roodman" or "Hsiao"
local heads_of_household_only = "False" // "False" or "True"
local restrict_to_employed = "False" // "False" or "True"
local use_primary_for_education = "False" // "False" or "True"
local data_source = "FullFour" // "FullFour" or "HarvardLibrary"


forvalues years = 2011/2014 {
	do_analysis `education' `regencies' `inflation' `omitSelfEmployed' `years' `survey_year_FEs' `weights' `regency_vars' `specification' `heads_of_household_only' `restrict_to_employed' `use_primary_for_education' `data_source'

}

// Ours

local education = "ours" // "Roodman", "Hsiao" or "ours"
local regencies = "ours" // "Roodman", "Hsiao", "ours", or "ours_with_imputation_weights"
local inflation = "ours" // "Roodman", "Hsiao" or "ours"
local omitSelfEmployed = "True" // "False" or "True"


forvalues years = 2011/2014 {
	qui do_analysis `education' `regencies' `inflation' `omitSelfEmployed' `years' `survey_year_FEs' `weights' `regency_vars' `specification' `heads_of_household_only' `restrict_to_employed' `use_primary_for_education' `data_source'

}



log close
