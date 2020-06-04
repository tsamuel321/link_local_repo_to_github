

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
*mkdir "${dir}/data/equ_ipl_poverty_query"

/*
*Generate possible equivalent international poverty lines
set obs 350
gen double obs = _n 
gen double obs_ = _n * 0.002
gen double equ_ipl = 1.75 + obs_

*/
use `"${dir}/data/query_ipl_missing_countries.dta"', replace
rename equ_ipl equ_ipl_

merge m:1 obs using `"${dir}/data/equ_ipl_query.dta"', keep(3) nogen

count

save `"${dir}/data/query_ipl_missing_countries_.dta"', replace

*`r(N)'


forvalues row=1/`r(N)' {

use `"${dir}/data/query_ipl_missing_countries_.dta"', clear

local ipl = equ_ipl[`row']
local n = obs[`row']
local cc = countrycode[`row']
 
 global data_equ "${dir}/data/equ_ipl_poverty_query/`ipl'"
 

 *mkdir "${data_equ}"
		
*Get CPI data
use `"${dir}/data/cpi.dta"', clear

keep if year==2011 | year==2017
rename cpi2010 cpi

reshape wide cpi, i(countrycode) j(year)

gen cpi_2011_2017 = cpi2011/cpi2017

reshape long cpi, i(countrycode) j(year)
keep countrycode year cpi_2011_2017
rename cpi_2011_2017 cpi_

collapse cpi_, by(countrycode)

*Get relevant PPP ratio using 2011 original PPPs and 2017 PPPs
preserve 
	use `"${dir}/data/ppp.dta"', clear
	keep countrycode coveragetype ppp2011_original ppp2017
	keep if coveragetype=="National"
	drop coveragetype
	
	*Clean and organize data
	foreach var of varlist ppp2011_original ppp2017{
	replace `var' = . if `var'==-1
	}

	rename ppp2011_original ppp2011
	gen ppp_ = ppp2017/ppp2011
	
	keep countrycode ppp_
	
	tempfile ppp_2011orig_2017
	save `ppp_2011orig_2017', replace
restore
	
merge 1:1 countrycode using `ppp_2011orig_2017'

drop _merge

drop if countrycode=="KSV"

tempfile cpi_ppp_ratios
save `cpi_ppp_ratios', replace

/*
*/
*Query national poverty lines and poverty rates for the remaining countries
use `"${dir}/data/surveys_query.dta"', clear

drop year
duplicates drop

merge 1:1 countrycode using `cpi_ppp_ratios', keep(3) nogen
drop if inlist(countrycode,"CHN","IND","IDN")

gen pl = `ipl'*cpi_*ppp_

replace pl = 1.9 if inlist(countrycode,"SYR","TUV","VEN","YEM","KIR")  //These are the countries with survey data that do not have 2017 PPPs.

keep if inlist(countrycode,"`cc'")

save `"${dir}/data/survey_query_cpi_ppp_missing.dta"', replace

count

forvalues row=1/`r(N)' {

	// Finds what surveys to query
	use `"${dir}/data/survey_query_cpi_ppp_missing.dta"', clear

	loc ccc = countrycode[`row']
	loc pl = pl[`row']
	
	if "`ccc'"=="ARG" 		local coverage="urban"
	else					local coverage="national"

	
	povcalnet, country(`ccc') year(all) coverage(`coverage') povline(`pl') fillgaps clear
	save `"${data_equ}/`ccc'.dta"', replace
	}

	
*Combine (append) poverty data from all countries
use `"${data_equ}/AGO.dta"', clear 

*LBY OMN are missing countries in povcalnet

#delimit;
local ccc "ALB ARG ARM AUS AUT AZE BDI BEL BEN BFA BGD BGR BIH BLR BLZ BOL BRA BTN BWA CAF CAN CHE CHL CHN_rur CHN_urb CIV CMR COD COG COL COM CPV CRI CYP CZE DEU DJI DNK DOM DZA ECU EGY ESP EST ETH FIN FJI FRA GAB GBR GHA GIN
GMB GNB GRC GTM HND HRV HTI HUN IDN_rur IDN_urb IND_rur IND_urb IRL IRQ ISL ISR ITA JAM JOR JPN KAZ KEN KGZ KOR LAO LBR LCA LKA LSO LTU LUX LVA MAR MDA MDG MDV MEX MKD MLI MLT MMR MNE MNG MOZ MRT MUS MWI MYS NAM NER NGA NIC NLD
NOR NPL PAK PAN PER PHL POL PRT PRY PSE ROU RUS RWA SDN SEN SLE SLV SRB STP SUR SVK SVN SWE SWZ SYC TCD TGO THA TJK TTO TUN TUR TZA UGA URY USA VEN VNM YEM ZAF ZMB ZWE FSM GEO GUY IRN KIR LBN PNG SLB SSD SYR TKM TLS TON TUV UKR UZB VUT WSM XKX ARE TWN
";

#delimit cr;  

 foreach x of local ccc {
	append using `"${data_equ}/`x'.dta"', force
	}
	
save `"${data_equ}/ipl2017_poverty_query.dta"', replace	
	


*Combine query results
use `"${data_equ}/ipl2017_poverty_query.dta"', clear

*keep if year==2015

*First off, determine the national poverty rates for China, India, and Indonesia.
gen poor_urb_rur = headcount*population if inlist(countrycode, "CHN","IND","IDN")
egen poor_total = sum(poor_urb_rur) if inlist(countrycode, "CHN","IND","IDN"), by(countrycode year)
egen pop_total = sum(population) if inlist(countrycode, "CHN","IND","IDN"), by(countrycode year)
gen headcount_nat = poor_total/pop_total

list countrycode coveragetype povertyline headcount population poor_urb_rur poor_total pop_total headcount_nat if inlist(countrycode,"CHN","IND","IDN")

drop if coveragetype == 1    //Drop all Rural coverage, which holds for only these three countries.
replace coveragetype = 3 if inlist(countrycode, "CHN", "IND", "IDN")  //Set Urban coverage to National for these three countries.
replace headcount = headcount_nat if inlist(countrycode, "CHN", "IND", "IDN")    //replace headcount with national headcount
replace population = pop_total if inlist(countrycode, "CHN", "IND", "IDN")  //replace Urban population with National population


list countrycode coveragetype povertyline headcount population poor_urb_rur poor_total pop_total headcount_nat if inlist(countrycode,"CHN","IND","IDN")
drop poor_urb_rur poor_total pop_total headcount_nat

save `"${data_equ}/ipl2017_poverty_query_new.dta"', replace	
count

}
exit