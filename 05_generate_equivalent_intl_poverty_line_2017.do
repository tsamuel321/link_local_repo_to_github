
	
*********************************************************************************************************************************************************************************

** Purpose  : Compute an equivalent IPL in 2017 PPPs that retains 2005, 2015 global poverty rate in 2011 PPPs
** Input 1	: The Stata code below was largely created by R.Andres Castaneda and Christoph Lakner (References: https://github.com/worldbank/povcalnet)
** Input 2  : PPP data set, filename(ppp.dta)
** Input 3	: CPI data set, filename(cpi.dta)
** Input 4	: Jolliffe & Prydz (2016) --> https://link.springer.com/article/10.1007/s10888-016-9327-5
** Input 5  : Jolliffe & Prydz (2016), Appendix 2 of Policy Research Working Paper, No. 7606 --> http://documents.worldbank.org/curated/en/837051468184454513/pdf/WPS7606.pdf
** Date     : May 21, 2020
** Author(s): Samuel Kofi Tetteh Baah & Daniel Mahler 

*********************************************************************************************************************************************************************************
	


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


*Generate possible equivalent international poverty lines
set obs 350
gen double obs = _n 
gen double obs_ = _n * 0.002
gen double equ_ipl = 1.75 + obs_


save `"${dir}/data/equ_ipl_query.dta"', replace

count

*

forvalues row=1/`r(N)' {



use `"${dir}/data/equ_ipl_query.dta"', clear

local ipl = equ_ipl[`row']
local n = obs[`row']
 
 global data_equ "${dir}/data/equ_ipl_poverty_query/`ipl'"
 
/*
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


*Get separate 2017 urban, rural PPPs for China, India, and Indonesia 
use `"${dir}/data/ppp.dta"', clear
keep countryname countrycode coveragetype ppp2017
keep if inlist(countrycode,"CHN","IND","IDN")

replace ppp2017 = . if ppp2017==-1

sort countryname coverage
order countryname countrycode coverage ppp2017
	
	
*Get original 2011 PPPs from povcalnet master data
preserve
	pcn master, load(ppp)
	keep if inlist(countrycode, "CHN", "IND", "IDN")
	keep countrycode countryname coveragetype ppp2011
	
	
	tempfile urb_rur_ppp2011
	save `urb_rur_ppp2011', replace
restore
	
merge 1:1 countrycode countryname coverage using `urb_rur_ppp2011', keep(3) nogen

save `"${dir}/data/CHN_IND_IDN/urb_rur_ppp.dta"', replace



*Get separate urban, rural CPI series for China
import excel "${dir}/data/CHN_IND_IDN/Summary calculations v3 stata input.xlsx", sheet("China sources cleaned") firstrow clear 

	keep year cpi_rur cpi_urb
	keep if year==2011 | year==2017

	rename cpi_rur cpi_rur1
	rename cpi_urb cpi_urb2

	gen id = _n
	reshape long cpi_rur cpi_urb, i(id) j(coveragetype)
	egen cpi = rowmean(cpi_rur cpi_urb)

	gen coverage = "Rural" if coveragetype==1
	replace coverage = "Urban" if coveragetype==2

	drop cpi_rur cpi_urb id coveragetype

	reshape wide cpi, i(coverage) j(year)

	*Urban-rural price ratio is 1.285 in 2011
	replace cpi2011 = cpi2011 if coverage=="Rural"
	replace cpi2011 = 1.285*cpi2011 if coverage=="Urban"

	replace cpi2017 = cpi2011*cpi2017 if coverage=="Rural" 
	replace cpi2017 = cpi2011*cpi2017 if coverage=="Urban"

	gen countryname = "China"
	gen countrycode = "CHN"

	tempfile cpi_china
	save `cpi_china', replace

 

*Get separate urban, rural CPI series for India
import excel "${dir}/data/CHN_IND_IDN/Summary calculations v3 stata input.xlsx", sheet("India sources cleaned") firstrow clear 

	keep if Year==2011 | Year==2017
	keep Year AVG_urb AVG_rur
	gen year = 2011 if Year==2011
	replace year = 2017 if Year==2017

	rename AVG_urb cpi_urb
	rename AVG_rur cpi_rur
	drop Year 

	rename cpi_rur cpi_rur1
	rename cpi_urb cpi_urb2

	gen id = _n
	reshape long cpi_rur cpi_urb, i(id) j(coveragetype)

	egen cpi = rowmean(cpi_rur cpi_urb)

	gen coverage = "Rural" if coveragetype==1
	replace coverage = "Urban" if coveragetype==2
	drop cpi_rur cpi_urb id coveragetype

	reshape wide cpi, i(coverage) j(year)

	gen countryname = "India"
	gen countrycode = "IND"

	tempfile cpi_india
	save `cpi_india', replace


*For Indonesia, CPI series is available only at the national level, so rural and urban CPIs are the same.
pcn master, load(cpi)	
	
	keep if countrycode=="IDN"
	keep if year==2011 | year==2017
	
	replace coveragetype = "Rural" if coveragetype=="rural"
	replace coveragetype = "Urban" if coveragetype=="urban"
	rename coveragetype coverage
	
	keep countrycode countryname coverage cpi year
	
	reshape wide cpi, i(countrycode countryname coverage) j(year)
	
	tempfile cpi_indonesia
	save `cpi_indonesia', replace
	

*Combine CPIs for China, India, and Indonesia.	
use `cpi_china', clear
append using `cpi_india'
append using `cpi_indonesia'

rename coverage  coveragetype
	
save `"${dir}/data/CHN_IND_IDN/urb_rur_cpi.dta"', replace	
	
*Combine both CPIs and PPPs for China, India, and Indonesia.
use `"${dir}/data/CHN_IND_IDN/urb_rur_cpi.dta"', clear
merge 1:1 countrycode countryname coveragetype using `"${dir}/data/CHN_IND_IDN/urb_rur_ppp.dta"', nogen keep(3)

order countryname countrycode coverage 

gen ppp_ = ppp2017/ppp2011

gen cpi_ = cpi2011/cpi2017
	
	
*Query urban poverty lines and poverty rates for China, India, and Indonesia.
	
preserve
	keep if coverage=="Urban"
	keep countrycode countryname ppp_ cpi_ 
	gen pl = `ipl'*cpi_*ppp_
	
	save `"${dir}/data/CHN_IND_IDN/chi_ind_indo_urb.dta"', replace

	count
	
	forvalues row=1/`r(N)' {

		// Finds what surveys to query
		use `"${dir}/data/CHN_IND_IDN/chi_ind_indo_urb.dta"', clear
		
		loc ccc = countrycode[`row']
		loc pl = pl[`row']
		
		capture povcalnet, country(`ccc') year(all) coverage(urban) povline(`pl') fillgaps clear
		save `"${data_equ}/`ccc'_urb.dta"', replace
		}

restore	

*Query rural poverty lines and poverty rates for China, India, and Indonesia.
		keep if coverage=="Rural"
		keep countrycode countryname ppp_ cpi_ 
		gen pl = `ipl'*cpi_*ppp_
		
		save `"${dir}/data/CHN_IND_IDN/chi_ind_indo_rur.dta"', replace

		count
		
		forvalues row=1/`r(N)' {

			// Finds what surveys to query
			use `"${dir}/data/CHN_IND_IDN/chi_ind_indo_rur.dta"', clear
			
			loc ccc = countrycode[`row']
			loc pl = pl[`row']
			
			 capture povcalnet, country(`ccc') year(all) coverage(rural) povline(`pl') fillgaps clear
			save `"${data_equ}/`ccc'_rur.dta"', replace
			
			}


*Query national poverty lines and poverty rates for the remaining countries
use `"${dir}/data/surveys_query.dta"', clear

drop year
duplicates drop

merge 1:1 countrycode using `cpi_ppp_ratios', keep(3) nogen
drop if inlist(countrycode,"CHN","IND","IDN")

gen pl = `ipl'*cpi_*ppp_

replace pl = 1.9 if inlist(countrycode,"SYR","TUV","VEN","YEM","KIR")  //These are the countries with survey data that do not have 2017 PPPs.

*keep if inlist(countrycode,"LBN","NLD","COD")

save `"${dir}/data/survey_query_cpi_ppp.dta"', replace

count

forvalues row=1/`r(N)' {

	// Finds what surveys to query
	use `"${dir}/data/survey_query_cpi_ppp.dta"', clear

	loc ccc = countrycode[`row']
	loc pl = pl[`row']
	
	if "`ccc'"=="ARG" 		local coverage="urban"
	else					local coverage="national"

	
	capture povcalnet, country(`ccc') year(all) coverage(`coverage') povline(`pl') fillgaps clear
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

*/



*Calculate global poverty rate
use `"${data_equ}/ipl2017_poverty_query_new.dta"', clear
	

*Set Argentina's urban population to national, since headcount is for only urban Argentina...in oder to coincide with other countries in the data set and facilitate poverty calculations.
replace coveragetype = 3 if countrycode=="ARG"    //This step will be undone later. 

generate str coverage = "."

replace coverage = "National" if coveragetype ==3
keep if coveragetype==3 
drop regioncode

merge m:1 countrycode using `"${dir}/data/economies.dta"', keep(3) nogen

*Regional and global counts

*Now include the population of countries which are not in povcalnet and prepare the data for poverty calculations
/*
preserve
	//First, organize population data for Eritrea and add later to population data in povcalnet master file.
	import excel "${dir}\data\Eritrea pop.xlsx", sheet("Sheet1") firstrow clear 
	rename A countrycode
	rename B series
	drop Time
	replace series = "National" if series=="SP.POP.TOTL"
	replace series = "Urban" if series=="SP.URB.TOTL"
	replace series = "Rural" if series=="SP.RUR.TOTL"
	reshape long YR, i(countrycode series) j(year)
	rename YR population
	replace population = population/1000000   //population per million as in povcalnet master file.
	gen countryname = "Eritrea"
	rename series coveragetype
	duplicates drop
	save `"${dir}/data/eritrea_pop.dta"', replace
restore
*/
preserve

	*Load population data from povcalnet master file
	pcn master, load(pop)
	
	*append using `"${dir}/data/eritrea_pop.dta"'   //Add Eritrea's population data
	duplicates drop
	
	rename coveragetype coverage
	keep if coverage=="National"
	*keep if year==2015

	duplicates drop
	save `"${dir}/data/pop.dta"', replace

restore

merge m:1 countrycode year coverage using `"${dir}/data/pop.dta"'

preserve
*Get a file for countries not available in povcalnet

	keep if _merge==2                         //these are countries not available in povcalnet
	keep countryname countrycode coverage pop year
	save `"${dir}/data/pop_povcalnet_na.dta"', replace
restore


preserve
*Argentina national population
	pcn master, load(pop)
	
	keep if countrycode=="ARG"
	keep if coveragetype=="National"                     
	keep countrycode population year
	rename population pop
		
	save `"${dir}/data/argentina_national_pop.dta"', replace
restore

keep countrycode countryname headcount population coverage year

append using `"${dir}/data/pop_povcalnet_na.dta"'

merge m:1 countrycode using `"${dir}/data/economies"', keep(3) nogen

duplicates drop

keep if coverage=="National"
duplicates drop _all, force

merge m:1 countrycode year using `"${dir}/data/argentina_national_pop.dta"'    //Use Argentina's national population for the calculations.
keep if _merge==1 | _merge==3
drop _merge
replace population = pop if countrycode=="ARG"
drop pop

*Regional aggregation 
bysort region year: egen headcount_regavg = wtmean(headcount), weight(pop)
replace headcount = headcount_regavg if missing(headcount)     //Assign to countries without povcalnet poverty numbers the poverty rate of their region

preserve
drop if headcount==.
keep if inlist(year,2010,2012,2015)
egen reg_pop = total(pop),by(region year)
gen poor_reg = (headcount_regavg*reg_pop)/100

collapse headcount_regavg reg_pop poor_reg,by(region year)

rename headcount_regavg headcount
rename reg_pop population 
rename poor_reg poor 

replace headcount = 100*headcount

tempfile region_wb
save `region_wb'
restore


*Global aggregation 
collapse headcount pop, by(countryname year)
bysort year: egen headcount_gloavg = wtmean(headcount), weight(pop)

egen global_pop = total(pop),by(year)
replace headcount_gloavg = 100*headcount_gloavg

collapse headcount_gloavg global_pop,by(year)

gen poor_glo = (headcount_gloavg*global_pop)/100

gen region="WLD"

keep region headcount_gloavg poor_glo global_pop year
order region year headcount_gloavg poor_glo global_pop
drop if headcount_gloavg==.

lab var headcount_gloavg "Global poverty rate, %"
lab var poor_glo "Millions of poor"
lab var global_pop "Global population"

rename headcount_gloavg headcount
rename global_pop population 
rename poor_glo poor 

keep if inlist(year,2010,2012,2015)


append using `region_wb'

gen equ_ipl = `ipl'

save `"${data_equ}/ipl.dta"', replace

display `ipl'
display `n'
 
}




*Combine (append) results
global data "${dir}/data/equ_ipl_poverty_query"


use `"${data}/1.752/ipl.dta"', clear

 foreach num in 1.754 1.756 1.758 1.76 1.762 1.764 1.766 1.768 1.77 1.772 1.774 1.776 1.778 1.78 1.782 1.784 1.786 1.788 1.79 1.792 1.794 1.796 1.798 1.8 1.802 1.804 1.806 1.808 1.81 1.812 1.814 1.816 1.818 1.82 1.822 1.824 1.826 1.828 1.83 1.832 1.834 1.836 1.838 1.84 1.842 1.844 1.846 1.848 1.85 1.852 1.854 1.856 1.858 1.86 1.862 1.864 1.866 1.868 1.87 1.872 1.874 1.876 1.878 1.88 1.882 1.884 1.886 1.888 1.89 1.892 1.894 1.896 1.898 1.9 1.902 1.904 1.906 1.908 1.91 1.912 1.914 1.916 1.918 1.92 1.922 1.924 1.926 1.928 1.93 1.932 1.934 1.936 1.938 1.94 1.942 1.944 1.946 1.948 1.95 1.952 1.954 1.956 1.958 1.96 1.962 1.964 1.966 1.968 1.97 1.972 1.974 1.976 1.978 1.98 1.982 1.984 1.986 1.988 1.99 1.992 1.994 1.996 1.998 2 2.002 2.004 2.006 2.008 2.01 2.012 2.014 2.016 2.018 2.02 2.022 2.024 2.026 2.028 2.03 2.032 2.034 2.036 2.038 2.04 2.042 2.044 2.046 2.048 2.05 2.052 2.054 2.056 2.058 2.06 2.062 2.064 2.066 2.068 2.07 2.072 2.074 2.076 2.078 2.08 2.082 2.084 2.086 2.088 2.09 2.092 2.094 2.096 2.098 2.1 2.102 2.104 2.106 2.108 2.11 2.112 2.114 2.116 2.118 2.12 2.122 2.124 2.126 2.128 2.13 2.132 2.134 2.136 2.138 2.14 2.142 2.144 2.146 2.148 2.15 2.152 2.154 2.156 2.158 2.16 2.162 2.164 2.166 2.168 2.17 2.172 2.174 2.176 2.178 2.18 2.182 2.184 2.186 2.188 2.19 2.192 2.194 2.196 2.198 2.2 2.202 2.204 2.206 2.208 2.21 2.212 2.214 2.216 2.218 2.22 2.222 2.224 2.226 2.228 2.23 2.232 2.234 2.236 2.238 2.24 2.242 2.244 2.246 2.248 2.25 2.252 2.254 2.256 2.258 2.26 2.262 2.264 2.266 2.268 2.27 2.272 2.274 2.276 2.278 2.28 2.282 2.284 2.286 2.288 2.29 2.292 2.294 2.296 2.298 2.3 2.302 2.304 2.306 2.308 2.31 2.312 2.314 2.316 2.318 2.32 2.322 2.324 2.326 2.328 2.33 2.332 2.334 2.336 2.338 2.34 2.342 2.344 2.346 2.348 2.35 2.352 2.354 2.356 2.358 2.36 2.362 2.364 2.366 2.368 2.37 2.372 2.374 2.376 2.378 2.38 2.382 2.384 2.386 2.388 2.39 2.392 2.394 2.396 2.398 2.4 2.402 2.404 2.406 2.408 2.41 2.412 2.414 2.416 2.418 2.42 2.422 2.424 2.426 2.428 2.43 2.432 2.434 2.436 2.438 2.44 2.442 2.444 2.446 2.448 2.45 {
 
append using `"${data}/`num'/ipl.dta"', force
	
}

