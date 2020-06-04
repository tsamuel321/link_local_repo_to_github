
	
*********************************************************************************************************************************************************************************

** Purpose  : Generate new implicit poverty lines to construct new higher international poverty line (corresponding to $3.2 & $5.5 2011 PPP) with revised 2011 PPPs and 2017 PPPs
** Input 1	: The Stata code below was largely created by R.Andres Castaneda and Christoph Lakner (References: https://github.com/worldbank/povcalnet)
** Input 2  : PPP data set, filename(ppp.dta)
** Input 3	: CPI data set, filename(cpi.dta)
** Input 4	: Jolliffe & Prydz (2016) --> https://link.springer.com/article/10.1007/s10888-016-9327-5
** Input 5  : Jolliffe & Prydz (2016), Appendix 2 of Policy Research Working Paper, No. 7606 --> http://documents.worldbank.org/curated/en/837051468184454513/pdf/WPS7606.pdf
** Date     : May 9, 2020
** Author(s): Samuel Kofi Tetteh Baah & Daniel Mahler (source code: R.Andres Castaneda and Christoph Lakner)

*********************************************************************************************************************************************************************************
	
version 14
drop _all



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




*********************************************************************************************************************************************************************************
*1) Gather data on national poverty rates 
*********************************************************************************************************************************************************************************
//Jolliffe & Prydz (2016) downloaded the series below on 12 November, 2015. They had 800 national poverty lines. 
//No mention is made of the period under consideration. I take a guess based on data points in Appendix A2 of the working paper.

wbopendata, indicator(SI.POV.NAHC.NC) clear long

rename si_pov_nahc_nc headcount

drop if headcount==.
*keep if year<2013    //I take a guess based on data points in Appendix A2 of the working paper.

count   //I have 795 observations, they have 800 observations.

keep countrycode countryname region regionname incomelevel incomelevelname year headcount

merge 1:1 countrycode year using `"${data}/surveys_query.dta"', gen(m1)
count if m1==3   //I have matched 703 country-year observations in Povcalnet master. They matched 700.
keep if m1==3

egen countryid = group(countrycode)
sum countryid
gen N = r(max)
display N    //I have 126 countries, they have 107 countries.

gen source = "WB GPWG/PID"

save `"${data}/wb_national_poverty_rates.dta"', replace


