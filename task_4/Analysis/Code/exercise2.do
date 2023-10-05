capture log close
cd /Users/gizemkilicgedik/Desktop/AppliedEmpirical/task_5
pwd
log using exercise2.log, replace 

//exercise2.do

//Gizem Kilicgedik October 3, 2023

//This is the do file for Exercise 2(Out of sample prediction) in Task 4. In this exercise, we are using 1992-2002 growth dataset. The goal is to use our estimated predictors from the 1992-2002 dataset to predict growth in 2002-2011.

	version 17
	clear all
	macro drop _all
	set linesize 70  
	set more off
	set mem 500m
	set seed 19940103

*setting global directory path here

	global path "/Users/gizemkilicgedik/Desktop/AppliedEmpirical/task_4"
	cd "$path" 

*setting input and output path

	global inputpath "Analysis/Data"
	global outputpath "Analysis/Output"
	
*importing the dataset 	

	use "$inputpath/growthdata92_02.dta", clear
	
/*** COMPARING DIFFERENT METHODS MSE on TESTING DATA ***/

	generate wave = 1
	append using "$inputpath/growthdata02_11.dta"
	replace wave = 2 if wave == .
	order iso3 growth

* Sample Selection Regression

	regress growth inflation regulation ln_y tfr fem_emp urban presidential law if wave == 2
	regress growth inflation regulation ln_y tfr fem_emp urban presidential law if wave == 1
	predict growth_hat_selectsample, xb
	egen mse_selectsample = total((growth_hat_selectsample - growth)^2), by(wave)

* Ridge Regression

	regress growth ext_bal inflation tot_emp competitiveness_exec presidential stability effectiveness regulation law if wave == 2
	regress growth ext_bal inflation tot_emp competitiveness_exec presidential stability effectiveness regulation law if wave == 1
	predict growth_hat_ridge, xb
	egen mse_ridge= total((growth_hat_ridge - growth)^2), by(wave)

* Lasso Regression

	regress growth ext_bal inflation tot_emp competitiveness_exec presidential stability effectiveness regulation law if wave == 2
	regress growth ext_bal inflation tot_emp competitiveness_exec presidential stability effectiveness regulation law if wave == 1
	predict growth_hat_lasso, xb
	egen mse_lasso= total((growth_hat_lasso - growth)^2), by(wave)

* Naive Prediction

	summarize growth_hat_lasso if wave == 1
	generate growth_hat_naive = r(mean)
	egen mse_naive = total((growth_hat_naive -  growth)^2), by(wave)

* Kitchen Sink

	regress growth ln_y-corruption if wave == 1
	predict growth_hat_sink, xb
	egen mse_sink = total((growth_hat_sink -  growth)^2), by(wave)
	bysort wave: generate count = _n
	keep if count == 1
	drop count
	keep wave mse*


save "$outputpath/exercise2.dta", replace

log close

exit
