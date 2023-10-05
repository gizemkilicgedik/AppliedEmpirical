capture log close
cd /Users/gizemkilicgedik/Desktop/AppliedEmpirical/task_5
log using cross_fit_po.log, replace 

//cross_fit_po.do

//Gizem Kilicgedik 	October 3, 2023

//This is the do file for cross-fit partial out exercise (exercise 1) in Task 5. In this exercise, the goal is to employ the cross-fit partial approach to estimate the impact of an unemployment insurance program on the duration of time individuals spend without a job.

	version 17
	clear all
	macro drop _all
	set linesize 70  
	set more off
	set mem 500m
	set seed 19940103

*setting global directory path here

	global path "/Users/gizemkilicgedik/Desktop/AppliedEmpirical/task_5"
	cd "$path" 

*setting input and output path

	global inputpath "Raw"
	global outputpath "Analysis/Output"
	
*importing the dataset 
	
	use "$inputpath/penn_jae.dta", clear
	drop muld-v26

/*** Exercise 1a: cross-fit partialing out with plug-in parameters ***/

* Generating interaction and square variables

local v = ""
generate vars = ""

local varlist female black hispanic othrace dep q1 q2 q3 q4 v14 q5 q6 recall ///
agelt35 agegt54 durable nondurable lusd husd

foreach var1 of local varlist {     
	generate `var1'_squared = `var1'^2     											
	replace vars = "`v'" + " " + "`var1'"
	local v = vars[1]
	di `v'
	foreach var2 of local varlist {    
		if strpos("`v'", "`var2'") == 0 {
		gen `var1'_x_`var2' = `var1' * `var2'	
		}
		else {
        display "This is a repeated variable"
		}	
	}
}

drop vars

* Creating the treatment dummy 

gen d = 0
replace d = 1 if tg == 4 | tg == 6
drop if tg == 1 | tg == 2 | tg == 3 | tg == 5

label var d "Treated"

* Generating the outcome variables

gen y = log(inuidur1)

order y female- husd_squared

* Carrying out the cross fit partial out method using the plug-in parameter

eststo clear

eststo: xporegress y d, controls(female-husd_squared) xfolds(5) resample(15) selection(plugin)
estadd local para "Plug in"	
estadd local vars "No"


/*** Exercise 1b: Always including raw covariates ***/

eststo: xporegress y d, controls((female-husd) female-husd_squared) xfolds(5) resample(15) selection(plugin)
estadd local para "Plug in"	
estadd local vars "Yes"

/*** Exercise 1c: Cross-fit partialing out with cross-validation ***/

eststo: xporegress y d, controls(female-husd_squared) xfolds(5) resample(15) selection(cv)
estadd local para "CV"	
estadd local vars "No"

/*** Output Table ***/

file open myfile using "$outputpath/cross_fit_po.tex", write replace
file write myfile "\def\sym#1{\ifmmode^{#1}\else\(^{#1}\)\fi}"
file write myfile "\hline"
file write myfile "\hline"
file write myfile "\begin{tabular}{l c c c}"
file write myfile " & (1) & (2) & (3) \\  "
file write myfile "\hline"
file write myfile "\hline"
file close myfile
	
esttab using "$outputpath/cross_fit_po.tex" , append  b(4) se(4)  label noconstant booktabs ///
star(* 0.10 ** 0.05 *** 0.01) ///
fragment keep(d) ///
nonumbers nodepvars nomtitles nonotes noobs ///
order(d) ///
scalars("para Plug in or CV" "vars Force raw vars") ///
sfmt(2)

cap file close _all
file open myfile using "$outputpath/cross_fit_po.tex", write append
file write myfile "\hline"
file write myfile "\hline"
file write myfile " \end{tabular} "
file close myfile

log close

exit
