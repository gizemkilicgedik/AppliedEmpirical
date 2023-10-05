***********************************
**** Task 2 
**** Programs for value review and regression output
**** Gizem Kilicgedik
**** Date: 12 September 2023
***********************************

*** Program for value review

* Syntax: valuereview using [filename], numericfile([filename])
* Output: summary statistics of byte and float variables, and tabulation 
*		  of string and interger variable (please see this in log file instead)

cap program drop valuereview
program valuereview
	
	syntax using/, numericfile(string) 
	use "`using/'", clear
	
	cap drop YR* QTR* // specifically for AK91
	
	eststo clear
	ds, has(type numeric)
	cap confirm variable `r(varlist)'
	if _rc == 0 eststo: qui estpost sum `r(varlist)', det
	
	esttab using "`numericfile'", replace ///
		cell("mean(fmt(2)) min max p50(fmt(2)) sd(fmt(2))") ///
		collabel("Mean" "Min" "Max" "Median" "SD") ///
		label noobs
	eststo clear 
	
	ds, has(type int)
	cap confirm variable `r(varlist)'
	if _rc == 0 foreach var of varlist `r(varlist)' {
		tab `var'
	}
	ds, has(type string)
	cap confirm variable `r(varlist)'
	if _rc == 0 foreach var of varlist `r(varlist)' {
		tab `var'
	}
	
end


*** program for regression analyses and table output

* Syntax: olsregression [varlist] [if], storename([anyname])
* Output: regression with heteroskedasticity robust standard error, stored
*		  in unique name for table output

cap program drop olsregression
program  olsregression
	syntax anything [if], storename(name)
	eststo `storename': reg `anything', robust
end

* Syntax: latexoutputtable [varlist] using [filename], storename([anyname])
* Output: latex table specialized in keeping only relevant variable and 
*		  can be ordered accordingly using the storage name from olsregression
*		  program

cap program drop latexoutputtable
program  latexoutputtable
	syntax varlist using/, storename(string)
	esttab `storename' using "`using/'", ///
	keep(`varlist') order(`varlist') ///
	label  collabels(none) mlabels(, none) starlevels(* 0.10 ** 0.05 *** 0.01)  ///
	cells(b(fmt(3)) se(fmt(3) par)) style(tex) stats(N r2, labels("Number of Observations" "R-squared") fmt(%9.0fc 3)) ///
	replace
	eststo clear
end

