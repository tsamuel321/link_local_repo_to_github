

	
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


 foreach num in 2 2.01 2.02 2.03 2.04 2.05 2.06 2.07 2.08 2.09 2.1 2.11 2.12 2.13 2.14 2.15 2.16 2.17 2.18 2.19 2.2 2.21 2.22 2.23 2.24 2.25 2.26 2.27 2.28 2.29 {
 
 global data_equ "${dir}/data/equ_ipl_poverty_query/`num'"
 
 mkdir "${data_equ}"
	
	
		
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
	gen pl = `num'*cpi_*ppp_
	
	save `"${dir}/data/CHN_IND_IDN/chi_ind_indo_urb.dta"', replace

	count
	
	forvalues row=1/`r(N)' {

		// Finds what surveys to query
		use `"${dir}/data/CHN_IND_IDN/chi_ind_indo_urb.dta"', clear
		
		loc ccc = countrycode[`row']
		loc pl = pl[`row']
		
		povcalnet, country(`ccc') year(all) coverage(urban) povline(`pl') fillgaps clear
		save `"${data_equ}/`ccc'_urb.dta"', replace
		}

restore	

*Query rural poverty lines and poverty rates for China, India, and Indonesia.
		keep if coverage=="Rural"
		keep countrycode countryname ppp_ cpi_ 
		gen pl = `num'*cpi_*ppp_
		
		save `"${dir}/data/CHN_IND_IDN/chi_ind_indo_rur.dta"', replace

		count
		
		forvalues row=1/`r(N)' {

			// Finds what surveys to query
			use `"${dir}/data/CHN_IND_IDN/chi_ind_indo_rur.dta"', clear
			
			loc ccc = countrycode[`row']
			loc pl = pl[`row']
			
			 povcalnet, country(`ccc') year(all) coverage(rural) povline(`pl') fillgaps clear
			save `"${data_equ}/`ccc'_rur.dta"', replace
			
			}

	
*Query national poverty lines and poverty rates for the remaining countries
use `"${dir}/data/surveys_query.dta"', clear

drop year
duplicates drop

merge 1:1 countrycode using `cpi_ppp_ratios', keep(3) nogen
drop if inlist(countrycode,"CHN","IND","IDN")

gen pl = `num'*cpi_*ppp_

replace pl = 1.9 if inlist(countrycode,"SYR","TUV","VEN","YEM","KIR")  //These are the countries with survey data that do not have 2017 PPPs.


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
	


//////Now poverty analysis/////////
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

preserve

	*Load population data from povcalnet master file
	pcn master, load(pop)
	
	append using `"${dir}/data/eritrea_pop.dta"'   //Add Eritrea's population data
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

*Global aggregation 
collapse headcount pop, by(countryname year)
bysort year: egen headcount_gloavg = wtmean(headcount), weight(pop)

egen global_pop = total(pop),by(year)
replace headcount_gloavg = 100*headcount_gloavg

collapse headcount_gloavg global_pop,by(year)

gen poor_glo = (headcount_gloavg*global_pop)/100

gen countryname="World"

keep countryname headcount_gloavg poor_glo global_pop year
order countryname year headcount_gloavg poor_glo global_pop
drop if headcount_gloavg==.

lab var headcount_gloavg "Global poverty rate, %"
lab var poor_glo "Millions of poor"
lab var global_pop "Global population"

gen equ_ipl = `num'

save `"${data_equ}/ipl.dta"', replace

}




