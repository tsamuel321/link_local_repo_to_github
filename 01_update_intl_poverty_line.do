

**********************************************************************************************************************************************

** Purpose  : Update international poverty line ($1.9 2011 PPP) with revised 2011 PPPs and 2017 PPPs, as well as with new CPI series
** Input 1	: Poverty lines, CPIs (in 2011 PPP) of 15 poorest countries (Ferreira et al. 2016, Table 4, p.162)
** Input 2  : PPP data set, filename(ppp.dta)
** Input 3	: CPI data set, filename(cpi.dta)
** Date     : May 3, 2020
** Author(s): Samuel Kofi Tetteh Baah

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

set obs 15

gen countryname = ""
gen countrycode = ""
gen pl = .
gen cpi_old = .

local ccn "Chad Ethiopia Gambia Ghana Guinea-Bissau Malawi Mali Mozambique Nepal Niger Rwanda SierraLeone Tajikistan Tanzania Uganda"
local ccc "TCD ETH GMB GHA GNB MWI MLI MOZ NPL NER RWA SLE TJK TZA UGA"
local ccp "1.28 2.03 1.82 3.07 2.16 1.34 2.15 1.26 1.47 1.49 1.5 2.73 3.18 0.88 1.77"
local cci "112.4 297.1 129.3 295.2 124.8 214.6 119.8 173.5 164.8 116.3 157.8 203.9 334.2 169.9 178"

local n: word count `ccc'

 forvalues i = 1/`n' {
		local cn : word `i' of `ccn'
		local cc : word `i' of `ccc'		
		local cp : word `i' of `ccp'
		local ci : word `i' of `cci'
		
		replace countryname = "`cn'" in `i'
		replace countrycode = "`cc'" in `i'
		replace pl = `cp' in `i'
		replace cpi_old = `ci' in `i'
		
		local i = `i' + 1
   }

replace countryname = "Gambia, The" if countryname=="Gambia"
replace countryname = "Sierra Leone" if countryname=="SierraLeone"

merge 1:m countrycode using `"${dir}/data/ppp.dta"', keep(3) nogen

preserve
	use `"${dir}/data/cpi.dta"', clear
	keep if year==2005 | year==2011 | year == 2017
	keep if inlist(countrycode,"TCD","ETH","GMB","GHA","GNB","MWI","MLI","MOZ","NPL") | inlist(countrycode,"NER","RWA","SLE","TJK","TZA","UGA")
	
	rename cpi2010 cpi
	reshape wide cpi, i(countrycode) j(year)
	
	tempfile cpi_new
	save `cpi_new', replace
restore

merge 1:1 countrycode using `cpi_new', keep(3) nogen

keep countryname countrycode pl ppp2005 ppp2011_original ppp2011_revised ppp2017 cpi2005 cpi2011 cpi2017 cpi_old

gen cpi_2005_2011 = 100*(cpi2011/cpi2005)
gen cpi_2005_2017 = 100*(cpi2017/cpi2005)
gen cpi_2011_2017 = 100*(cpi2017/cpi2011)

label var cpi_old "CPI 2011, old (100=2005)"
label var cpi2005 "CPI2005"
label var cpi2011 "CPI2011"
label var cpi2017 "CPI2017"

label var cpi_2005_2011 "CPI 2011, new (100=2005)"
label var cpi_2005_2017 "CPI 2017 (100=2005)"
label var cpi_2011_2017 "CPI 2017 (100=2011)"

rename pl pl_2011

preserve

	*Update IPL with and without revised CPI and/or revised 2011 PPP
	gen pl_ppp = pl_2011*ppp2011_original/ppp2011_revised   //Update only PPP.
	gen pl_cpi = pl_2011*cpi_2005_2011/cpi_old				//Update only CPI.
	gen pl_ppp_cpi = pl_2011*ppp2011_original/ppp2011_revised*cpi_2005_2011/cpi_old	 //Update both PPP and CPI.


	egen ipl_2011 = mean(pl_2011)
	egen ipl_ppp = mean(pl_ppp)
	egen ipl_cpi = mean(pl_cpi)
	egen ipl_ppp_cpi = mean(pl_ppp_cpi)


	label var ipl_2011 		"IPL Original 2011 PPP"
	label var ipl_ppp 		"IPL Update PPP only"
	label var ipl_cpi 		"IPL Update CPI only"
	label var ipl_ppp_cpi 	"IPL Update both PPP and CPI"


	label var pl_2011 		"National Poverty Line Original 2011 PPP"
	label var pl_ppp 		"National Poverty Line Update PPP only"
	label var pl_cpi 		"National Poverty Line Update CPI only"
	label var pl_ppp_cpi 	"National Poverty Line Update both PPP and CPI"


	lab var countryname "Country"
	lab var countrycode "Code"

	keep countryname countrycode cpi* ppp* pl_* ipl_*
	format cpi* ppp* pl_* ipl_* %12.2f

	export excel using `"${dir}/results/IPL.xlsx"', sheet("Stata_ipl2011", modify) firstrow(varl) keepcellfmt 