egen id = group(equ_ipl)
*reshape wide headcount_gloavg poor_glo global_pop, i(id) j(year)
*keep if inlist(year,2010,2012,2015)

*rename countryname region 
*gen regioncode = "WLD"

*keep if inlist(year,2010,2012,2015)

rename region regioncode

preserve
	povcalnet wb, clear
	replace headcount = 100*headcount
	rename headcount headcount_wb
	rename population population_wb
	keep region regioncode year headcount_wb population_wb
	keep if  (year==2010 | year==2012 | year==2015)
	*keep if regioncode=="WLD"& (year==2010 | year==2012 | year==2015)

	tempfile headcount_wb
	save  `headcount_wb', replace
restore

merge m:1 regioncode year using `headcount_wb', keep(3) nogen
drop id
egen id = group(regioncode year)
gen diff = abs(headcount - headcount_wb)
egen diff_min = min(diff),by(id) 
keep if diff == diff_min

egen glo_poor_ = mean(poor) if regioncode=="WLD",by(year)
egen glo_poor =mean(glo_poor_),by(year)
drop glo_poor_

gen poor_shr = 100*poor/glo_poor
replace poor_shr = poor_shr/100 if regioncode=="WLD"







keep region year headcount equ_ipl poor poor
order region year headcount equ_ipl poor 


lab var region 		"Region"
lab var year 		 "Year"
lab var headcount	 "Headcount (2011 PPPs)"
lab var equ_ipl		 "Equivalent IPL (2017 PPPs)"

export excel using `"${dir}/results/Equivalent IPL.xlsx"', sheet("World", modify) firstrow(varl) keepcellfmt 


