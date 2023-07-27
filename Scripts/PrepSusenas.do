*** This creates the years of schooling, birth year, and self employment variables we use from the raw Susenas data
*** B5_TL1 is province of birth and B5_TL2 is district within province, this also puts everything in terms of regencies, which are the two of them concatenated.


cap log close
log using Logs/PrepSusenas.log, replace

foreach data_source in FullFour HarvardLibrary {

	use "RawData/susenas_`data_source'.dta", clear

	keep if JK == 1 // men
	gen regy2010 = B5_TL1 * 100 + B5_TL2 // Each two digits
	joinby regy2010 using "Concordances/SUPAS 1995-2010 regency concordance.dta", unmatched(master)
	rename regy2010 birthpl_SUSENAS



	rename survey_year year
	gen birthyr = year - UMUR
	rename weight wt
	rename HB relate
	rename regy1995shareinregy2010 birthpl_imputation_wt
	rename B5_TL1 birthprov
	rename id1995a_bplreg birthpl
	drop JK UMUR B5_TL2 _merge


	rename B5R15 school_attempted
	rename B5R16 attempted_years 
	rename B5R17 highest_diploma
	rename B5R24B employed
	rename B5R31 self_employed


	* This is how we think Roodman meant to calculate years of schooling.
	generate years_schooling_base = school_attempted
	recode years_schooling_base (1 2 3 = 0) (4 5 6 = 6) (7 8 9 10 = 9) (11 12 13 = 12) (14 = 16)
	generate years_schooling_add = attempted_years - 1 if attempted_years >= 1
	replace years_schooling_add = 0 if attempted_years == 0
	recode years_schooling_add (7 = 6) if inrange(school_attempted, 1, 3)
	recode years_schooling_add (7 = 3) if inrange(school_attempted, 4, 10) | school_attempted == 12 | school_attempted == 13
	recode years_schooling_add (7 = 1) if school_attempted == 11
	recode years_schooling_add (5 6 = 0) if school_attempted == 14
	recode years_schooling_add (7 = 2) if school_attempted == 14
	generate years_schooling_correct = years_schooling_base + years_schooling_add

	drop years_schooling_base years_schooling_add

	* This is how Roodman calculates it in his original code
	gen school_attempted_Roodman = school_attempted
	replace school_attempted_Roodman = 0 if missing(school_attempted) // He doesn't do this explicitly, but somehow in what he stores in SQL all the missings are 0
	recode school_attempted_Roodman (1 2 3 = 0) (4 5 6 = 6) (7 8 9 10 = 9) (11 12 13 14 = 12), gen(years_schooling)  // years of schooling *before* each schooling level
	mat completionyears = 6, 6, 6, 3, 3, 3, 3, 3, 3, 3, 3, 2, 3, 5  // max years in schooling levels; used when p518=8, meaning "completed"
	replace years_schooling = years_schooling + cond(school_attempted_Roodman<8, school_attempted_Roodman, completionyears[1, school_attempted_Roodman]) if school_attempted_Roodman>0

	rename years_schooling years_schooling_Roodman

	* This is how Hsiao measures years of schooling
	generate years_schooling = highest_diploma
	recode years_schooling (1 = 0) (2 3 4 = 6) (5 6 7 = 9) (8 9 10 11 = 12) (12 = 14) (13 = 15) (14 = 16) (15 = 18)

	rename years_schooling years_schooling_Hsiao

	recode employed (1=1) (2 3 4=0)
	recode self_employed (1 2 3=1) (4 5 6=0)
	replace self_employed = 0 if employed == 0
	replace self_employed = . if employed == . // following Hsiao



	gen int dum = cond(birthyr<1962, 1900+100, birthyr) // Esther pools the birth years of those too old to be in the IV specification
	gen byte age74 = 1974 - birthyr
	gen byte old = age74 <= 17 & age74 >= 12
	gen byte young = !old if (age74>=2 & age74 <= 6) | old  // young dummy missing outside of ages 2-6, 12-17, so will restrict samples
	gen byte reallyold = age74 <= 24 & age74 >= 18

	keep if 24>=age74 & age74>=2

	save "CleanData/CompareToRoodmanPreppedData_`data_source'.dta"

}

log close