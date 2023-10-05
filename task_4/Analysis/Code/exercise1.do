capture log close
cd /Users/gizemkilicgedik/Desktop/AppliedEmpirical/task_5
pwd
log using exercise1.log, replace 

//exercise1.do

//Gizem Kilicgedik 	October 3, 2023

//This is the do file for Exercise 1(Within-time period prediction) in Task 5. In this exercise, we are using 1992-2002 growth dataset. The goal is to implement the prediction methods that we have learned: subset selection, lasso, ridge regression, and random forests.

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
	
	use "$inputpath/growthdata_92_02.dta", clear

/*** DATA PREPARATION ***/

*Dividing the data into training and testing components

	generate rand = uniform()
	sort rand

	generate randomized_rank = 100 * _n/_N

	generate data_type = 0

	replace data_type = 1 if randomized_rank <= 20
	replace data_type = 2 if randomized_rank > 20

	label define typ 1 "Testing data" 2 "Training data"
	label values data_type typ

	drop rand randomized_rank

*Dividing the training data into 10 equally sized clusters for cross validation

	bysort data_type: generate cluster = 10* _n/_N
	replace cluster = ceil(cluster)
	replace cluster = . if data_type == 1


	order iso3 growth
	
/*** SUBSET SELECTION ***/

	preserve


*Initializing an empty model

	local selected_vars ""															

*Looping through model sizes

forval mod_size = 1/27 {
	
	local j = "`mod_size'"
	local min_mse_`j' 100000													
	local best_model_`j' "`selected_vars'" 
	local index = 0
	
*Looping through variables
	
	foreach var of varlist ln_y-corruption {
	
		local index = `index' + 1
		local k = "`index'"
		
		generate p_grth_`j'_`k' = .
		
		if strpos("`selected_vars'", "`var'") > 0 continue
		
		forval clus = 1/10 {
			
			regress growth `selected_vars' `var' if cluster != `clus' & cluster != .
		
			predict p_grth, xb
			
			replace  p_grth_`j'_`k' =  p_grth if cluster == `clus'
			
			drop p_grth
		
		}
		
		egen  mse_`j'_`k' = total((growth -  p_grth_`j'_`k')^2)
		
		generate model_`j'_`k' = "`selected_vars'" + " " + "`var'" 
		 
		local mse_`j'_`k' mse_`j'_`k'[1]
		
		if `mse_`j'_`k'' <= `min_mse_`j'' { 
		local min_mse_`j' `mse_`j'_`k''
		local best_model_`j' = model_`j'_`k'[1]
		}
		else {
		local min_mse_`j' `min_mse_`j''											
		local best_model_`j' `best_model_`j''									
		}
		
		di "`best_model_`j''"													
		
	
	}
	
	local selected_vars "`best_model_`j''"

	di "`selected_vars'"

	}
		

*Creating a dataset which has the models with the lowest MSE for each 'size'.

	generate model_size = _n
	generate model = ""
	generate mse = .
	
	
	forval i = 1/27 {
		
	replace mse = `min_mse_`i'' if model_size == `i'
	replace model = "`best_model_`i''" if model_size == `i'
		
	}
	
	
	keep model_size model mse
	drop if model_size >27
	sort mse																	// Sort by MSE -- The top row will be the model with the lowest in sample MSE
	
	
// The effcient linear prediction model is regress growth inflation regulation ln_y tfr fem_emp urban presidential law
	
	restore

/*** RIDGE REGRESSION ***/

	elasticnet linear growth ln_y-corruption, cluster(cluster)
	etable

// The efficient linear prediction model is: regress growth ext_bal inflation tot_emp competitiveness_exec presidential stability effectiveness regulation law


/*** LASSO REGRESSION ***/

	lasso linear growth ln_y-corruption, cluster(cluster)
	etable
	
// The efficient linear prediction model is: regress growth ext_bal inflation tot_emp competitiveness_exec presidential stability effectiveness regulation law

**Testing the root mean square error of the different prediction methods

/*** RANDOM FORESTS ***/


gsort -data_type

rforest growth ln_y-corruption in 23/112, type(reg) iter(1000) numvars(8)

matrix list e(importance)

predict growth_hat_rforest in 1/22

egen mse_rforest  =  total((growth_hat_rforest - growth)^2)


keep if data_type == 1

*Sample Selection Regression

regress growth inflation regulation ln_y tfr fem_emp urban presidential law
predict growth_hat_selectsample, xb
egen mse_selectsample = total((growth_hat_selectsample - growth)^2)

*Ridge Regression

regress growth ext_bal inflation tot_emp competitiveness_exec presidential stability effectiveness regulation law
predict growth_hat_ridge, xb
egen mse_ridge= total((growth_hat_ridge - growth)^2)

*Lasso Regression

regress growth ext_bal inflation tot_emp competitiveness_exec presidential stability effectiveness regulation law
predict growth_hat_lasso, xb
egen mse_lasso= total((growth_hat_lasso - growth)^2)

*Naive Prediction

summarize growth_hat_lasso	
generate growth_hat_naive = r(mean)
egen mse_naive = total((growth_hat_naive -  growth)^2)

*Kitchen Sink

regress growth ln_y-corruption
predict growth_hat_sink, xb
egen mse_sink = total((growth_hat_sink -  growth)^2)
keep mse*
keep if _n == 1
xpose, clear varname
rename v1 mse
order _ mse
sort mse

save "$outputpath/exercise1.dta", replace

log close

exit

























