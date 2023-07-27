cap log close
log using Logs/ReplicatingHsiao.log, replace



local regencies = "Hsiao"
local survey_year_FEs = "True"
local omitSelfEmployed = "True"
local years = "2011,2012,2013,2014"
local inflation = "Hsiao"
local regency_vars = "Hsiao"
local specification = "Hsiao"
local heads_of_household_only = "True"
local restrict_to_employed = "True"
local data_source = "Hsiao" // "Hsiao", "Harvard", or "Ours"
local restrict_to_employed = "True" // "False" or "True"


if "`data_source'" == "Hsiao" {

	if "`regencies'" == "Hsiao" {
		use "RawData/susenas_HsiaoSent.dta", clear
		merge m:1 kab_birth71 using "Concordances/birth_districts.dta", nogen
		gen birthpl_imputation_wt = 1
		rename income_month B5R29
		rename years_school yeduc
		rename age_1974 age74
		rename hoh relate
		gen birthyr = 1974 - age74
		gen int dum = cond(birthyr<1962, 1900+100, birthyr)
		gen young = 1 if inrange(age74, 2, 6)
		replace young = 0 if inrange(age74, 12, 17)
		gen birthplnew = birthpl
	}

}

if "`data_source'" == "Harvard" {
	use "RawData/susenas_HarvardLibrary.dta", clear
	keep if JK == 1
	rename survey_year year

	gen birthpl_SUSENAS = 100 * B5_TL1 + B5_TL2

	merge m:1 birthpl_SUSENAS using "Concordances/concordance_hsiao.dta", nogen
	gen birthpl_imputation_wt = 1
	drop birthpl
	rename birthpl_hsiao birthpl


	gen age74 = UMUR + 1974 - year
	gen birthyr = 1974 - age74
	gen int dum = cond(birthyr<1962, 1900+100, birthyr)
	gen young = 1 if inrange(age74, 2, 6)
	replace young = 0 if inrange(age74, 12, 17)
	gen birthplnew = birthpl
	rename HB relate


// 	rename B5R17 educ_attain
// 	gen years_school = 0 if educ_attain == 1
// 	replace years_school = 6 if educ_attain == 2
// 	replace years_school = 6 if educ_attain == 3
// 	replace years_school = 6 if educ_attain == 4
// 	replace years_school = 9 if educ_attain == 5
// 	replace years_school = 9 if educ_attain == 6
// 	replace years_school = 9 if educ_attain == 7
// 	replace years_school = 12 if educ_attain == 8
// 	replace years_school = 12 if educ_attain == 9
// 	replace years_school = 12 if educ_attain == 10
// 	replace years_school = 12 if educ_attain == 11
// 	replace years_school = 14 if educ_attain == 12
// 	replace years_school = 15 if educ_attain == 13
// 	replace years_school = 16 if educ_attain == 14
// 	replace years_school = 18 if educ_attain == 15
//	
// 	rename years_school yeduc

	* If we'd rather do things Hsiao's way, comment out the above section and uncomment this.
	rename B5R17 highest_diploma
	generate years_schooling = highest_diploma
	recode years_schooling (1 = 0) (2 3 4 = 6) (5 6 7 = 9) (8 9 10 11 = 12) (12 = 14) (13 = 15) (14 = 16) (15 = 18)

	rename years_schooling yeduc

	gen employed = B5R24B
	recode employed (1=1) (2 3 4=0)
	gen self_employed = B5R31
	recode self_employed (1 2 3=1) (4 5 6=0)

	replace self_employed = 0 if employed == 0
	replace self_employed = . if employed == .
// 	replace employed = . if self_employed == . & year == 2012 // only 1
// 	assert self_employed == 0 if employed == 0
// 	assert self_employed != . if employed == 1
// 	assert self_employed == . if employed == .


	replace B5R29 = . if employed != 1


}

if "`data_source'" == "ours" {
	use "CleanData/CompareToRoodmanPreppedData_FullFour.dta", clear
	gen yeduc = years_schooling_Hsiao
	keep if year < 2014
	keep if birthpl_imputation_wt > 0.5

	merge m:1 birthpl_SUSENAS using "Concordances/concordance_hsiao.dta", nogen
	cap drop birthpl_imputation_wt
	gen birthpl_imputation_wt = 1
	drop birthpl
	rename birthpl_hsiao birthpl
	
	gen birthplnew = birthpl
}

keep if year < 2014 // This way we can compare with our data which has 4 quarters of 2014 instead of 2.

	
if "`regency_vars'" == "Hsiao" {
	merge m:1 birthpl using "RawData/hsiao_inpres_with_numeric_birthpl.dta"
	gen ninnew = nin
	gen ch71new = ch71
	gen en71new = en71
}


gen lwage = ln(B5R29)







if "`survey_year_FEs'" == "True" {
	local survey_year_FE_expression = "i.year"
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


if "`specification'" == "Hsiao" {
	local additional_controls = "1.young#c.ch71new 1.young#c.en71new 1.young#c.wsppc"
	local additional_controls_manyIV = "_IbirXch7* _IbirXen7* _IbirXwsp*"
}
else if "`specification'" == "ours_and_Roodman" {
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


xi i.young|ninnew /*i.dum|ninnew*/ i.birthyr // *ch71new i.birthyr*en71new i.birthyr*wsppc i.year i.young|ch71new i.young|en71new  i.young|wsppc

	
// Years of education (all)
di "reghdfe yeduc _IyouXninne_1 _Ibirthyr_* `additional_controls' `survey_year_FE_expression' if !missing(yeduc) `hoh_restriction' `birthpl_imputation_wt_restrict', cluster(birthplnew) absorb(birthplnew)"
reghdfe yeduc _IyouXninne_1 _Ibirthyr_* `additional_controls' `survey_year_FE_expression' if !missing(yeduc) `hoh_restriction' `birthpl_imputation_wt_restrict', cluster(birthplnew) absorb(birthplnew)

// First stage (young)
reghdfe yeduc _IyouXninne_1 _Ibirthyr_* `additional_controls' `survey_year_FE_expression' if !missing(lwage) & !missing(yeduc) & inlist(year,`years') `hoh_restriction' `birthpl_imputation_wt_restrict' `self_employed_restriction' `employed_restriction', cluster(birthplnew) absorb(birthplnew)

// Reduced form (young)
reghdfe lwage _IyouXninne_1 _Ibirthyr_* `additional_controls' `survey_year_FE_expression' if !missing(lwage) & !missing(yeduc) & inlist(year,`years') `hoh_restriction' `birthpl_imputation_wt_restrict' `self_employed_restriction' `employed_restriction', cluster(birthplnew) absorb(birthplnew)



log close