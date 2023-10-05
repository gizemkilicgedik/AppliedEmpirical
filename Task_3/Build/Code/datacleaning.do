capture log close
cd /Users/gizemkilicgedik/Desktop/AppliedEmpirical/task_3
pwd
log using datacleaning.log, replace 

//datacleaning.do
//Gizem Kilicgedik Septermber 20, 2023
//This is the do file for cleaning the World Values Survey Data, Wave 6

	version 17
	clear all
	macro drop _all
	set linesize 70 
	global path "/Users/gizemkilicgedik/Desktop/AppliedEmpirical/task_3"
	cd "$path" //setting global directory path here
	global inputpath "Raw/Data"
	global outputpath "Analysis/Data"
	ssc install missings, replace
	
//I am starting with uploading the data
	use "$inputpath/WV6_Data_stata_v20201117.dta", clear
	
//Choosing the ordered variables
	keep C_COW_ALPHA V2 V4-V11 V49-V56 V59 V70-V79 V90-V139 V152-V169 V170-V175 ///
		 V181-V186 V188-V191 V192-V197 V198-V210
	rename C_COW_ALPHA COW
	
//Checking the variable values
	codebook

//Recoding negative values into missing values
	qui ds, has(type numeric)
	cap confirm variable `r(varlist)'
	if _rc == 0 foreach v of varlist `r(varlist)' {
		replace `v' = . if `v' < 0
	}	
	
//Collapsing 
	foreach v of var `r(varlist)' {
		local l`v' : variable label `v'
        if `"`l`v''"' == "" {
 		local l`v' "`v'"
		}
	}
	
	collapse (first) COW (mean) V4-V11 V49-V56 V59 V70-V79 V90-V139 V152-V169 ///
					V170-V175 V181-V186 V188-V191 V192-V197 V198-V210, by(V2)
	
	qui ds, has(type numeric)
	foreach v of var `r(varlist)' {
		la var `v' `"`l`v''"'
	}
	
//Dropping the variables that have missing values(all countries must have data for the variables included)
	qui missings report
	drop `r(varlist)'
	drop V125_* // not all countries have this

	
//Generating string country variables for transposing the data
	decode V2, gen(country)
	order country, first
	replace country = subinstr(country, " ", "", .)
	replace country = "TrinidadTobago" if country == "TrinidadandTobago"
	rename V2 countryID
	
//Saving the data
	save "$outputpath/WV6_Data_NON_NOR.dta", replace 
	
//Generating normalized variables
	ds, has(type float)
	foreach v of varlist `r(varlist)' {
		tempvar meanvar
		tempvar sdvar
		egen `meanvar' = mean(`v')
		egen `sdvar' = sd(`v')
		replace `v' = (`v'-`meanvar')/`sdvar'
		la var `v' `"`l`v'' (Normalized)"'
	}
	cap drop __*
	
//Saving the data with the normalized variables
	save "$outputpath/WV6_Data_NOR.dta", replace 
	
log close 
exit

