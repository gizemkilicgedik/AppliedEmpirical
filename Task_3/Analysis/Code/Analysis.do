capture log close
cd /Users/gizemkilicgedik/Desktop/AppliedEmpirical/task_3
pwd
log using analysis.log, replace 

//analysis.do

//Gizem Kilicgedik Septermber 20, 2023

//This is to try out unsupervised learning using WVS6(cleaned). First goal is to use cluster analysis to try out which questions naturally belong together and which countries naturally belong together. The second one is to use principal component analysis to find how answers to different questions covaries.

	version 17
	clear all
	macro drop _all
	set linesize 70 
	
//setting global directory path here
	global path "/Users/gizemkilicgedik/Desktop/AppliedEmpirical/task_3"
	cd "$path" 

//setting input and output path
	global inputpath "Analysis/Data"
	global outputpath "Analysis/Results"
	global NON_NOR "Non-normalized"
	global NOR "Normalized"
	
//installing the packages needed
	ssc install sxpose2, replace
	ssc install sepscatter, replace 
	ssc install texsave,replace
	
//CLUSTER ANALYSIS

foreach J in NON_NOR NOR { // Doing both non-normalized and normalized datasets

	use "$inputpath/WV6_Data_`J'.dta", clear


///Cluster analysis for questions
	preserve
	drop countryID COW

//Transposing the dataset
	sxpose2, clear firstnames destring varname varlabel force

	rename _varname questions
	rename _varlabel details
	
//Cluster analysis 
	forval i = 2/10 {
		set seed 19940103
		qui ds, has(type double)
		cluster kmeans `r(varlist)', k(`i') gen(group`i') name(Cluster`i')
	}

//Generating mean of each questions and groups
	ds, has(type double)
	egen questionmean = rowmean(`r(varlist)')

//Setting random number (for graphical analysis purpose)
	gen group1 = 1
	forval i = 1/10 {
		sort group`i' questions
		gen number`i' = _n
	}

//Graphical analysis
	forval i = 1/10 {
		sepscatter number`i' questionmean, separate(group`i') xlabel(none) ///
				ylabel(none) graphregion(color(white)) ytitle("") xtitle("") ///
				legend(subtitle("Cluster") ring(0) row(2) pos(5) region(color(none))) ///
				title("Cluster Analysis of Questions ($`J'): K = `i'")
		graph export "$outputpath/Graphs/$`J'/CA_QuestionK`i'_`J'.png", replace
	}
	
//Table of groups and questions
	sort group5 questions
	gen groupname = "Politics" if group5 == 1
	replace groupname = "Life security" if group5 == 2
	replace groupname = "Life importance" if group5 == 3
	replace groupname = "Democracy and freedom" if group5 == 4
	replace groupname = "Traditional values" if group5 == 5

	order groupname, after(group5)
	la var group5 "Group ID"
	la var groupname "Group"
	la var questions "Question Code"
	la var details "Question"

	texsave group5 groupname questions details using "$outputpath/Tables/$`J'/CA_QuestionsK5_`J'.tex", varlabels replace

	restore

///Cluster analysis of countries
//Cluster Analysis
	forval i = 2/10 {
	set seed 19940103
	qui ds, has(type float)
	cluster kmeans `r(varlist)', k(`i') gen(group`i') name(Country`i')
	}

//Generating mean of each questions and groups
	ds, has(type float)
	egen countrymean = rowmean(`r(varlist)')

//Setting random number (for graphical analysis purpose)
	gen group1 = 1
	forval i = 1/10 {
		sort group`i' countryID
		gen number`i' = _n
	}

//Graphical analysis
	forval i = 1/10 {
		sepscatter number`i' countrymean, separate(group`i')  ///
				ylabel(none) graphregion(color(white)) ytitle("") xtitle("Country Mean") ///
				title("Cluster Analysis of Country ($`J'): K = `i'") mylabel(country)
		graph export "$outputpath/Graphs/$`J'/CA_CountryK`i'_`J'.png", replace
	}

}

//PRINCIPAL COMPONENET ANALYSIS

foreach J in NON_NOR NOR { // Doing both non-normalized and normalized dataset

	use "$inputpath/WV6_Data_`J'.dta", clear
	
//Principal component analysis with two components
	pca V*, com(2)
	
//Obtaining factor loading 
	preserve 
	
	matrix define A=e(L)
	svmat2 A, rnames(Q)
	findit svmat2
	gen aA1=abs(A1)
	gen aA2=abs(A2)
	gsort -aA1
	keep Q aA1 aA2
	
	tempfile factorloading
	save `factorloading', replace
	
	restore 
	
//Merging the data with the factor loading
	reshape long V, i(countryID) j(Questions)
	tostring Questions, gen(Q)
	replace Q = "V"+Q
	
	merge m:1 Q using `factorloading', nogen
	
//Generating score for each component
	gen Z1 = V*aA1
	gen Z2 = V*aA2
	
	la var Z1 "First principal component"
	la var Z2 "Second principal component"
	
//Obtaining country average 
	sort countryID Questions
	collapse (mean) Z1 Z2, by(country COW)
	
//Clustering country 
	set seed 19940103
	cluster kmeans Z1 Z2, k(5) gen(group) name(PCA)
	
	la var Z1 "First principal component"
	la var Z2 "Second principal component"
	
//Culture map
	sepscatter Z1 Z2, separate(group) mylabel(COW) ///
	graphregion(color(white)) ytitle("First principal component score") ///
	xtitle("Second principal component score") ///
	title("PCA Culture Map ($`J')") 
	
	graph export "$outputpath/Graphs/$`J'/PCA_CultureMap_`J'.png", replace

}	

log close
exit
	