use `"${data}/wb_national_poverty_rates.dta"', clear


*Get relative povertry rates for OECD countries
	
	//PVT6A: Poverty rate after taxes and transfers, Poverty line 60%  (i.e., share of population living on below 60% of median disposable income)
	//Data source: https://stats.oecd.org/Index.aspx?DataSetCode=IDD#
	//Downloaded 28/03/2020
	//They include OECD poverty rates for Australia, Austria, Belgium, Czech Republic, Denmark, Estonia, Finland, France, Germany,
	//Greece, Hungary, Iceland, Ireland, Israel, Italy, Luxembourg, Mexico, Netherlands, Norway, Poland,
	//Portugal, Slovak Republic, Spain, Sweden, Switzerland, Turkey and United Kingdom.

import excel `"${data}/oecd_poverty_rates_raw_data.xlsx"', sheet("oecd_poverty_rates_raw_data") firstrow clear

	*Clean data 
	keep if Agegroup=="Total population"
	keep if MEASURE=="PVT6B"
	keep if Methodology=="New income definition since 2012"
	
	keep LOCATION Country Year Value Flags
	rename LOCATION countrycode
	rename Country countryname 
	rename Year year
	rename Value headcount 
	rename Flags oecd_pov_flag
	
	replace headcount = 100*headcount
	
	keep if inlist(countrycode, "AUS","AUT","BEL","CZE","DNK","FIN","FRA") | inlist(countrycode,"DEU","GRC","HUN","ISL","IRL","ISR") ///
		| inlist(countrycode,"ITA","LUX","MEX","NLD","NOR","SVK") | inlist(countrycode,"PRT","ESP","SWE","CHE","TUR","GBR","ESP")
	
	gen source = "OECD"
	
	sort countrycode year
	tempfile oecd_pov_rates
	save `oecd_pov_rates', replace

preserve	
*US: poverty rates are from U.S. Bureau of the Census, Current Population Survey.
	
	//Source (a): https://www.census.gov/data/tables/time-series/demo/income-poverty/p70-137.html   (see Table 2a [2005, 2006, 2007] and Table 2b [2009, 2010, 2011])
	//Source (b): https://www.census.gov/data/tables/time-series/demo/income-poverty/p70-123.html   (see Table 5 [2004, 2005, 2006])

import excel `"${data}/US poverty data.xlsx"', sheet("cleaned") firstrow clear
	keep pov*
	gen countrycode = "USA"
	gen countryname = "United States"
	drop if pov2005 == .
	destring pov2004 pov2005_ pov2006_, replace ignore("...")
	replace  pov2004 = pov2004/10
	replace  pov2005_ = pov2005_/10
	replace pov2006_ = pov2006_/10
	
	list pov*   
	drop pov2005_ pov2006_ //poverty rates from two different Excel sheets (from different links, but same US Census Bureau) are the same.
	
	reshape long pov, i(countrycode) j(year)
	line pov year     //rising absolute poverty in the US between 2005 to 2011. 
	rename pov headcount
	
	gen source = "US Census Bureau"
	
	sort countrycode year
	tempfile us_pov_rates
	save `us_pov_rates', replace
	
	
*Canada: poverty rates are from Statistics Canada

	//Canada does not measure poverty, but rather refers to the prevalence of low-income status. In Jolliffe and Prydz (2016), the source for the low-income estimates is Statistics Canada, CANSIM table 202-0802 and Catalogue no. 75-202-X	
	//In this paper, the source of Canada poverty rates is the same: https://www150.statcan.gc.ca/t1/tbl1/en/cv.action?pid=1110018101#timeframe. See Table: 11-10-0181-01 (formerly CANSIM 202-0802)				
	//The series selected for analysis: Low income measures (LIMs) after tax, are relative measures of low income, set at 50% of adjusted median household income. 
	//These measures are categorized according to the number of persons present in the household, 	reflecting the economies of scale inherent in household size.

import excel `"${data}/Canada poverty data.xlsx"', sheet("cleaned") firstrow clear	
	
	rename A countrycode
	replace countrycode = "CAN"
	gen countryname = "Canada"
	reshape long y, i(countrycode) j(year)
	rename y headcount
	
	sort countrycode year
	tempfile canada_pov_rates
	
	gen source = "Statistics Canada"
	
	save `canada_pov_rates', replace
restore

*Combine relative poverty rates for OECD countries
use `oecd_pov_rates', clear
append using `us_pov_rates'
append using `canada_pov_rates'


save `"${data}/oecd_pov_rates.dta"', replace 	
	
	
*Combine all national poverty rates that will be used to calculate implicit poverty rates.	
use `"${data}/wb_national_poverty_rates.dta"', clear	
append using `"${data}/oecd_pov_rates.dta"'

gen coverage ="National"

keep countrycode countryname year headcount incomelevelname oecd_pov_flag coverage source
duplicates drop _all, force
rename headcount headcount_nat

*drop if inlist(countrycode,"CZE","HUN","MEX","TUR","SVK")   //The observations drawn from the WB website are more preferred, some of the OECD estimates are poverty rates after tax but before transfer (see variable "oecd_pov_flag")

drop if inlist(countrycode,"CZE","HUN","MEX","TUR","SVK")  & source=="OECD"   //The observations drawn from the WB website are more preferred, some of the OECD estimates are poverty rates after tax but before transfer (see variable "oecd_pov_flag")


encode source, generate(source2)
drop source 
rename source2 source

save `"${data}/national_pov_rates.dta"', replace 




preserve
	povcalnet, country(all) year(all) clear 
	keep countrycode year datayear
	duplicates drop 

	tempfile datayear
	save `datayear', replace 
restore


merge 1:1 countrycode year using `datayear', keep(3)

gen double y = round(headcount_nat,0.1)

replace headcount_nat = y/100
keep countrycode year datayear headcount_nat  
rename year year_
rename datayear year

sort countrycode year

gen obs = _n 


save `"${data}/ccc_year_headcount_nat"', replace 



use `"${data}/ccc_year_headcount_nat"', clear
*rename year y1
*rename year_ y2

