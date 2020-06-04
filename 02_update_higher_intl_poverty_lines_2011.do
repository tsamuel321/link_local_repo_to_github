

**********************************************************************************************************************************************

** Purpose  : Update higher international poverty line ($3.2 & $5.5 2011 PPP) with revised 2011 PPPs and 2017 PPPs
** Input 1	: Implicit national poverty from Jolliffe & Prydz (2016), Appendix 2 of Policy Research Working Paper, No. 7606
** Input 2  : PPP data set, filename(ppp.dta)
** Input 3	: CPI data set, filename(cpi.dta)
** Date     : May 4, 2020
** Author(s): Samuel Kofi Tetteh Baah & Daniel Mahler

**********************************************************************************************************************************************


clear all
set more off

global UPI=c(username) 

if "$UPI"=="WB537472" {
global dir "C:\Users\wb537472\OneDrive - WBG\Documents\Samuel_ETC_Research\paper\analysis_ext"
}

else {
global dir "C:\Users\\${UPI}\OneDrive - WBG\Documents\Samuel_ETC_Research\paper\analysis_ext"
}

cd "$dir"


global data "${dir}/data/implicit_poverty_lines"

*Load implicit poverty lines from the working paper. 
import excel "${data}/implicit_poverty_lines_dean_espen.xlsx", sheet("cleaned") clear

*Clean, organize, prepare, and save data for analysis
rename A countryname
rename B id
rename C indicator
rename D var

gen j = . 
replace j = 1 if indicator=="Year"
replace j = 2 if indicator=="Natpline"
replace j = 3 if indicator=="hhmean"
replace j = 4 if indicator=="hfce"
replace j = 5 if indicator=="gni"

drop indicator

reshape wide var, i(id countryname) j(j)

rename var1 year
rename var2 impline
rename var3 hh_mean
rename var4 hfce
rename var5 gni_pc

save "${data}/implicit_poverty_lines_dean_espen.dta", replace


*Load implicit poverty lines from their working paper. 
use "${data}/implicit_poverty_lines_dean_espen.dta", replace


replace countryname = "Cote d'Ivoire" if countryname=="Cote d’Ivoire" 
replace countryname = "Congo, Democratic Republic of" if countryname=="Congo, Dem. Rep."
replace countryname = "Congo, Republic of" if countryname=="Congo, Rep."
replace countryname ="North Macedonia" if countryname=="Macedonia, FYR"
replace countryname = "Eswatini" if countryname=="Swaziland"
replace countryname = "Venezuela, Republica Bolivariana de" if countryname=="Venezuela, RB"


merge 1:1 countryname using `"${data}/economies.dta"', gen(m1) 

*1) Country classification by quartiles based on HFCE per capita
xtile hfce_4 = hfce , nq(4)

bysort hfce_4: sum impline

gen quartile ="Lowest 25%" if hfce_4==1
replace quartile = "25-50%" if hfce_4==2
replace quartile = "50-75%" if hfce_4==3
replace quartile = "Highest 25%" if hfce_4==4

egen quartile_mu = mean(impline),by(quartile)
tabulate quartile_mu quartile

egen quartile_med = median(impline),by(quartile)
tabulate quartile_med quartile

*Get and merge 2011 revised PPPs
gen coveragetype = "National"


merge 1:1 countrycode coveragetype using `"${dir}/data/ppp.dta"'

	foreach var of varlist ppp2011_original ppp2011_revised ppp2017{
	replace `var' = . if `var'==-1
	}

tab countryname if  _merge==1 & impline!=.    //All observations in the master merged with PPP data

rename ppp2011_original ppp2011


tab countryname  if ppp2011_revised==.&ppp2011!=.  //which countries have missing revised 2011 PPPs?
replace ppp2011_revised = ppp2011 if ppp2011_revised==.  //Assign old PPPs to countries with missing PPPs.

*Generate implicit poverty line with revised 2011 PPPs
gen impline_revised = impline*ppp2011/ppp2011_revised

*Get mean and median by quartiles
egen quartile_mu_rev = mean(impline_revised),by(quartile)
egen quartile_med_rev = median(impline_revised),by(quartile)

*Count number of countries by quartile
tabulate quartile_mu_rev quartile
tabulate quartile_med_rev quartile

*Get results
table quartile, c(mean quartile_med mean quartile_med_rev mean quartile_mu mean quartile_mu_rev ) format(%9.2f)

preserve
	egen n_quartile = count(impline),by(quartile)
	collapse quartile_med quartile_med_rev quartile_mu quartile_mu_rev n_quartile, by(quartile)
	drop if quartile==""     //Countries in this category do not have observations for HFCE. 

	lab var quartile_med "Median Original 2011 PPP"
	lab var quartile_med_rev "Median Revised 2011 PPP"
	lab var quartile_mu "Mean Original 2011 PPP"
	lab var quartile_mu_rev "Mean Revised 2011 PPP"
	lab var n_quartile "Observations"
	lab var quartile "Quartile"
	export excel using `"${dir}/results/Higher Poverty Lines.xlsx"', sheet("Quartile 2011", modify) firstrow(varl) keepcellfmt 
restore



*2) By World Bank income classification
keep countryname countrycode impline impline_revised year coveragetype quartile quartile_mu quartile_med ppp2011 ppp2011_revised ppp2017
replace year = year + 1 

merge 1:1 countrycode year coveragetype using `"${data}/historical_inc_groups.dta"'
drop _merge

*Get mean and median by income classification
egen income_mu = mean(impline),by(incgroup_historical)
egen income_mu_rev = mean(impline_revised),by(incgroup_historical)

