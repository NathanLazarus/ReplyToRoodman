cap log close
log using Logs/BuildConcordances.log, replace

import delim "Concordances/concordance_hsiao.csv", clear
rename birthpl_susenas birthpl_SUSENAS
save "Concordances/concordance_hsiao.dta", replace

import delim "RawData/hsiao_inpres.csv", clear
rename prop71 prop_birth71
rename kab71 kab_birth71
merge m:1 kab_birth71 using "Concordances/birth_districts.dta"
drop _merge
save "RawData/hsiao_inpres_with_numeric_birthpl.dta", replace


import delim "Concordances/SUPAS 1995-2010 regency concordance.csv", clear
save "Concordances/SUPAS 1995-2010 regency concordance.dta", replace

log close