save `"${data}/ccc_year_headcount_nat"', replace

count

*236 268 286 287 288 340 367 378-381 383 388
local row = 53

forvalues row=`row'/`r(N)' {

use `"${data}/ccc_year_headcount_nat"', clear

local n = obs[`row']

** Initial conditions (it could be any number)
local pl         = 1   // MODIFY (if you want): starting point (it could be any positive number)

local years = y1[`row']
display `years'


local goals = headcount_nat[`row']

 
local tolerance  = .001          // MODIFY (if you want)
local ni         = 20             // number of iterations before failing

*local countries = "DOM"      // MODIFY
local countries = countrycode[`row']

** Get the country codes to loop over. 

if (inlist("`countries'", "all", "")) {
	povcalnet info, clear
	sort country_code
	drop if _n<=138
	drop if country_code=="SUR"
	levelsof country_code, clean
	local countries = "`r(levels)'"	
}

** get proper names for variables of Output
foreach g of local goals {
	local  p = strtoname("p`=`g'*100'")
	local pnames " `p'"
		
	*local pnames "`pnames' `p'"
	*local pnames "`pnames' `p'"
}


// ------------------------------------------------------------------------
// loop over countries
// ------------------------------------------------------------------------

foreach country of local countries {
	*Define coverage variable:	
	if "`country'"=="ARG" 		local coverage="urban"
	else						local coverage="national"

	tempname M N      // matrix with results
	// ------------------------------------------------------------------------
	// loop over goals
	// ------------------------------------------------------------------------

	foreach goal of local goals {

		disp _n as text "iterations for goal `goal':"

		local s          = 0    // iteration stage counter
		local num        = 1    // numerator
		local i          = 0    // general counter
	  local delta      = 3    // MODIFY (if you want): Initial change of povline value

		qui povcalnet, countr(`country') povline(`pl') clear year(`years') coverage(`coverage')
		local attempt = headcount[1]

		while (round(`attempt', `tolerance') != `goal' & `s' <= `ni') {
			local ++i
			if (`attempt' < `goal') {  // before crossing goal
				while (`pl' + `delta' < 0) {
					local delta = `delta'*2
				}
				local pl = `pl' + `delta'
				local below = 1
			}
			if (`attempt' > `goal') {  // first time above goal
				while (`pl'-`delta' < 0) {
					local delta = `delta'/2
				}
				local pl  =  `pl'-`delta'
				local below = 0
			}
			
			*** Call data
			qui povcalnet, countr(`country') povline(`pl') clear year(`years')
			local attempt = headcount[1]
			
			disp in y "`s':" in w _col(5) "pl:" _col(10) `pl' _col(21) "attempt:" _col(28) `attempt'
			
			if ( (`attempt' > `goal' & `below' == 1) | /* 
			 */  (`attempt' < `goal' & `below' == 0) ) { 
				local ++s
				if mod(`s',2) local one = -1
				else          local one =  1
				
				local num = (2*`num')+`one'
				local den = 2^`s'
				local delta =  (`num'/`den')*`delta'
				
			} // end of condition to change the value of delta
		}  // end of while

	mat `M' = nullmat(`M') \ `goal', `pl'

	}

	// ------------------------------------------------------------------------
	// Display results
	// ------------------------------------------------------------------------

	mat colnames `M' = goal value

	mat list `M'

	mat `N'=`M'[1...,2]'	// transpose matrix
	mat colnames `N' = `pnames'

	*Save in a data file
	drop _all
	
	svmat `N', n(col)
	 
	

	gen countrycode="`country'"
	
	
} // end of countries loop

	
 save `"${data}/percentiles/`n'.dta"', replace
 exit
 local row = `row' + 1
 *display `row'
	}
	
	
	

*Combine results
use `"${data}/percentiles/1.dta"', clear

gen id = 1
forvalues i = 2/1108{
	
	capture append using `"${data}/percentiles/`i'.dta"'
	replace id = `i' if id==.
}

sum
egen impline = rowmean(p*)
keep countrycode id impline
rename id obs

merge 1:1 countrycode obs using `"${data}/ccc_year_headcount_nat"', gen(m1)

rename y1 datayear
rename y2 year 
rename impline impline1

merge 1:1 countrycode year using `"${data}/additional_implicit_lines.dta"', gen(m2)

rename impline impline2

replace impline1 = impline2 if impline1==.
rename impline1 impline

keep countrycode impline year headcount_nat datayear


*br if _merge==2

kdensity impline
gen year_abs = abs(year-2017)
egen year_min = min(year_abs),by(countrycode)
keep if year_abs == year_min
tab year if impline!=.
keep if impline!=.
gen dum1 = (year>2011)
gen dum2 = (year==2017)
sum dum*



replace year = year + 1

merge 1:1 countrycode year using `"${data}/historical_inc_groups.dta"', keep(3)

replace year = year - 1 


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
drop _merge


*Add PPP data
merge 1:1 countrycode coveragetype using `"${dir}/data/ppp.dta"', nogen

	foreach var of varlist ppp2011_original ppp2011_revised ppp2017{
	replace `var' = . if `var'==-1
	}


rename ppp2011_original ppp2011

gen ppp_ = ppp2011/ppp2017
gen cpi_ = cpi2017/cpi2011

keep if impline!=.

sum impline ppp_ cpi_

*drop if ppp_==.

*tab countrycode if ppp_==. 
*replace ppp_=1 if inlist(countrycode,"SYR","TUV","VEN","YEM","KIR")  //PPP set to no change for countries with no 2017 PPPs : inlist(countrycode,"SYR","TUV","VEN","XKX","YEM")
*replace cpi_=1 if inlist(countrycode,"SYR","TUV","VEN","YEM","KIR")     //CPI ratio is also set to 1: inlist(countrycode,"SYR","TUV","VEN","XKX","YEM")

replace ppp_=. if inlist(countrycode,"SYR","TUV","VEN","YEM","KIR")  //Drop countries with no 2017 PPPs : inlist(countrycode,"SYR","TUV","VEN","XKX","YEM")
replace cpi_=. if inlist(countrycode,"SYR","TUV","VEN","YEM","KIR")     //Drop countries with no 2017 PPPs : inlist(countrycode,"SYR","TUV","VEN","XKX","YEM")

drop if inlist(countrycode,"EGY","IRQ","JOR","LAO","MMR","YEM")  //Drop countries whose PPPs are imputed Egypt, Iraq, Jordan, Lao, Myanmar and Yemen


sum impline ppp_ cpi_

gen impline_2017 = impline*(cpi_)*(ppp_)

egen income_mu = mean(impline_2017),by(incgroup_historical)
egen income_med = median(impline_2017),by(incgroup_historical)
egen n_income = count(impline_2017),by(incgroup_historical)

table incgroup_historical, c(mean income_med mean income_mu mean n_income) format(%9.2f)


merge 1:1 countrycode using `"${dir}/data/impline_revised.dta"'

twoway kdensity impline, graphregion(color(white)) legend(lab(1 "Original 2011 PPPs") lab(2 "2017 PPPs")) ytitle("Density") xtitle("Implicit poverty line, PPP$ per person per day") lcolor("204 78 1")  ylabel(0(0.05)0.20)|| kdensity impline_2017, lcolor("0 128 157") 



preserve
	keep countryname year datayear incgroup_historical headcount_nat impline impline_2017 ppp2011 ppp2011_revised ppp2017 cpi2011 cpi2017 ppp_ cpi_ 

	order countryname year datayear incgroup_historical headcount_nat impline impline_2017 ppp2011 ppp2011_revised ppp2017 cpi2011 cpi2017 ppp_ cpi_ 
	
	replace headcount_nat = 100*headcount_nat

	lab var countryname 		"Country"
	lab var year 				"Year"
	lab var datayear 			"Data year"
	lab var incgroup_historical "Income classification"
	lab var impline 			"Implicit line (Original 2011 PPP)"
	lab var impline_2017 		"Implicit line (2017 PPP)"
	lab var headcount_nat 		"National poverty line, %"
	lab var ppp2011 			"Original 2011 PPP"
	lab var ppp2011_revised 	"Revised 2011 PPP"
	lab var ppp2017 			"2017 PPP"
	lab var cpi2011 			"CPI 2011"
	lab var cpi2017 			"CPI 2017"
	lab var ppp_ 				"PPP ratio (PPP2011/PPP2017)"
	lab var cpi_ 				"CPI ratio (CPI2017/CPI2011)"

	export excel using `"${dir}/results/Higher Poverty Lines.xlsx"', sheet("Data 2017", modify) firstrow(varl) keepcellfmt 
restore