restore

*Update IPL with and without revised CPI and/or 2017 PPP
gen pl_ppp_cpi = pl_2011*ppp2011_original/ppp2011_revised*cpi_2005_2011/cpi_old	 //Update both PPP and CPI.


egen ipl_2011 = mean(pl_2011)
egen ipl_ppp_cpi = mean(pl_ppp_cpi)


label var ipl_2011 		"IPL Original 2011 PPP"
label var ipl_ppp_cpi 	"IPL Revised 2011 PPP"

*Test the hypothesis that the 1.90 line is not statistically different from the 1.80 line.

mvtest means pl_2011 pl_ppp_cpi
ttest pl_2011 == pl_ppp_cpi, unpaired

*Approach A: Update IPL (revised 2011) with CPI and PPP (updating the CPI used in deriving 1.90 IPL original 2011)
gen ipl_2011_ = ipl_ppp_cpi
gen pl_2017_a = pl_ppp_cpi * ppp2011_revised/ppp2017 * cpi_2011_2017/100
egen ipl_2017_a = mean(pl_2017_a)

*Approach B: Update IPL (revised 2011) with CPI and PPP (not updating the CPI used in deriving 1.90 IPL original 2011)
gen pl_2017_b = pl_2017_a * cpi_old/cpi_2005_2011
egen ipl_2017_b = mean(pl_2017_b)

*Approach C: Take 1.90 as given and update with CPI and PPP
gen pl_2017_c = 1.9 * ppp2011_original/ppp2017 * cpi_2011_2017/100
egen ipl_2017_c = mean(pl_2017_c)

*Approach D: Take 1.90 as given and update with US inflation
preserve 
	use `"${dir}/data/cpi.dta"', clear
	keep if year==2011 | year == 2017
	keep if inlist(countrycode,"USA")
	rename cpi2010 cpi
	
	sort year
	gen cpi_us= cpi[2]/cpi[1] 
	list cpi_us
	
	collapse cpi_us,by(countrycode)
		
	tempfile cpi_us
	save `cpi_us', replace
restore

merge 1:1 countrycode using `cpi_us', nogen 
egen cpi_us_ = mean(cpi_us)
drop if pl_2011 == . 
drop cpi_us
rename cpi_us_ cpi_us
 
gen pl_2017_d = 1.9 * cpi_us
egen ipl_2017_d = mean(pl_2017_d)

list ipl_2017_*  

label var cpi_us 		"US inflation"
label var ipl_2011		"IPL Original 2011 PPP"
label var ipl_2011_ 	"IPL Revised 2011 PPP"
label var ipl_2017_a	"Update PPP & CPI I (update CPI in $1.9)"
label var ipl_2017_b	"Update PPP & CPI II (do not update CPI in $1.9)"
label var ipl_2017_c 	"Take $1.9 as given, update PPP & CPI"
label var ipl_2017_d 	"Take $1.9 as given, update with US inflation"
label var ipl_2011		"IPL Original 2011 PPP"
label var pl_2011 		"National Poverty Line Original 2011 PPP"

lab var countryname "Country"
lab var countrycode "Code"

*keep countryname countrycode cpi* cpi_us ppp* ipl_2011 ipl_2011_ ipl_2017_* pl_2011
order countryname countrycode pl_2011 cpi* cpi_us ppp* ipl_2011 ipl_2011_ ipl_2017_*
format cpi* cpi_us ppp* pl_2011 ipl_2011 ipl_2011_ ipl_2017_* %12.2f

export excel using `"${dir}/results/IPL.xlsx"', sheet("Stata_ipl2017", modify) firstrow(varl) keepcellfmt


