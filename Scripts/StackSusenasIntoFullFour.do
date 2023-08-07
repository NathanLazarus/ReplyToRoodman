cap log close
log using Logs/StackSusenasIntoFullFour.log, replace

import dbase "RawData/Susenas_HarvardLibrary/kor11ind.dbf", clear
save "RawData/Susenas_data_as_dta/kor11ind.dta", replace
import dbase "RawData/Susenas_HarvardLibrary/kor12ind.dbf", clear
save "RawData/Susenas_data_as_dta/kor12ind.dta", replace
import dbase "RawData/Susenas_HarvardLibrary/kor2013ind_backcast.dbf", clear
save "RawData/Susenas_data_as_dta/kor13ind.dta", replace
tempfile additional_variables_2014
import dbase "RawData/Susenas_WePurchased/2014_kor_ind variabel terpilih.dbf", clear
gen obs_num = _n
save `additional_variables_2014', replace
import dbase "RawData/Susenas_WePurchased/2014_kor_ind_24492.dbf", clear
gen obs_num = _n
merge 1:1 obs_num using `additional_variables_2014', nogen
drop obs_num
save "RawData/Susenas_data_as_dta/kor14ind.dta", replace
import dbase "RawData/Susenas_HarvardLibrary/2014kor14ind_tw1.dbf", clear
save "RawData/Susenas_data_as_dta/kor14ind_q1.dta", replace
import dbase "RawData/Susenas_HarvardLibrary/kor14ind_tw3.dbf", clear
save "RawData/Susenas_data_as_dta/kor14ind_q3.dta", replace

use "RawData/Susenas_data_as_dta/kor11ind.dta", clear
gen survey_year = 2011
gen double weight = FWT
append using "RawData/Susenas_data_as_dta/kor12ind.dta"
replace survey_year = 2012 if missing(survey_year)
replace weight = WEIND if survey_year == 2012
append using "RawData/Susenas_data_as_dta/kor13ind.dta"
replace survey_year = 2013 if missing(survey_year)
replace weight = FWT_TAHUN if survey_year == 2013
append using "RawData/Susenas_data_as_dta/kor14ind.dta"
replace survey_year = 2014 if missing(survey_year)
replace weight = FWT_TAHUN if survey_year == 2014

keep JK UMUR HB B5_TL1 B5_TL2 B5R15 B5R16 B5R17 B5R24B B5R28B B5R29 B5R31 weight survey_year

save "RawData/susenas_FullFour.dta", replace

use "RawData/Susenas_data_as_dta/kor11ind.dta", clear
gen survey_year = 2011
gen double weight = FWT
append using "RawData/Susenas_data_as_dta/kor12ind.dta"
replace survey_year = 2012 if missing(survey_year)
replace weight = WEIND if survey_year == 2012
append using "RawData/Susenas_data_as_dta/kor13ind.dta"
replace survey_year = 2013 if missing(survey_year)
replace weight = FWT_TAHUN if survey_year == 2013
append using "RawData/Susenas_data_as_dta/kor14ind_q1.dta"
replace weight = FWT if missing(survey_year)
replace survey_year = 2014 if missing(survey_year)
append using "RawData/Susenas_data_as_dta/kor14ind_q3.dta"
replace weight = FWT_TRIWUL if missing(survey_year) 
replace survey_year = 2014 if missing(survey_year)

keep JK UMUR HB B1R1 B1R2 B5_TL1 B5_TL2 B5R15 B5R16 B5R17 B5R24B B5R28B B5R29 B5R31 weight survey_year

save "RawData/susenas_HarvardLibrary.dta", replace

log close