tabulate income_mu incgroup_historical

egen income_med = median(impline),by(incgroup_historical)
egen income_med_rev = median(impline_revised),by(incgroup_historical)


*Get results
table incgroup_historical, c(mean income_med mean income_med_rev mean income_mu mean income_mu_rev ) format(%9.2f)
keep if impline_revised!=.| impline!=.


preserve
	egen n_income = count(impline),by(incgroup_historical)
	collapse income_med income_med_rev income_mu income_mu_rev n_income, by(incgroup_historical)

	lab var income_med "Median Original 2011 PPP"
	lab var income_med_rev "Median Revised 2011 PPP"
	lab var income_mu "Mean Original 2011 PPP"
	lab var income_mu_rev "Mean Revised 2011 PPP"
	lab var n_income "Observations"
	lab var incgroup_historical "Income classification"
	export excel using `"${dir}/results/Higher Poverty Lines.xlsx"', sheet("Income classification 2011", modify) firstrow(varl) keepcellfmt 
restore

drop income_mu_rev income_med_rev

keep countrycode impline impline_revised incgroup_historical

preserve
keep countrycode impline_revised

tempfile impline_revised
save `impline_revised', replace
save `"${dir}/data/impline_revised.dta"', replace
restore 
/////2017 PPPs//////////////////////////////////////////

*Add CPI data
preserve
	use `"${dir}/data/cpi.dta"', clear
	keep if year==2005 | year==2011 | year == 2017
	
	rename cpi2010 cpi
	reshape wide cpi, i(countrycode coveragetype) j(year)
	
	tempfile cpi
	save `cpi', replace
restore

merge 1:1 countrycode coveragetype using `cpi', gen(m2)
keep if m2==3

gen ppp_ = ppp2011/ppp2017
gen cpi_ = cpi2017/cpi2011

replace ppp_=1 if ppp_==.&m2==3   //This is Venezuela without 2017 PPP estimate.
replace cpi_=1 if countrycode=="VEN"    //CPI ratio is also set to 1 for Venezuela

keep if m2==3

sum 

*Generate implicit poverty line with revised 2011 PPPs
gen impline_2017 = impline*(cpi_)*(ppp_)
replace impline_revised = impline_2017

//Get mean and median by quartiles
egen quartile_mu_rev = mean(impline_revised),by(quartile)
egen quartile_med_rev = median(impline_revised),by(quartile)

*Get results
table quartile, c(mean quartile_med mean quartile_med_rev mean quartile_mu mean quartile_mu_rev ) format(%9.2f)

preserve
	egen n_quartile = count(impline_revised),by(quartile)
	collapse quartile_med quartile_med_rev quartile_mu quartile_mu_rev n_quartile, by(quartile)
	drop if quartile==""     //Countries in this category do not have observations for HFCE. 

	lab var quartile_med "Median Original 2011 PPP"
	lab var quartile_med_rev "Median 2017 PPP"
	lab var quartile_mu "Mean Original 2011 PPP"
	lab var quartile_mu_rev "Mean 2017 PPP"
	lab var n_quartile "Observations"
	lab var quartile "Quartile"
	export excel using `"${dir}/results/Higher Poverty Lines.xlsx"', sheet("Quartile 2017", modify) firstrow(varl) keepcellfmt 
restore



//Get mean and median by income classification

egen income_mu_rev = mean(impline_revised),by(incgroup_historical)
egen income_med_rev = median(impline_revised),by(incgroup_historical)


*Get results
table incgroup_historical, c(mean income_med mean income_med_rev mean income_mu mean income_mu_rev ) format(%9.2f)

preserve
	egen n_income = count(impline_revised),by(incgroup_historical)
	collapse income_med income_med_rev income_mu income_mu_rev n_income, by(incgroup_historical)
	
	lab var income_med "Median Original 2011 PPP"
	lab var income_med_rev "Median 2017 PPP"
	lab var income_mu "Mean Original 2011 PPP"
	lab var income_mu_rev "Mean 2017 PPP"
	lab var n_income "Observations"
	lab var incgroup_historical "Income classification"
	export excel using `"${dir}/results/Higher Poverty Lines.xlsx"', sheet("Income classification 2017", modify) firstrow(varl) keepcellfmt 
restore

drop impline_2017
rename impline_revised impline_2017

merge 1:1 countrycode using `impline_revised'

preserve
keep countryname year incgroup_historical impline impline_revised impline_2017 ppp2011 ppp2011_revised ppp2017 cpi2011 cpi2017 ppp_ cpi_ 
order countryname year incgroup_historical impline impline_revised impline_2017 ppp2011 ppp2011_revised ppp2017 cpi2011 cpi2017 ppp_ cpi_ 


	lab var countryname 		"Country"
	lab var year 				"Year"
	lab var incgroup_historical "Income classification"
	lab var impline 			"Implicit line (Original 2011 PPP)"
	lab var impline_revised 	"Implicit line (Revised 2011 PPP)"
	lab var impline_2017 		"Implicit line (2017 PPP)"
	lab var ppp2011 			"Original 2011 PPP"
	lab var ppp2011_revised 	"Revised 2011 PPP"
	lab var ppp2017 			"2017 PPP"
	lab var cpi2011 			"CPI 2011"
	lab var cpi2017 			"CPI 2017"
	lab var ppp_ 				"PPP ratio (PPP2011/PPP2017)"
	lab var cpi_ 				"CPI ratio (CPI2017/CPI2011)"

	export excel using `"${dir}/results/Higher Poverty Lines.xlsx"', sheet("Data 2011", modify) firstrow(varl) keepcellfmt 
restore

























